// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import {IExecutionDelegate} from "src/interfaces/IExecutionDelegate.sol";

contract ExecutionDelegate is IExecutionDelegate, Ownable {
    using Address for address;

    mapping(address => bool) public approvedContracts;
    mapping(address => bool) public revokedContractsApproval;

    event ApproveContract(address indexed _contract);
    event DenyContract(address indexed _contract);

    event RevokeApproval(address indexed user);
    event GrantApproval(address indexed user);

    modifier approvedContract() {
        require(approvedContracts[msg.sender], "Contract is not approved to make transfers");
        _;
    }
    function approveContract(address _contract) external onlyOwner {
        approvedContracts[_contract] = true;
        emit ApproveContract(_contract);
    }

    function denyContract(address _contract) external onlyOwner {
        approvedContracts[_contract] = false;
        emit DenyContract(_contract);
    }

    function revokeApproval() external {
        revokedContractsApproval[msg.sender] = true;
        emit RevokeApproval(msg.sender);
    }

    function grantApproval() external {
        revokedContractsApproval[msg.sender] = false;
        emit GrantApproval(msg.sender);
    }

    function transferERC721(
        address from,
        address to,
        address collection,
        uint256 tokenId
    ) 
        external 
        approvedContract 
    {
        require(revokedContractsApproval[from] == false, "User has revoked approval");
        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }

    function transferERC1155(
        address collection, 
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 amount
    ) 
        external
        approvedContract 
    {
        require(revokedContractsApproval[from] == false, "User has revoked approval");
        IERC1155(collection).safeTransferFrom(from, to, tokenId, amount, "");
    }

    function transferERC20(
        address token, 
        address from, 
        address to, 
        uint256 amount
    )
        approvedContract
        external
    {
        require(revokedContractsApproval[from] == false, "User has revoked approval");
        bytes memory data = abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount);
        bytes memory returndata = token.functionCall(data);
        if (returndata.length > 0) {
          require(abi.decode(returndata, (bool)), "ERC20 transfer failed");
        }
    }
}