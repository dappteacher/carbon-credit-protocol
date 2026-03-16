// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import "../src/token/CarbonCreditToken.sol";
import "../src/nft/CarbonCertificateNFT.sol";
import "../src/registry/CarbonRegistry.sol";
import "../src/oracle/CarbonOracle.sol";
import "../src/governance/CarbonDAO.sol";

contract DaoExecutionTarget {
    bool public toggled;

    function toggle() external {
        toggled = !toggled;
    }
}

contract CarbonDAOTest is Test {
    CarbonCreditToken token;
    CarbonCertificateNFT nft;
    CarbonRegistry registry;
    CarbonOracle oracle;
    CarbonDAO dao;
    DaoExecutionTarget target;

    address proposer = address(21);

    function setUp() public {
        token = new CarbonCreditToken("Carbon", "CO2", address(this));
        nft = new CarbonCertificateNFT(address(0));
        registry = new CarbonRegistry(address(this), address(0), address(token), address(nft));
        oracle = new CarbonOracle(address(registry));
        dao = new CarbonDAO(address(token), 100, 100, 2 days);
        target = new DaoExecutionTarget();

        nft.setRegistry(address(registry));
        registry.setOracle(address(oracle));
        token.setMinter(address(registry));
        token.setTransfersEnabled(true);
        registry.registerCompany(proposer, "ipfs://company-dao");
        oracle.recordOffset(proposer, 250, "DAO-001", "ipfs://dao-cert");
    }

    function testProposalRequiresThreshold() public {
        uint256 proposalId;
        vm.prank(proposer);
        proposalId = dao.createProposal(
            address(target), abi.encodeWithSelector(DaoExecutionTarget.toggle.selector), "toggle target"
        );

        vm.prank(proposer);
        dao.vote(proposalId);

        vm.warp(block.timestamp + 2 days + 1);
        dao.execute(proposalId);

        assertTrue(target.toggled());
    }
}
