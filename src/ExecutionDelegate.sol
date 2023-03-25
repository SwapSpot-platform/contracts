// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import {IExecutionDelegate} from "src/interfaces/IExecutionDelegate.sol";

contract ExecutionDelegate is IExecutionDelegate, Ownable {
    function approveContract(address _contract) external {}
    function denyContract(address _contract) external {}
    function revokeApproval() external {}
    function grantApproval() external {}

    function transferERC721Unsafe(address collection, address from, address to, uint256 tokenId) external {}

    function transferERC721(address collection, address from, address to, uint256 tokenId) external {}

    function transferERC1155(address collection, address from, address to, uint256 tokenId, uint256 amount) external {}
    function transferERC20(address token, address from, address to, uint256 amount) external {}
}