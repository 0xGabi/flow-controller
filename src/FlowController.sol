// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Superfluid} from "@blossom-labs/apps-superfluid/contracts/Superfluid.sol";
import {ConvictionVoting} from "@1hive/apps-conviction-voting/contracts/ConvictionVoting.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "hardhat/console.sol";

contract FlowController is Ownable {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    // Shift to left to leave space for decimals
    int128 private constant ONE = 1 << 64;

    struct Proposal {
        uint256 lastRate;
        uint256 lastTime;
    }

    ConvictionVoting public cv;
    Superfluid public superfluid;

    int128 internal decay;
    int128 internal maxRatio;
    int128 internal minStakeRatio;

    mapping(uint256 => Proposal) internal proposals;
    mapping(uint256 => bool) internal activeProposals;

    constructor(ConvictionVoting _cv, Superfluid _superfluid) {
        cv = _cv;
        superfluid = _superfluid;

        decay = cv.decay.divu(1e18).add(1);
        maxRatio = cv.maxRatio.divu(1e18).add(1);
        minStakeRatio = cv.minStakeRatio.divu(1e18).add(1);
    }

    function activateProposal(uint256 _proposalId) public onlyOwner {
        activeProposals[_proposalId] = true;
        superfluid.createFlow(_token, _receiver, _flowRate, _description);
    }

    function deactivateProposal(uint256 _proposalId) public onlyOwner {
        activeProposals[_proposalId] = false;
        superfluid.deleteFlow(_token, _receiver);
    }

    function updateActiveProposals(uint256[] _proposalsIds) external {
        for (uint256 i = 0; i < _proposalsIds.lenght; i++) {
            Proposal storage proposal = proposals[_proposalsIds[i]];
            if (proposal.lastTime == block.timestamp) {
                continue; // Rates already updated
            }

            // calculateRate and store it
            proposal.lastRate = rate(_proposalId);
            proposal.lastTime = block.timestamp;

            // update flow
            superfluid.updateFlow(_token, _receiver, _flowRate, _description);
        }
    }

    function minStake() public view returns (uint256) {
        return minStakeRatio.mulu(cv.totalStaked);
    }

    /**
     * @dev targetRate = (1 - sqrt(minStake / min(staked, minStake))) * maxRatio * funds
     */
    function calculateTargetRate(uint256 _stake) public view returns (uint256 _targetRate) {
        if (_stake == 0) {
            _targetRate = 0;
        } else {
            uint256 funds = ERC20(cv.requestToken).balanceOf(address(cv.fundsManager));
            uint256 _minStake = minStake();
            _targetRate = (ONE.sub(_minStake.divu(_stake > _minStake ? _stake : _minStake).sqrt())).mulu(
                maxRatio.mulu(funds)
            );
        }
    }

    function getTargetRate(uint256 _proposalId) public view returns (uint256) {
        (, , , stakedTokens) = cv.getProposal(_proposalId);

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
