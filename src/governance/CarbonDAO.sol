// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IVotesToken {
    function balanceOf(address account) external view returns (uint256);
}

contract CarbonDAO {
    struct Proposal {
        address proposer;
        address target;
        bytes data;
        uint64 deadline;
        uint128 votes;
        bool executed;
        string description;
    }

    uint256 public proposalCount;
    uint256 public immutable proposalThreshold;
    uint256 public immutable quorum;
    uint256 public immutable votingPeriod;

    IVotesToken public immutable votingToken;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    error ProposalNotFound();
    error VotingClosed();
    error AlreadyVoted();
    error InsufficientVotingPower();
    error VotingStillActive();
    error ProposalAlreadyExecuted();
    error QuorumNotReached();
    error ProposalExecutionFailed();

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 deadline,
        string description
    );
    event Voted(uint256 indexed id, address indexed voter, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address _votingToken, uint256 _proposalThreshold, uint256 _quorum, uint256 _votingPeriod) {
        votingToken = IVotesToken(_votingToken);
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
        votingPeriod = _votingPeriod;
    }

    function createProposal(address target, bytes calldata data, string calldata description)
        external
        returns (uint256 id)
    {
        uint256 proposerVotes = votingToken.balanceOf(msg.sender);
        if (proposerVotes < proposalThreshold) revert InsufficientVotingPower();

        id = ++proposalCount;
        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            data: data,
            deadline: uint64(block.timestamp + votingPeriod),
            votes: 0,
            executed: false,
            description: description
        });

        emit ProposalCreated(id, msg.sender, target, block.timestamp + votingPeriod, description);
    }

    function vote(uint256 id) external {
        Proposal storage p = proposals[id];
        if (p.target == address(0)) revert ProposalNotFound();
        if (block.timestamp > p.deadline) revert VotingClosed();
        if (voted[id][msg.sender]) revert AlreadyVoted();

        uint256 voterWeight = votingToken.balanceOf(msg.sender);
        if (voterWeight == 0) revert InsufficientVotingPower();

        p.votes += uint128(voterWeight);
        voted[id][msg.sender] = true;

        emit Voted(id, msg.sender, voterWeight);
    }

    function execute(uint256 id) external {
        Proposal storage p = proposals[id];
        if (p.target == address(0)) revert ProposalNotFound();
        if (block.timestamp < p.deadline) revert VotingStillActive();
        if (p.executed) revert ProposalAlreadyExecuted();
        if (p.votes < quorum) revert QuorumNotReached();

        p.executed = true;

        (bool success,) = p.target.call(p.data);
        if (!success) revert ProposalExecutionFailed();

        emit ProposalExecuted(id);
    }
}
