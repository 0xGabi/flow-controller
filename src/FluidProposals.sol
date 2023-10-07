// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableUpgradeable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ConvictionVoting, ProposalStatus} from "./interfaces/IConvictionVoting.sol";
import {FundsManager} from "./interfaces/IFundsManager.sol";
import {Superfluid} from "./interfaces/ISuperfluid.sol";
import {SuperToken} from "./interfaces/ISuperToken.sol";

import {ABDKMath64x64} from "./libraries/ABDKMath64x64.sol";

contract FluidProposals is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    uint256 public immutable version;

    uint256 private constant SUPERTOKEN_WRAP_AMOUNT = 200 ether;

    // Shift to left to leave space for decimals
    int128 private constant ONE = 1 << 64;

    struct Flow {
        uint256 lastRate;
        uint256 lastTime;
    }

    struct Proposal {
        bool registered;
        address beneficiary;
    }

    ConvictionVoting public cv;
    Superfluid public superfluid;
    SuperToken public token;

    int128 public decay;
    int128 public maxRatio;
    int128 public minStakeRatio;

    mapping(uint256 => Flow) internal flows;
    mapping(uint256 => Proposal) internal registeredProposals;
    mapping(address => bool) internal registeredBeneficiary;
    uint256[15] internal activeProposals;

    event FlowSettingsChanged(uint256 decay, uint256 maxRatio, uint256 minStakeRatio);
    event ProposalRegistered(uint256 indexed id, address beneficiary);
    event ProposalActivated(uint256 indexed id);
    event ProposalReplaced(uint256 indexed id);
    event ProposalRemoved(uint256 indexed id);
    event FlowUpdated(uint256 indexed id, address indexed beneficiary, uint256 rate);

    error ProposalOnlyActive();
    error ProposalOnlySignaling();
    error ProposalOnlySubmmiter();
    error ProposalAlreadyActive();
    error ProposalAlreadyRemoved();
    error ProposalNeedsMoreStake();

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor(uint256 version_) {
        version = version_;
        _disableInitializers();
    }

    function initialize(
        address _cv,
        address _superfluid,
        address _token,
        uint256 _decay,
        uint256 _maxRatio,
        uint256 _minStakeRatio
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        cv = ConvictionVoting(_cv);
        superfluid = Superfluid(_superfluid);
        token = SuperToken(_token);
        setFlowSettings(_decay, _maxRatio, _minStakeRatio);
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setFlowSettings(uint256 _decay, uint256 _maxRatio, uint256 _minStakeRatio) public onlyOwner {
        decay = _decay.divu(1e18).add(1);
        maxRatio = _maxRatio.divu(1e18).add(1);
        minStakeRatio = _minStakeRatio.divu(1e18).add(1);

        emit FlowSettingsChanged(_decay, _maxRatio, _minStakeRatio);
    }

    function syncSupertoken() public onlyOwner {
        uint256 superTokenPoolBalance = token.balanceOf(cv.vault());
        uint256 tokenPoolBalance = FundsManager(cv.vault()).balance(cv.requestToken());
        
        // we never have more than 5% of the pool in superToken
        require(superTokenPoolBalance <= tokenPoolBalance / 20, "SuperToken pool balance above 5% ceiling");
       
        superfluid.upgrade(token, SUPERTOKEN_WRAP_AMOUNT);
    }

    function removeProposals(uint256[] memory _proposalIds) public onlyOwner {
        for (uint256 i = 0; i < _proposalIds.length; i++) {
            _removeProposal(_proposalIds[i]);
        }
    }

    function registerProposals(uint256[] memory _proposalIds, address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _proposalIds.length; i++) {
            _registerProposal(_proposalIds[i], _addresses[i]);
        }
    }

    function registerProposal(uint256 _proposalId, address _beneficiary) public {
        require(_proposalId != 0);
        require(_beneficiary != address(0));
        require(!registeredBeneficiary[_beneficiary]);

        (uint256 amount,,,,,,, ProposalStatus status, address submmiter,) = cv.getProposal(_proposalId);

        if (status != ProposalStatus.Active) {
            revert ProposalOnlyActive();
        }

        if (amount != 0) {
            revert ProposalOnlySignaling();
        }

        if (msg.sender != submmiter) {
            revert ProposalOnlySubmmiter();
        }

        _registerProposal(_proposalId, _beneficiary);
    }

    function activateProposal(uint256 _proposalId) public {
        require(registeredProposals[_proposalId].registered);

        (,,, uint256 min,,,,,,) = cv.getProposal(_proposalId);

        uint256 minIndex = _proposalId;

        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                revert ProposalAlreadyActive();
            }
            if (activeProposals[i] == 0) {
                // If position i is empty, use it
                min = 0;
                minIndex = i;
                break;
            }
            (,,, uint256 _min,,,,,,) = cv.getProposal(activeProposals[i]);
            if (_min < min) {
                min = _min;
                minIndex = i;
            }
        }

        if (activeProposals[minIndex] == _proposalId) {
            revert ProposalNeedsMoreStake();
        }

        if (activeProposals[minIndex] == 0) {
            _activateProposal(minIndex, _proposalId);
            return;
        }

        _replaceProposal(minIndex, _proposalId);
    }

    function removeProposal(uint256 _proposalId) public {
        require(_proposalId != 0);
        (,,,,,,,, address submmiter,) = cv.getProposal(_proposalId);

        if (msg.sender != submmiter) {
            revert ProposalOnlySubmmiter();
        }

        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                _removeProposal(i);
                return;
            }
        }

        revert ProposalAlreadyRemoved();
    }

    function sync() external {
        for (uint256 i = 0; i < activeProposals.length; i++) {
            uint256 _proposalId = activeProposals[i];
            Flow storage flow = flows[_proposalId];
            if (flow.lastTime == block.timestamp || _proposalId == 0) {
                continue; // Empty or rates already updated
            }

            // Check still an active proposal
            (,,,,,,, ProposalStatus status,,) = cv.getProposal(_proposalId);
            if (status != ProposalStatus.Active) {
                _removeProposal(i);
                continue;
            }

            // calculateRate and store it
            flow.lastRate = getCurrentRate(_proposalId);
            flow.lastTime = block.timestamp;

            if (flow.lastRate != 0) {
                // update flow
                superfluid.updateFlow(
                    token, registeredProposals[_proposalId].beneficiary, int96(int256(flow.lastRate)), ""
                );

                emit FlowUpdated(_proposalId, registeredProposals[_proposalId].beneficiary, flow.lastRate);
            }
        }
    }

    function _registerProposal(uint256 _proposalId, address _beneficiary) internal {
        Proposal storage proposal = registeredProposals[_proposalId];
        proposal.registered = true;
        proposal.beneficiary = _beneficiary;

        registeredBeneficiary[_beneficiary] = true;

        emit ProposalRegistered(_proposalId, _beneficiary);
    }

    function _activateProposal(uint256 _proposalIndex, uint256 _proposalId) internal {
        require(activeProposals[_proposalIndex] == 0);
        activeProposals[_proposalIndex] = _proposalId;
        // Superfluid require initial flowRate > 0, so int96(1)
        superfluid.createFlow(token, registeredProposals[_proposalId].beneficiary, int96(1), "");

        Flow storage flow = flows[_proposalId];
        flow.lastTime = block.timestamp;

        emit ProposalActivated(_proposalId);
    }

    function _removeProposal(uint256 _proposalIndex) internal {
        uint256 proposalId = activeProposals[_proposalIndex];
        superfluid.deleteFlow(token, registeredProposals[proposalId].beneficiary);
        activeProposals[_proposalIndex] = 0;

        registeredBeneficiary[registeredProposals[proposalId].beneficiary] = false;

        emit ProposalRemoved(proposalId);
    }

    function _replaceProposal(uint256 _proposalIndex, uint256 _proposalId) internal {
        uint256 oldProposalId = activeProposals[_proposalIndex];

        superfluid.deleteFlow(token, registeredProposals[oldProposalId].beneficiary);
        emit ProposalReplaced(oldProposalId);

        activeProposals[_proposalIndex] = _proposalId;

        // Require initial flowRate > 0
        superfluid.createFlow(token, registeredProposals[_proposalId].beneficiary, int96(1), "");

        Flow storage flow = flows[_proposalId];
        flow.lastTime = block.timestamp;

        emit ProposalActivated(_proposalId);
    }

    function canActivateProposal(uint256 _proposalId) public view returns (bool) {
        if (!registeredProposals[_proposalId].registered) {
            return false;
        }

        (,,, uint256 min,,,,,,) = cv.getProposal(_proposalId);

        uint256 minIndex = _proposalId;

        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == _proposalId) {
                // Proposal already active
                return false;
            }
            if (activeProposals[i] == 0) {
                // If position i is empty, use it
                min = 0;
                minIndex = i;
                break;
            }
            (,,, uint256 _min,,,,,,) = cv.getProposal(activeProposals[i]);
            if (_min < min) {
                min = _min;
                minIndex = i;
            }
        }

        return activeProposals[minIndex] != _proposalId;
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
    function calculateTargetRate(uint256 _stake) public view returns (uint256 _targetRate) {
        if (_stake == 0) {
            _targetRate = 0;
        } else {
            // The old CV that 1Hive uses have a vault reference instead of fundsManager
            uint256 funds = FundsManager(cv.vault()).balance(cv.requestToken());
            uint256 _minStake = minStake();
            _targetRate =
                (ONE.sub(_minStake.divu(_stake > _minStake ? _stake : _minStake).sqrt())).mulu(maxRatio.mulu(funds));
        }
    }

    function getTargetRate(uint256 _proposalId) public view returns (uint256) {
        (,,, uint256 stakedTokens,,,,,,) = cv.getProposal(_proposalId);

        return calculateTargetRate(stakedTokens);
    }

    /**
     * @notice Get current
     * @dev rate = (alpha ^ time * lastRate + _targetRate * (1 - alpha ^ time)
     */
    function calculateRate(uint256 _timePassed, uint256 _lastRate, uint256 _targetRate) public view returns (uint256) {
        int128 at = decay.pow(_timePassed);
        return at.mulu(_lastRate) + (ONE.sub(at).mulu(_targetRate)); // No need to check overflow on solidity >=0.8.0
    }

    function getCurrentRate(uint256 _proposalId) public view returns (uint256 _rate) {
        Flow storage flow = flows[_proposalId];
        assert(flow.lastTime <= block.timestamp);
        return _rate = calculateRate(
            block.timestamp - flow.lastTime, // we assert it doesn't overflow above
            flow.lastRate,
            getTargetRate(_proposalId)
        );
    }
}
