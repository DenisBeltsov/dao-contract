// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {DaoContract} from "../src/DaoContract.c.sol";
import {Script} from "forge-std/Script.sol";

contract DaoScript is Script {
    DaoContract public dao;

    function setUp() public {}

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address governanceTokenAddress = vm.envAddress("GOVERNANCE_TOKEN_ADDRESS");

        vm.startBroadcast(pk);
        uint threeMin = 3 * 60;
        dao = new DaoContract(governanceTokenAddress, threeMin);
//        uint proposalId = dao.createProposal("First Proposal");
//        dao.executeProposal(proposalId);

        vm.stopBroadcast();
    }
}
