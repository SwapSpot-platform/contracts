// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { Offer, Fee, OfferType } from "src/lib/OfferStruct.sol";
import { ISwapSpot } from "src/interfaces/ISwapSpot.sol";
import { IExecutionDelegate } from "src/interfaces/IExecutionDelegate.sol";
import { IPolicyManager } from "src/interfaces/IPolicyManager.sol";

contract SwapSpot is ISwapSpot, OwnableUpgradeable, UUPSUpgradeable {
    // trading is open
    uint256 public isOpen;
    uint256 public swapId;

    address public constant WCRO = 0xca2503482e5D6D762b524978f400f03E38d5F962;

    IExecutionDelegate public executionDelegate;
    IPolicyManager public policyManager;
    Fee public fee;

    mapping(bytes32 => bool) public cancelledOrFilled;
    mapping(address => uint256) public nonces;
    mapping(uint256 => Offer) public offersById;
    mapping(address => uint256[]) public offersByTrader;
    mapping(address => bool) public partnersCollection;

    event OfferCancelled(bytes32 indexed hash);
    event OfferListed(bytes32 indexed hash);
    event OfferMade(bytes32 indexed hash);
    event OffersMatched(
        address indexed maker,
        address indexed taker,
        Offer sell,
        bytes32 sellHash,
        Offer buy,
        bytes32 buyHash
    );

    error NotOpen();
    error WrongCaller();
    error AlreadyCancelledOrFilled();
    
    // 0 for buying, 1 for selling
    error OfferInvalidParameters(uint256);

    modifier tradingOpen() {
        if (isOpen == 0) revert NotOpen();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(IExecutionDelegate _executionDelegate, IPolicyManager _policyManager) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        executionDelegate = _executionDelegate;
        policyManager = _policyManager;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}


    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    function open() external onlyOwner {
        isOpen = 1;
    }

    function close() external onlyOwner {
        isOpen = 0;
    }
    
    function setExecutionDelegate(IExecutionDelegate _executionDelegate) external onlyOwner {
        executionDelegate = _executionDelegate;
    }

    function setPolicyManager(IPolicyManager _policyManager) external onlyOwner {
        policyManager = _policyManager;
    }

    /*//////////////////////////////////////////////////////////////
                             TRADING LOGIC
    //////////////////////////////////////////////////////////////*/
    function listOffer(Offer calldata offer) external payable tradingOpen {
        require(offer.side == OfferType.Sell, "Only sell offers are allowed");
        
        bytes32 offerHash = _hashOffer(offer, nonces[offer.trader]);
        if (_validateOfferParameters(offer, offerHash, true) == false) revert OfferInvalidParameters(0);

        uint256 currentSwapId = swapId + 1;
        offersById[currentSwapId] = offer;
        offersByTrader[offer.trader].push(currentSwapId);
        swapId = currentSwapId;
    }

    function makeOffer(Offer calldata makerOffer, Offer calldata takerOffer) external payable {}

    function acceptOffer(Offer calldata makerOffer, Offer calldata takerOffer) external {}

    function _validateOfferParameters(
        Offer calldata offer, 
        bytes32 offerHash, 
        bool isListing
    ) internal view returns (bool) {
        return (
            (isListing ? offer.matchingId == 0 : offer.matchingId != 0) &&
            (offer.collections.length < 9) &&
            (offer.collections.length == offer.tokenIds.length) &&
            (offer.trader == msg.sender) &&
            (cancelledOrFilled[offerHash] == false) &&
            _canSettleOffer(offer.listingTime, offer.expirationTime) &&
            _validateCollections(offer.collections) &&
            _validatePaymentToken(offer.paymentToken)
        );
    }

    function _validateCollections(address[] calldata collections) internal view returns (bool) {
        for (uint i = 0; i < collections.length; i++) {
            if (policyManager.isContractBlacklisted(collections[i])) return false;
        }
        return true;
    }

    function _validatePaymentToken(address paymentToken) internal view returns (bool) {
        return (
            paymentToken == WCRO ||
            policyManager.isTokenAllowed(paymentToken) ||
            paymentToken == address(0)
        );
    }

    function _canSettleOffer(uint256 listingTime, uint256 expirationTime)
        view
        internal
        returns (bool)
    {
        return (listingTime < block.timestamp) && (expirationTime == 0 || block.timestamp < expirationTime);
    }

    function _transferListingFees(Offer calldata offer) internal {
        bool isPartner;
        for (uint i = 0; i < offer.collections.length; i++) {
            if (partnersCollection[offer.collections[i]]) {
                isPartner = true;
                break;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CANCEL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Cancel an offer
    /// @dev It prevents the offer to being matched, must be called by the trader
    /// @param offer The offer to cancel
    function cancelOffer(Offer calldata offer) public {
        if (msg.sender != offer.trader) revert WrongCaller();

        bytes32 hash = _hashOffer(offer, nonces[offer.trader]);

        if (cancelledOrFilled[hash]) revert AlreadyCancelledOrFilled();
        cancelledOrFilled[hash] = true;

        emit OfferCancelled(hash);
    }

    /// @notice Cancel multiple offers
    /// @param offers The offers to cancel
    function cancelOffers(Offer[] calldata offers) external {
        for (uint256 i = 0; i < offers.length; i++) {
            cancelOffer(offers[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  HASH
    //////////////////////////////////////////////////////////////*/
    function _hashOffer(Offer calldata offer, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    offer.trader,
                    offer.side,
                    keccak256(abi.encodePacked(offer.collections)),
                    keccak256(abi.encodePacked(offer.tokenIds)),
                    offer.paymentToken,
                    offer.price,
                    offer.listingTime,
                    offer.expirationTime
                ),
                abi.encode(nonce)
            )
        );
    }
}
