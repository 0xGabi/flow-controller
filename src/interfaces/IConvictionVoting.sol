// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum ProposalStatus {
    Active, // A vote that has been reported to Agreements
    Paused, // A vote that is being challenged by Agreements
    Cancelled, // A vote that has been cancelled
    Executed // A vote that has been executed
}

contract ConvictionVoting {
    uint256 public totalStaked;
    address public requestToken;
    address public vault; // fundsManager for Gardens created with new template

    function getProposal(uint256 _proposalId)
        external
        view
        returns (
            uint256 requestedAmount,
            bool stableRequestAmount,
            address beneficiary,
            uint256 stakedTokens,
            uint256 convictionLast,
            uint64 blockLast,
            uint256 agreementActionId,
            ProposalStatus proposalStatus,
            address submitter,
            uint256 threshold
        )
    {}
}
