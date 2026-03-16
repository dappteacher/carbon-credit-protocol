// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

error NotRegistry();
error RegistryAlreadySet();
error CertificateDoesNotExist();

contract CarbonCertificateNFT {
    string public name = "Carbon Offset Certificate";
    string public symbol = "COC";

    address public registry;
    uint256 public totalSupply;

    struct Certificate {
        address company;
        uint128 amount;
        uint64 timestamp;
        string projectId;
        string metadataURI;
    }

    mapping(uint256 => Certificate) public certificates;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event RegistrySet(address indexed registry);

    modifier onlyRegistry() {
        if (msg.sender != registry) revert NotRegistry();
        _;
    }

    constructor(address _registry) {
        registry = _registry;
        if (_registry != address(0)) {
            emit RegistrySet(_registry);
        }
    }

    function setRegistry(address _registry) external {
        if (registry != address(0)) revert RegistryAlreadySet();
        registry = _registry;
        emit RegistrySet(_registry);
    }

    function mintCertificate(
        address company,
        uint256 amount,
        string calldata projectId,
        string calldata metadataURI
    ) external onlyRegistry returns (uint256 id) {
        id = ++totalSupply;

        certificates[id] = Certificate({
            company: company,
            amount: uint128(amount),
            timestamp: uint64(block.timestamp),
            projectId: projectId,
            metadataURI: metadataURI
        });

        ownerOf[id] = company;
        balanceOf[company]++;

        emit Transfer(address(0), company, id);
    }

    function tokenURI(uint256 id) external view returns (string memory) {
        if (ownerOf[id] == address(0)) revert CertificateDoesNotExist();
        return certificates[id].metadataURI;
    }
}
