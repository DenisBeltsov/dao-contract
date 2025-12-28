// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {DaoContract} from "../src/DaoContract.c.sol";

contract MockGovernanceToken is ERC20 {
    constructor() ERC20("Mock GOV", "MGOV") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DaoTest is Test {
    DaoContract public dao;
    MockGovernanceToken public govToken;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    event ProposalCreated(uint256 indexed id, address indexed creator, string description);
    event ProposalExecuted(uint256 indexed id, address indexed executor);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);

    function setUp() public {
        govToken = new MockGovernanceToken();

        // mint governance power to the contract and distribute to voters
        govToken.mint(address(this), 1_000_000 ether);
        govToken.transfer(user1, 120_000 ether);
        govToken.transfer(user2, 90_000 ether);
        govToken.transfer(user3, 60_000 ether);

        dao = new DaoContract(address(govToken), 1 days);
    }

    function test_CreateProposal() public {
        string memory description = "Test proposal";

        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(1, owner, description);

        uint256 proposalId = dao.createProposal(description);

        assertEq(proposalId, 1);
        assertEq(dao.proposalCount(), 1);

        (uint256 id, string memory desc, bool executed, uint256 forVotes, uint256 againstVotes,) = dao.proposals(1);
        assertEq(id, 1);
        assertEq(desc, description);
        assertFalse(executed);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
    }

    function test_RevertWhen_CreateProposalWithEmptyDescription() public {
        vm.expectRevert("Description cannot be empty");
        dao.createProposal("");
    }

    function test_RevertWhen_NonOwnerCreatesProposal() public {
        vm.prank(user1);
        vm.expectRevert();
        dao.createProposal("Unauthorized proposal");
    }

    function test_VoteEmitsEventAndTallies() public {
        uint256 proposalId = dao.createProposal("Vote on me");

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Voted(proposalId, user1, true, govToken.balanceOf(user1));
        dao.vote(proposalId, true);

        (,, bool executed, uint256 forVotes,,) = dao.proposals(proposalId);
        assertFalse(executed);
        assertEq(forVotes, govToken.balanceOf(user1));
    }

    function test_RevertWhen_DoubleVoting() public {
        uint256 proposalId = dao.createProposal("Test double vote");

        vm.prank(user1);
        dao.vote(proposalId, true);

        vm.prank(user1);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function test_RevertWhen_NoVotingPower() public {
        uint256 proposalId = dao.createProposal("Powerless vote");

        vm.prank(address(0xdead));
        vm.expectRevert("No voting power");
        dao.vote(proposalId, true);
    }

    function test_ExecuteProposalAfterQuorumAndMajority() public {
        uint256 proposalId = dao.createProposal("Execute me");

        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, true);

        vm.expectEmit(true, true, true, true);
        emit ProposalExecuted(proposalId, owner);
        dao.executeProposal(proposalId);

        (,, bool executed,,,) = dao.proposals(proposalId);
        assertTrue(executed);
    }

    function test_RevertWhen_ExecuteWithoutQuorum() public {
        uint256 proposalId = dao.createProposal("Insufficient quorum");

        vm.prank(user1);
        dao.vote(proposalId, true);

        vm.expectRevert("Quorum not reached");
        dao.executeProposal(proposalId);
    }

    function test_RevertWhen_ExecuteWhenRejected() public {
        uint256 proposalId = dao.createProposal("Rejected");

        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, false);
        vm.prank(user3);
        dao.vote(proposalId, false);

        // quorum satisfied but against votes dominate
        vm.expectRevert("Proposal did not pass");
        dao.executeProposal(proposalId);
    }

    function test_RevertWhen_ExecuteAlreadyExecutedProposal() public {
        uint256 proposalId = dao.createProposal("Run once");

        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, true);

        dao.executeProposal(proposalId);

        vm.expectRevert("Proposal already executed");
        dao.executeProposal(proposalId);
    }

    function test_QuorumCalculation() public view {
        uint256 expectedThreshold = (govToken.totalSupply() * dao.QUORUM_BPS()) / dao.BPS_DENOMINATOR();
        assertEq(dao.quorumThreshold(), expectedThreshold);
    }

    function testFuzz_VoteWeightsAffectTallies(bool supportUser2) public {
        uint256 proposalId = dao.createProposal("Fuzz vote");

        vm.prank(user1);
        dao.vote(proposalId, true);

        vm.prank(user2);
        dao.vote(proposalId, supportUser2);

        (,, bool executed, uint256 forVotes, uint256 againstVotes,) = dao.proposals(proposalId);
        assertFalse(executed);

        uint256 expectedFor = govToken.balanceOf(user1) + (supportUser2 ? govToken.balanceOf(user2) : 0);
        uint256 expectedAgainst = supportUser2 ? 0 : govToken.balanceOf(user2);

        assertEq(forVotes, expectedFor);
        assertEq(againstVotes, expectedAgainst);
    }
}
