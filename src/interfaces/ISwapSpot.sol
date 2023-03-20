// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Offer } from "src/lib/OfferStruct.sol";
import { IExecutionDelegate } from "src/interfaces/IExecutionDelegate.sol";
import { IPolicyManager } from "src/interfaces/IPolicyManager.sol";
interface ISwapSpot {
    
    function open() external;
    function close() external;

    function initialize(IExecutionDelegate _executionDelegate, IPolicyManager _policyManager) external;
    function setExecutionDelegate(IExecutionDelegate _executionDelegate) external;
    function setPolicyManager(IPolicyManager _policyManager) external;

    function listOffer(Offer calldata offer) external payable;
    function makeOffer(Offer calldata makerOffer, Offer calldata takerOffer) external payable;

    function acceptOffer(Offer calldata makerOffer, Offer calldata takerOffer) external;
    function cancelOffer(Offer calldata offer) external;
    function cancelOffers(Offer[] calldata offers) external;
}