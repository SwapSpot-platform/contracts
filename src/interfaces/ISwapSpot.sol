// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Offer} from "src/lib/OfferStruct.sol";
import {IExecutionDelegate} from "src/interfaces/IExecutionDelegate.sol";
import {IPolicyManager} from "src/interfaces/IPolicyManager.sol";

interface ISwapSpot {
    function changeTradingState() external;

    function initialize(address _executionDelegate, address _policyManager, address _feeAddress) external;
    function setExecutionDelegate(address _executionDelegate) external;
    function setPolicyManager(address _policyManager) external;
    function setFeeAddress(address _feeAddress) external;
    
    function listOffer(Offer calldata offer) external payable;
    function makeOffer(Offer calldata makerOffer, Offer calldata takerOffer) external payable;

    function acceptOffer(Offer calldata makerOffer, Offer calldata takerOffer) external;
    function cancelOffer(Offer calldata offer) external;
    function cancelOffers(Offer[] calldata offers) external;

    function getOfferArrays(uint256 offerId) external view returns (address[] memory, uint256[] memory);
}
