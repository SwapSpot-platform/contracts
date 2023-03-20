// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPolicyManager {
    function blacklistContract(address _contract) external;
    function addToken(address _token) external;

    function isContractBlacklisted(address _contract) external view returns (bool);
    function isTokenAllowed(address _token) external view returns (bool);

    function viewBlacklistedContracts() external view returns (address[] memory, uint256);
    function viewAllowedTokens() external view returns (address[] memory, uint256);
}