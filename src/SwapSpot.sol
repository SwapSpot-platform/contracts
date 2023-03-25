// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { Offer, Fee, OfferType } from "src/lib/OfferStruct.sol";
import { ISwapSpot } from "src/interfaces/ISwapSpot.sol";
import { IExecutionDelegate } from "src/interfaces/IExecutionDelegate.sol";
import { IPolicyManager } from "src/interfaces/IPolicyManager.sol";

import "forge-std/console.sol";


contract SwapSpot is ISwapSpot, OwnableUpgradeable, UUPSUpgradeable {
    // trading is open
    uint256 public isOpen;
    uint256 public swapId;

    address public constant WCRO = 0xca2503482e5D6D762b524978f400f03E38d5F962;
    address public feeAddress;

    IExecutionDelegate public executionDelegate;
    IPolicyManager public policyManager;
    Fee public fee;

    // check if offer is cancelled or filled
    mapping(bytes32 => bool) public cancelledOrFilled;
    // user's nonce
    mapping(address => uint256) public nonces;
    // offerId => offer
    mapping(uint256 => Offer) public offersById;
    // address => array of offerIds made by user
    mapping(address => uint256[]) public offersByTrader;
    

    event OfferCanceled(bytes32 indexed hash);
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
    error NotEnoughFunds();
    error WrongCaller();
    error AlreadyCancelledOrFilled();
    error InexistantMatchingId();
    error OffersDoNotMatch();
    error OfferExpired();
    
    // 0 for buying, 1 for selling
    error OfferInvalidParameters(uint256 side);

    modifier tradingOpen() {
        if (isOpen == 0) revert NotOpen();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _executionDelegate The address of the execution delegate contract
    /// @param _policyManager The address of the policy manager contract
    /// @param _feeAddress The address that will receive the fees
    function initialize(address _executionDelegate, address _policyManager, address _feeAddress) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        executionDelegate = IExecutionDelegate(_executionDelegate);
        policyManager = IPolicyManager(_policyManager);
        isOpen = 1;
        fee = Fee(50 ether, 2 ether);
        feeAddress = _feeAddress;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}


    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @notice Open or close the trading
    /// @dev If the trading is open, it will be closed and vice versa
    /// @dev Trading has to be open to list/make offers
    function changeTradingState() external onlyOwner {
        isOpen = isOpen == 0 ? 1 : 0;
    }
    
    /// @notice Set the execution delegate contract
    /// @dev The execution delegate contract is the one that will execute the trades
    function setExecutionDelegate(address _executionDelegate) external onlyOwner {
        executionDelegate = IExecutionDelegate(_executionDelegate);
    }

    /// @notice Set the policy manager contract
    /// @dev The policy manager contract is the one that will check the policies, such as blacklisting or whitelisting
    function setPolicyManager(address _policyManager) external onlyOwner {
        policyManager = IPolicyManager(_policyManager);
    }

    /// @notice Set the fee address
    /// @dev The fee address is the one that will receive the fees
    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    /*//////////////////////////////////////////////////////////////
                             TRADING LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Logic for the swap Id increment and offers storage
    /// @dev It is called by the listOffer and makeOffer functions
    /// @param offer The offer to store
    function _setStorageOffers(Offer calldata offer) internal {
        uint256 currentSwapId = swapId + 1;
        offersById[currentSwapId] = offer;
        offersByTrader[offer.trader].push(currentSwapId);
        swapId = currentSwapId;
    }

    /// @notice Logic for the offers listing
    /// @dev The caller has to be the offer.trader
    /// @param offer The offer to list
    function listOffer(Offer calldata offer) external payable tradingOpen {
        require(offer.side == OfferType.Sell, "Only sell offers are allowed");
        if (offer.trader != msg.sender) revert WrongCaller();
        // check if the fees are paid
        if (msg.value < fee.listingFee) revert NotEnoughFunds();

        bytes32 offerHash = _hashOffer(offer, nonces[offer.trader]);
        // check if the offer parameters are valid
        if (_validateOfferParameters(offer, offerHash, true) == false) revert OfferInvalidParameters(0);

        // increment swap id and store the offer
        _setStorageOffers(offer);

        emit OfferListed(offerHash);
    }

    /// @notice Logic for the offers making
    /// @dev The caller has to be the makerOffer.trader
    /// @dev The takerOffer has to be a valid stored offer
    /// @param makerOffer The offer to make
    /// @param takerOffer The offer to match with
    function makeOffer(Offer calldata makerOffer, Offer calldata takerOffer) external payable tradingOpen {
        require(makerOffer.side == OfferType.Buy, "Only buy offers are allowed");
        require(makerOffer.trader != takerOffer.trader, "Cannot make offer with yourself");
        if (makerOffer.trader != msg.sender) revert WrongCaller();
        // check if the fees are paid
        if (msg.value < fee.buyingFee) revert NotEnoughFunds();

        // check if the takerOffer match with the matchingId provided in the makerOffer
        if (_validateMatchingId(makerOffer, takerOffer) == false) revert OffersDoNotMatch();

        bytes32 offerHash = _hashOffer(makerOffer, nonces[makerOffer.trader]);
        bytes32 takerOfferHash = _hashOffer(takerOffer, nonces[takerOffer.trader]);

        if (cancelledOrFilled[takerOfferHash] == true) revert AlreadyCancelledOrFilled();

        // check if the makerOffer parameters are valid
        if (_validateOfferParameters(makerOffer, offerHash, false) == false) revert OfferInvalidParameters(1);

        // check if the takerOffer parameters are valid
        if (_validateOfferParameters(takerOffer, takerOfferHash, true) == false) revert OfferInvalidParameters(0);

        _setStorageOffers(makerOffer);

        // transfer fees to project
        (bool sent,) = feeAddress.call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        emit OfferMade(offerHash);
    }

    function acceptOffer(Offer calldata makerOffer, Offer calldata takerOffer) external {
        require(takerOffer.trader == msg.sender, "Only the taker can accept the offer");

        // check if the takerOffer match with the matchingId provided in the makerOffer
        if (_validateMatchingId(makerOffer, takerOffer) == false) revert OffersDoNotMatch();

    }

    function _canMatchOffers(Offer calldata seller, Offer calldata buyer) 
        internal
        view
        returns (uint256 price, uint256[] memory sellerTokenIds, uint256[] memory buyerTokenIds) {}

    function _validateOfferParameters(
        Offer calldata offer, 
        bytes32 offerHash, 
        bool isListing
    ) internal view returns (bool) {
        return (
            (isListing ? offer.matchingId == 0 : offer.matchingId != 0) &&
            (offer.collections.length < 9) &&
            (offer.collections.length == offer.tokenIds.length) &&
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

    /// @notice Validating the matching between two offers
    /// @dev Computes a hash of the offer got from the makerOffer matchingId 
    ///      and checks if it matches the takerOffer hash
    /// @dev If taker offer is already cancelled or filled, it will return false
    function _validateMatchingId(Offer calldata makerOffer, Offer calldata takerOffer) internal view returns (bool) {
        Offer memory offerFromMatchingId = offersById[makerOffer.matchingId];

        bytes32 takerHash = _hashOffer(takerOffer, nonces[takerOffer.trader]);
        bytes32 offerFromMatchingIdHash = _hashOffer(offerFromMatchingId, nonces[offerFromMatchingId.trader]);
        
        return offerFromMatchingIdHash == takerHash;
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

        emit OfferCanceled(hash);
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
    function _hashOffer(Offer memory offer, uint256 nonce) internal pure returns (bytes32) {
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
                    offer.expirationTime,
                    offer.matchingId
                ),
                abi.encode(nonce)
            )
        );
    }

    function getOfferArrays(uint) internal pure returns (address[] memory, uint256[] memory) {
        return (offer.collections, offer.tokenIds);
    }
}
