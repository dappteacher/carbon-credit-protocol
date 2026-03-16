// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import "../src/token/CarbonCreditToken.sol";
import "../src/nft/CarbonCertificateNFT.sol";
import "../src/registry/CarbonRegistry.sol";
import "../src/oracle/CarbonOracle.sol";
import "../src/market/CarbonMarket.sol";
import "../src/governance/CarbonDAO.sol";

contract RegistryAdminTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract CarbonProtocolTest is Test {
    CarbonCreditToken token;
    CarbonCertificateNFT nft;
    CarbonRegistry registry;
    CarbonOracle oracle;
    CarbonMarket market;
    CarbonDAO dao;
    RegistryAdminTarget target;

    address admin = address(this);
    address company = address(1);
    address buyer = address(2);
    address treasury = address(3);

    function setUp() public {
        token = new CarbonCreditToken("Carbon", "CO2", admin);
        nft = new CarbonCertificateNFT(address(0));
        registry = new CarbonRegistry(admin, address(0), address(token), address(nft));
        oracle = new CarbonOracle(address(registry));
        market = new CarbonMarket(admin, address(token), treasury, 100);
        dao = new CarbonDAO(address(token), 50, 100, 3 days);
        target = new RegistryAdminTarget();

        nft.setRegistry(address(registry));
        registry.setOracle(address(oracle));
        token.setMinter(address(registry));
        token.setTransfersEnabled(true);

        registry.registerCompany(company, "ipfs://company-metadata");
    }

    function testRegisterCompanyAndOracleOffsetMint() public {
        oracle.recordOffset(company, 100, "VCS-001", "ipfs://certificate-1");

        (bool registered, uint64 totalEmission, uint64 totalOffset, string memory metadataURI) = registry.companies(company);

        assertTrue(registered);
        assertEq(totalEmission, 0);
        assertEq(totalOffset, 100);
        assertEq(metadataURI, "ipfs://company-metadata");
        assertEq(token.balanceOf(company), 100);
        assertEq(nft.balanceOf(company), 1);
        assertEq(nft.tokenURI(1), "ipfs://certificate-1");
    }

    function testMarketOrderLifecycle() public {
        oracle.recordOffset(company, 500, "GOLD-001", "ipfs://gold-standard-1");

        vm.prank(company);
        token.approve(address(market), 200);

        vm.prank(company);
        uint256 orderId = market.createOrder(200, 1 ether);

        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        market.fillOrder{value: 1 ether}(orderId);

        assertEq(token.balanceOf(buyer), 200);
        assertEq(treasury.balance, 0.01 ether);
        assertEq(company.balance, 0.99 ether);
    }

    function testDAOProposalExecution() public {
        oracle.recordOffset(company, 200, "VCS-002", "ipfs://certificate-2");

        vm.prank(company);
        uint256 proposalId = dao.createProposal(
            address(target),
            abi.encodeWithSelector(RegistryAdminTarget.setValue.selector, 42),
            "Update target value"
        );

        vm.prank(company);
        dao.vote(proposalId);

        vm.warp(block.timestamp + 3 days + 1);
        dao.execute(proposalId);

        assertEq(target.value(), 42);
    }

    function testNetEmissions() public {
        oracle.reportEmission(company, 300);
        oracle.recordOffset(company, 125, "VCS-003", "ipfs://certificate-3");

        assertEq(registry.netEmissions(company), 175);
    }
}
