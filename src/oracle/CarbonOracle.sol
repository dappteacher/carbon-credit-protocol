// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../access/Ownable.sol";

interface IRegistry {
    function reportEmission(address company, uint64 amount) external;
    function recordOffset(address company, uint64 amount, string calldata projectId, string calldata metadataURI) external;
}

contract CarbonOracle is Ownable {
    IRegistry public registry;

    event RegistryUpdated(address indexed registry);

    constructor(address _registry) Ownable(msg.sender) {
        registry = IRegistry(_registry);
        emit RegistryUpdated(_registry);
    }

    function setRegistry(address _registry) external onlyOwner {
        if (_registry == address(0)) revert ZeroAddress();
        registry = IRegistry(_registry);
        emit RegistryUpdated(_registry);
    }

    function reportEmission(address company, uint64 amount) external onlyOwner {
        registry.reportEmission(company, amount);
    }

    function recordOffset(
        address company,
        uint64 amount,
        string calldata projectId,
        string calldata metadataURI
    ) external onlyOwner {
        registry.recordOffset(company, amount, projectId, metadataURI);
    }
}
