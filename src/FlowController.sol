// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {ConvictionVoting} from "./interfaces/IConvictionVoting.sol";
import {Superfluid} from "./interfaces/ISuperfluid.sol";
import {ISuperToken} from "./interfaces/ISuperToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";

import "hardhat/console.sol";

contract FlowController is Ownable {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using SafeMath for uint256;

    // Shift to left to leave space for decimals
    int128 private constant ONE = 1 << 64;

    struct Proposal {
        uint256 lastRate;
        uint256 lastTime;
    }

    ConvictionVoting public cv;
    Superfluid public superfluid;
    ISuperToken public token;

    int128 internal decay;
    int128 internal maxRatio;
    int128 internal minStakeRatio;

    mapping(uint256 => Proposal) internal proposals;
    mapping(uint256 => bool) internal activeProposals;

    event ProposalActivated(uint256 indexed id);
    event ProposalDeactivated(uint256 indexed id);
    event FlowUpdated(uint256 indexed id, address indexed beneficiary, uint256 rate);

    constructor(
        ConvictionVoting _cv,
        Superfluid _superfluid,
        ISuperToken _token
    ) {
        cv = _cv;
        superfluid = _superfluid;
        token = _token;

        decay = cv.decay().divu(1e18).add(1);
        maxRatio = cv.maxRatio().divu(1e18).add(1);
        minStakeRatio = cv.minStakeRatio().divu(1e18).add(1);
    }

    function activateProposal(uint256 _proposalId) public onlyOwner {
        assert(!activeProposals[_proposalId]);

        activeProposals[_proposalId] = true;

        (, , address beneficiary, , , , , , , ) = cv.getProposal(_proposalId);

        superfluid.createFlow(token, beneficiary, 0, "");

        emit ProposalActivated(_proposalId);
    }

    function deactivateProposal(uint256 _proposalId) public onlyOwner {
        assert(activeProposals[_proposalId]);

        activeProposals[_proposalId] = false;

        (, , address beneficiary, , , , , , , ) = cv.getProposal(_proposalId);
        superfluid.deleteFlow(token, beneficiary);

        emit ProposalDeactivated(_proposalId);
    }

    function isActive(uint256 _proposalId) public view returns (bool) {
        return (activeProposals[_proposalId] == true);
    }

    function updateActiveProposals(uint256[] memory _proposalsIds) external {
        for (uint256 i = 0; i < _proposalsIds.length; i++) {
            if (!activeProposals[_proposalsIds[i]]) {
                continue;
            }

            Proposal storage proposal = proposals[_proposalsIds[i]];
            if (proposal.lastTime == block.timestamp) {
                continue; // Rates already updated
            }

            // calculateRate and store it
            proposal.lastRate = getCurrentRate(_proposalsIds[i]);
            proposal.lastTime = block.timestamp;

            (, , address beneficiary, , , , , , , ) = cv.getProposal(_proposalsIds[i]);

            // update flow
            superfluid.updateFlow(token, beneficiary, int96(int256(proposal.lastRate)), "");

            emit FlowUpdated(_proposalsIds[i], beneficiary, proposal.lastRate);
        }
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
            uint256 funds = IERC20(cv.requestToken()).balanceOf(address(cv.fundsManager()));
            uint256 _minStake = minStake();
            _targetRate = (ONE.sub(_minStake.divu(_stake > _minStake ? _stake : _minStake).sqrt())).mulu(
                maxRatio.mulu(funds)
            );
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
        return at.mulu(_lastRate).add(ONE.sub(at).mulu(_targetRate));
    }

    function getCurrentRate(uint256 _proposalId) public view returns (uint256 _rate) {
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
