// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IPolicyManager} from "src/interfaces/IPolicyManager.sol";

/**
 * @title PolicyManager
 * @dev Manages the policy whitelist for the Blur exchange
 */
contract PolicyManager is IPolicyManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _whitelistedTokens;
    EnumerableSet.AddressSet private _blacklistedContracts;

    function blacklistContract(address _contract) external override onlyOwner {
        require(!_blacklistedContracts.contains(_contract), "Contract already blacklisted");
        _blacklistedContracts.add(_contract);
    }

    function addToken(address _token) external override onlyOwner {
        require(!_whitelistedTokens.contains(_token), "Token already whitelisted");
        _whitelistedTokens.add(_token);
    }

    function isContractBlacklisted(address _contract) external view override returns (bool) {
        return _blacklistedContracts.contains(_contract);
    }

    function isTokenAllowed(address _token) external view override returns (bool) {
        return _whitelistedTokens.contains(_token);
    }

    function viewBlacklistedContracts() external view override returns (address[] memory, uint256) {
        uint256 length = _blacklistedContracts.length();
        address[] memory contracts = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            contracts[i] = _blacklistedContracts.at(i);
        }
        return (contracts, length);
    }

    function viewAllowedTokens() external view override returns (address[] memory, uint256) {
        uint256 length = _whitelistedTokens.length();
        address[] memory tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = _whitelistedTokens.at(i);
        }
        return (tokens, length);
    }
}