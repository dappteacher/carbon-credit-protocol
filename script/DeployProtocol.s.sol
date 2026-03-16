// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";

import "../src/token/CarbonCreditToken.sol";
import "../src/nft/CarbonCertificateNFT.sol";
import "../src/registry/CarbonRegistry.sol";
import "../src/oracle/CarbonOracle.sol";
import "../src/market/CarbonMarket.sol";
import "../src/governance/CarbonDAO.sol";

contract DeployProtocol is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");

        vm.startBroadcast(deployerPrivateKey);

        CarbonCreditToken token = new CarbonCreditToken("Carbon Credit", "CO2", msg.sender);
        CarbonCertificateNFT nft = new CarbonCertificateNFT(address(0));
        CarbonRegistry registry = new CarbonRegistry(msg.sender, address(0), address(token), address(nft));
        CarbonOracle oracle = new CarbonOracle(address(registry));
        CarbonMarket market = new CarbonMarket(msg.sender, address(token), treasury, 100);
        CarbonDAO dao = new CarbonDAO(address(token), 100 * 10 ** 6, 500 * 10 ** 6, 3 days);

        nft.setRegistry(address(registry));
        registry.setOracle(address(oracle));
        token.setMinter(address(registry));
        token.setTransfersEnabled(true);

        console2.log("CarbonCreditToken:", address(token));
        console2.log("CarbonCertificateNFT:", address(nft));
        console2.log("CarbonRegistry:", address(registry));
        console2.log("CarbonOracle:", address(oracle));
        console2.log("CarbonMarket:", address(market));
        console2.log("CarbonDAO:", address(dao));

        vm.stopBroadcast();
    }
}
