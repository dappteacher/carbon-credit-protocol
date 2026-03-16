// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import "../src/token/CarbonCreditToken.sol";
import "../src/nft/CarbonCertificateNFT.sol";
import "../src/registry/CarbonRegistry.sol";
import "../src/oracle/CarbonOracle.sol";
import "../src/market/CarbonMarket.sol";

contract CarbonMarketTest is Test {
    CarbonCreditToken token;
    CarbonCertificateNFT nft;
    CarbonRegistry registry;
    CarbonOracle oracle;
    CarbonMarket market;

    address company = address(11);
    address buyer = address(12);
    address treasury = address(13);

    function setUp() public {
        token = new CarbonCreditToken("Carbon", "CO2", address(this));
        nft = new CarbonCertificateNFT(address(0));
        registry = new CarbonRegistry(address(this), address(0), address(token), address(nft));
        oracle = new CarbonOracle(address(registry));
        market = new CarbonMarket(address(this), address(token), treasury, 250);

        nft.setRegistry(address(registry));
        registry.setOracle(address(oracle));
        token.setMinter(address(registry));
        token.setTransfersEnabled(true);
        registry.registerCompany(company, "ipfs://company");
        oracle.recordOffset(company, 1_000, "GS-100", "ipfs://cert");
    }

    function testSellerCanCancelOrder() public {
        vm.startPrank(company);
        token.approve(address(market), 300);
        uint256 orderId = market.createOrder(300, 2 ether);
        market.cancelOrder(orderId);
        vm.stopPrank();

        (,,, bool active) = market.orders(orderId);
        assertFalse(active);
    }

    function testFeeConfigurationWorks() public {
        market.setFeeConfig(300, address(99));
        assertEq(market.feeBps(), 300);
        assertEq(market.feeRecipient(), address(99));
    }

    function testFillOrderMovesTokensAndFunds() public {
        vm.prank(company);
        token.approve(address(market), 400);

        vm.prank(company);
        uint256 orderId = market.createOrder(400, 4 ether);

        vm.deal(buyer, 4 ether);
        vm.prank(buyer);
        market.fillOrder{value: 4 ether}(orderId);

        assertEq(token.balanceOf(buyer), 400);
        assertEq(treasury.balance, 0.1 ether);
        assertEq(company.balance, 3.9 ether);
    }
}
