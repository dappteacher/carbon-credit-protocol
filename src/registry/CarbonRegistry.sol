// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../access/Ownable.sol";

interface ICarbonToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface ICarbonCertificate {
    function mintCertificate(address company, uint256 amount, string calldata projectId, string calldata metadataURI)
        external
        returns (uint256 id);
}

contract CarbonRegistry is Ownable {
    struct Company {
        bool registered;
        uint64 totalEmission;
        uint64 totalOffset;
        string metadataURI;
    }

    mapping(address => Company) public companies;

    address public oracle;
    ICarbonToken public token;
    ICarbonCertificate public certificate;

    error NotOracle();
    error CompanyNotRegistered();
    error AlreadyRegistered();
    error InvalidOffset();

    event CompanyRegistered(address indexed company, string metadataURI);
    event CompanyMetadataUpdated(address indexed company, string metadataURI);
    event OracleUpdated(address indexed oracle);
    event EmissionReported(address indexed company, uint64 amount, uint64 totalEmission);
    event OffsetRecorded(address indexed company, uint64 amount, uint64 totalOffset, uint256 certificateId, string projectId);

    modifier onlyOracle() {
        if (msg.sender != oracle) revert NotOracle();
        _;
    }

    constructor(
        address _owner,
        address _oracle,
        address _token,
        address _certificate
    ) Ownable(_owner) {
        oracle = _oracle;
        token = ICarbonToken(_token);
        certificate = ICarbonCertificate(_certificate);

        emit OracleUpdated(_oracle);
    }

    function registerCompany(address company, string calldata metadataURI) external onlyOwner {
        if (companies[company].registered) revert AlreadyRegistered();

        companies[company] = Company({
            registered: true,
            totalEmission: 0,
            totalOffset: 0,
            metadataURI: metadataURI
        });

        emit CompanyRegistered(company, metadataURI);
    }

    function updateCompanyMetadata(address company, string calldata metadataURI) external onlyOwner {
        Company storage myCompany = companies[company];
        if (!myCompany.registered) revert CompanyNotRegistered();

        myCompany.metadataURI = metadataURI;
        emit CompanyMetadataUpdated(company, metadataURI);
    }

    function reportEmission(address company, uint64 amount) external onlyOracle {
        Company storage myCompany = companies[company];
        if (!myCompany.registered) revert CompanyNotRegistered();

        myCompany.totalEmission += amount;
        emit EmissionReported(company, amount, myCompany.totalEmission);
    }

    function recordOffset(
        address company,
        uint64 amount,
        string calldata projectId,
        string calldata metadataURI
    ) external onlyOracle {
        Company storage myCompany = companies[company];
        if (!myCompany.registered) revert CompanyNotRegistered();
        if (amount == 0) revert InvalidOffset();

        myCompany.totalOffset += amount;

        token.mint(company, amount);
        uint256 certificateId = certificate.mintCertificate(company, amount, projectId, metadataURI);

        emit OffsetRecorded(company, amount, myCompany.totalOffset, certificateId, projectId);
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = _oracle;
        emit OracleUpdated(_oracle);
    }

    function netEmissions(address company) external view returns (uint256) {
        Company memory myCompany = companies[company];
        if (!myCompany.registered) revert CompanyNotRegistered();

        if (myCompany.totalOffset >= myCompany.totalEmission) {
            return 0;
        }

        return myCompany.totalEmission - myCompany.totalOffset;
    }
}
