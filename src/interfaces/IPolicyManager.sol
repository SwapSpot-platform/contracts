// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPolicyManager {
    function partnersFeeAddress(address _collection) external view returns (address);
    function blacklistContract(address _contract) external;
    function addToken(address _token) external;
    function addPartner(address _collection, address _feeAddress) external;

    function isContractBlacklisted(address _contract) external view returns (bool);
    function isTokenAllowed(address _token) external view returns (bool);

    function viewBlacklistedContracts() external view returns (address[] memory, uint256);
    function viewAllowedTokens() external view returns (address[] memory, uint256);
    function viewPartners() external view returns (address[] memory, uint256);
}
