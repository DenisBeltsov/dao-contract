pragma solidity ^0.8.30;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract DaoContract is Ownable {
    uint256 public constant QUORUM_BPS = 300; // 3%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public proposalCount;
    IERC20 public immutable governanceToken;
    uint256 public immutable voteDuration;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address indexed creator, string description);
    event ProposalExecuted(uint256 indexed id, address indexed executor);
    event ProposalFinalized(uint256 indexed id, address indexed finalizer);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);

    struct Proposal {
        uint256 id;
        string description;
        bool executed;
        bool finalized;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 createdAt;
    }

    constructor(address governanceTokenAddress, uint256 _voteDuration) Ownable(msg.sender) {
        require(governanceTokenAddress != address(0), "Invalid governance token");
        governanceToken = IERC20(governanceTokenAddress);
        voteDuration = _voteDuration;
    }

    function createProposal(string memory _description) public onlyOwner returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: _description,
            executed: false,
            finalized: false,
            forVotes: 0,
            againstVotes: 0,
            createdAt: block.timestamp
        });

        emit ProposalCreated(proposalCount, msg.sender, _description);
        return proposalCount;
    }

    function vote(uint256 _id, bool _support) external {
        Proposal storage proposal = proposals[_id];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.finalized, "Proposal already finalized");
        require(!hasVoted[_id][msg.sender], "Already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[_id][msg.sender] = true;

        if (_support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit Voted(_id, msg.sender, _support, weight);
    }

    function finalizeProposal(uint256 _id) public onlyOwner {
        Proposal storage proposal = proposals[_id];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.finalized, "Proposal already finalized");
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.createdAt + voteDuration, "Voting window active");

        proposal.finalized = true;
        emit ProposalFinalized(_id, msg.sender);
    }

    function executeProposal(uint256 _id) public onlyOwner {
        Proposal storage proposal = proposals[_id];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(_hasQuorum(proposal), "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal did not pass");

        require(block.timestamp >= proposal.createdAt + voteDuration, "Voting window active");
        proposal.executed = true;
        proposal.finalized = true;

        emit ProposalExecuted(_id, msg.sender);
    }

    function hasQuorum(uint256 _id) external view returns (bool) {
        Proposal storage proposal = proposals[_id];
        require(proposal.id != 0, "Proposal does not exist");
        return _hasQuorum(proposal);
    }

    function quorumThreshold() public view returns (uint256) {
        return (governanceToken.totalSupply() * QUORUM_BPS) / BPS_DENOMINATOR;
    }

    function getProposal(uint256 _id) external view returns (Proposal memory) {
        Proposal memory proposal = proposals[_id];
        require(proposal.id != 0, "Proposal does not exist");
        return proposal;
    }

    function _hasQuorum(Proposal storage proposal) internal view returns (bool) {
        uint256 supply = governanceToken.totalSupply();
        if (supply == 0) {
            return false;
        }
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        return totalVotes * BPS_DENOMINATOR >= supply * QUORUM_BPS;
    }
}
