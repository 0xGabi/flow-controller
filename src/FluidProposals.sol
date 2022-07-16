// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ConvictionVoting} from "./interfaces/IConvictionVoting.sol";
import {FundsManager} from "./interfaces/IFundsManager.sol";
import {Superfluid} from "./interfaces/ISuperfluid.sol";
import {SuperToken} from "./interfaces/ISuperToken.sol";
import {ABDKMath64x64} from "./libraries/ABDKMath64x64.sol";

contract FluidProposals is Owned {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // Shift to left to leave space for decimals
    int128 private constant ONE = 1 << 64;

    struct Proposal {
        uint256 lastRate;
        uint256 lastTime;
    }

    ConvictionVoting public cv;
    Superfluid public superfluid;
    SuperToken public token;

    int128 public decay;
    int128 public maxRatio;
    int128 public minStakeRatio;

    mapping(uint256 => Proposal) internal proposals;
    uint256[10] internal activeProposals;
    address[10] internal beneficiaries;

    event FlowSettingsChanged(
        uint256 decay,
        uint256 maxRatio,
        uint256 minStakeRatio
    );
    event ProposalActivated(uint256 indexed id, address beneficiary);
    event ProposalDeactivated(uint256 indexed id);
    event FlowUpdated(
        uint256 indexed id,
        address indexed beneficiary,
        uint256 rate
    );

    error ProposalAlreadyActive(uint256 position);
    error ProposalAlreadyInactive();
    error ProposalNeedsMoreStake();

    constructor(
        address _cv,
        address _superfluid,
        address _token,
        uint256 _decay,
        uint256 _maxRatio,
        uint256 _minStakeRatio
    ) Owned(msg.sender) {
        cv = ConvictionVoting(_cv);
        superfluid = Superfluid(_superfluid);
        token = SuperToken(_token);
        setFlowSettings(_decay, _maxRatio, _minStakeRatio);
    }

    function setFlowSettings(
        uint256 _decay,
        uint256 _maxRatio,
        uint256 _minStakeRatio
    ) public onlyOwner {
        decay = _decay.divu(1e18).add(1);
        maxRatio = _maxRatio.divu(1e18).add(1);
        minStakeRatio = _minStakeRatio.divu(1e18).add(1);

        emit FlowSettingsChanged(_decay, _maxRatio, _minStakeRatio);
    }

    function activateProposal(uint256 _proposalId, address _beneficiary)
        public
    {
        require(_proposalId != 0);
        (, , , uint256 min, , , , , , ) = cv.getProposal(_proposalId);
        uint256 minIndex = _proposalId;

        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                revert ProposalAlreadyActive(i);
            }
            if (activeProposals[i] == 0) {
                // If position i is empty, use it
                min = 0;
                minIndex = i;
                break;
            }
            (, , , uint256 _min, , , , , , ) = cv.getProposal(
                activeProposals[i]
            );
            if (_min < min) {
                min = _min;
                minIndex = i;
            }
        }

        if (activeProposals[minIndex] == _proposalId) {
            revert ProposalNeedsMoreStake();
        }

        if (activeProposals[minIndex] == 0) {
            _activateProposal(minIndex, _proposalId, _beneficiary);
        }

        _replaceProposal(minIndex, _proposalId, _beneficiary);
    }

    function deactivateProposal(uint256 _proposalId) public onlyOwner {
        require(_proposalId != 0);
        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                _deactivateProposal(i);
                return;
            }
        }

        revert ProposalAlreadyInactive();
    }

    function sync() external {
        for (uint256 i = 0; i < activeProposals.length; i++) {
            uint256 _proposalId = activeProposals[i];
            Proposal storage proposal = proposals[_proposalId];
            if (proposal.lastTime == block.timestamp || _proposalId == 0) {
                continue; // Empty or rates already updated
            }

            // calculateRate and store it
            proposal.lastRate = getCurrentRate(_proposalId);
            proposal.lastTime = block.timestamp;

            // update flow
            superfluid.updateFlow(
                token,
                beneficiaries[i],
                int96(int256(proposal.lastRate)),
                ""
            );

            emit FlowUpdated(_proposalId, beneficiaries[i], proposal.lastRate);
        }
    }

    function _activateProposal(
        uint256 _proposalIndex,
        uint256 _proposalId,
        address _beneficiary
    ) internal {
        require(activeProposals[_proposalIndex] == 0);
        activeProposals[_proposalIndex] = _proposalId;
        beneficiaries[_proposalIndex] = _beneficiary;
        // Require initial flowRate > 0
        superfluid.createFlow(token, _beneficiary, int96(1), "");
        emit ProposalActivated(_proposalId, _beneficiary);
    }

    function _deactivateProposal(uint256 _proposalIndex) internal {
        uint256 _proposalId = activeProposals[_proposalIndex];
        address beneficiary = beneficiaries[_proposalIndex];
        superfluid.deleteFlow(token, beneficiary);
        emit ProposalDeactivated(_proposalId);
        activeProposals[_proposalIndex] = 0;
    }

    function _replaceProposal(
        uint256 _proposalIndex,
        uint256 _proposalId,
        address _beneficiary
    ) internal {
        uint256 oldProposalId = activeProposals[_proposalIndex];
        address oldBeneficiary = beneficiaries[_proposalIndex];

        superfluid.deleteFlow(token, oldBeneficiary);
        emit ProposalDeactivated(oldProposalId);

        activeProposals[_proposalIndex] = _proposalId;
        beneficiaries[_proposalIndex] = _beneficiary;

        // Require initial flowRate > 0
        superfluid.createFlow(token, _beneficiary, int96(1), "");
        emit ProposalActivated(_proposalId, _beneficiary);
    }

    function isActive(uint256 _proposalId) public view returns (bool) {
        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                return true;
            }
        }
        return false;
    }

    function minStake() public view returns (uint256) {
        return minStakeRatio.mulu(cv.totalStaked());
    }

    /**
     * @dev targetRate = (1 - sqrt(minStake / min(staked, minStake))) * maxRatio * funds
     */
    function calculateTargetRate(uint256 _stake)
        public
        view
        returns (uint256 _targetRate)
    {
        if (_stake == 0) {
            _targetRate = 0;
        } else {
            uint256 funds = FundsManager(cv.fundsManager()).balance(
                cv.requestToken()
            );
            uint256 _minStake = minStake();
            _targetRate = (
                ONE.sub(
                    _minStake
                        .divu(_stake > _minStake ? _stake : _minStake)
                        .sqrt()
                )
            ).mulu(maxRatio.mulu(funds));
        }
    }

    function getTargetRate(uint256 _proposalId) public view returns (uint256) {
        (, , , uint256 stakedTokens, , , , , , ) = cv.getProposal(_proposalId);

        return calculateTargetRate(stakedTokens);
    }

    /**
     * @notice Get current
     * @dev rate = (alpha ^ time * lastRate + _targetRate * (1 - alpha ^ time)
     */
    function calculateRate(
        uint256 _timePassed,
        uint256 _lastRate,
        uint256 _targetRate
    ) public view returns (uint256) {
        int128 at = decay.pow(_timePassed);
        return at.mulu(_lastRate) + (ONE.sub(at).mulu(_targetRate)); // No need to check overflow on solidity >=0.8.0
    }

    function getCurrentRate(uint256 _proposalId)
        public
        view
        returns (uint256 _rate)
    {
        Proposal storage proposal = proposals[_proposalId];
        assert(proposal.lastTime <= block.timestamp);
        return
            _rate = calculateRate(
                block.timestamp - proposal.lastTime, // we assert it doesn't overflow above
                proposal.lastRate,
                getTargetRate(_proposalId)
            );
    }
}
