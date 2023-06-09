// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {Utilities} from "test/utils/Utilities.sol";

import {SwapSpot} from "src/SwapSpot.sol";
import {PolicyManager} from "src/PolicyManager.sol";
import {ExecutionDelegate} from "src/ExecutionDelegate.sol";
import {Offer, Fee, OfferType, AssetType} from "src/lib/OfferStruct.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {mockERC20} from "src/mock/mockERC20.sol";
import {mockERC721} from "src/mock/mockERC721.sol";
import {mockERC1155} from "src/mock/mockERC1155.sol";

contract SwapSpotTest is DSTest {
    SwapSpot internal swapspot;
    PolicyManager internal policyManager;
    ExecutionDelegate executionDelegate;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address internal owner;
    address internal feeAddress;

    Offer[] internal offers;
    AssetType[] internal assetTypes;

    mockERC20 internal token1;
    mockERC20 internal token2;

    mockERC721 internal nft1;
    mockERC721 internal nft2;
    mockERC721 internal nft3;

    mockERC1155 internal erc1155_1;
    mockERC1155 internal erc1155_2;

    uint256[] internal tokenIds;
    address[] internal collections;

    uint64 internal timestamp = uint64(block.timestamp);
    uint64 internal deploymentTimestamp = timestamp + 1 days;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(6);

        token1 = new mockERC20();
        token2 = new mockERC20();
        nft1 = new mockERC721();
        nft2 = new mockERC721();
        nft3 = new mockERC721();
        erc1155_1 = new mockERC1155();
        erc1155_2 = new mockERC1155();
        _sendTokens();

        vm.startPrank(owner);
        SwapSpot implementation = new SwapSpot();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        policyManager = new PolicyManager();
        executionDelegate = new ExecutionDelegate();

        swapspot = SwapSpot(address(proxy));
        swapspot.initialize(address(executionDelegate), address(policyManager), feeAddress);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            nft1.setApprovalForAll(address(executionDelegate), true);
            nft2.setApprovalForAll(address(executionDelegate), true);
            nft3.setApprovalForAll(address(executionDelegate), true);
            erc1155_1.setApprovalForAll(address(executionDelegate), true);
            erc1155_2.setApprovalForAll(address(executionDelegate), true);
            vm.stopPrank();
        }
    }

    function _sendTokens() internal {
        for (uint256 i = 0; i < users.length; i++) {
            token1.mint(users[i], 100000 ether);
            token2.mint(users[i], 100000 ether);
            nft1.mint(users[i], 10);
            nft2.mint(users[i], 10);
            nft3.mint(users[i], 10);
            erc1155_1.mint(users[i], 1, 10);
            erc1155_1.mint(users[i], 2, 10);
            erc1155_2.mint(users[i], 1, 10);
            erc1155_2.mint(users[i], 2, 10);
        }
    }

    function testInitialize_ShouldRevert_WhenAlreadyInitialized() public {
        vm.prank(users[0]);
        vm.expectRevert();
        swapspot.initialize(address(executionDelegate), address(policyManager), address(feeAddress));
    }

    function testInitialize_ShouldHaveRightOwner_WhenDeployed() public {
        assertEq(address(swapspot.owner()), owner);
    }

    function testInitialize_ShouldHaveSetRightValues_WhenDeployed() public {
        assertEq(address(swapspot.executionDelegate()), address(executionDelegate));
        assertEq(address(swapspot.policyManager()), address(policyManager));
        assertEq(swapspot.isOpen(), 1);
        assertEq(swapspot.feeAddress(), feeAddress);
        (uint128 listingFee, uint128 buyingFee) = swapspot.fee();
        assertEq(listingFee, 50 ether);
        assertEq(buyingFee, 2 ether);
    }

    function testTradingState_ShouldBeTrue_WhenDeployed() public {
        assertEq(swapspot.isOpen(), 1);
    }

    function testTradingState_ShouldRevert_WhenNotOwner() public {
        vm.prank(users[0]);
        vm.expectRevert();
        swapspot.changeTradingState();
    }

    function testTradingState_ShouldSucceed_WhenOwner() public {
        vm.prank(owner);
        swapspot.changeTradingState();
        assertEq(swapspot.isOpen(), 0);

        vm.prank(owner);
        swapspot.changeTradingState();
        assertEq(swapspot.isOpen(), 1);
    }

    function testSetFeeAddress_ShouldRevert_WhenNotOwner() public {
        vm.prank(users[0]);
        vm.expectRevert();
        swapspot.setFeeAddress(address(users[0]));
    }

    function testSetFeeAddress_ShouldSucceed_WhenOwner() public {
        vm.prank(owner);
        swapspot.setFeeAddress(address(users[0]));
        assertEq(swapspot.feeAddress(), address(users[0]));
    }

    function testSetExecutionDelegate_ShouldRevert_WhenNotOwner() public {
        vm.prank(users[0]);
        vm.expectRevert();
        swapspot.setExecutionDelegate(address(executionDelegate));
    }

    function testSetExecutionDelegate_ShouldSucceed_WhenOwner() public {
        ExecutionDelegate newExecutionDelegate = new ExecutionDelegate();
        vm.prank(owner);
        swapspot.setExecutionDelegate(address(newExecutionDelegate));
        assertEq(address(swapspot.executionDelegate()), address(newExecutionDelegate));
    }

    function testSetPolicyManager_ShouldRevert_WhenNotOwner() public {
        vm.prank(users[0]);
        vm.expectRevert();
        swapspot.setPolicyManager(address(policyManager));
    }

    function testSetPolicyManager_ShouldSucceed_WhenOwner() public {
        PolicyManager newPolicyManager = new PolicyManager();
        vm.prank(owner);
        swapspot.setPolicyManager(address(newPolicyManager));
        assertEq(address(swapspot.policyManager()), address(newPolicyManager));
    }

    function testListOffer_ShouldRevert_WhenNotEnoughEthValue() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(SwapSpot.NotEnoughFunds.selector);
        swapspot.listOffer{value: 10 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTradingClosed() public {
        vm.prank(owner);
        swapspot.changeTradingState();

        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(SwapSpot.NotOpen.selector);
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenListingParameterIsBuy() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert("Only sell offers are allowed");
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenMatchingIdIs1() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTokenIdsLengthIs0() public {
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCollectionsLengthIs0() public {
        tokenIds.push(1);
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenPriceIsNotNull() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 1,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert("Price must be 0 for sell offers");
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCollectionsAndTokensIdsLengthMismatched() public {
        tokenIds.push(1);
        tokenIds.push(2);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTooManyTokens() public {
        for (uint256 i = 0; i < 9; i++) {
            tokenIds.push(i);
            collections.push(address(nft1));
        }

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCallerIsNotTrader() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.WrongCaller.selector);
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTimestampIsNotInRange() public {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        // listingTime is late than expirationTime
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp + 10 days,
            expirationTime: uint64(block.timestamp),
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);

        // listingTime is equal to expirationTime
        offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: deploymentTimestamp,
            expirationTime: deploymentTimestamp,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);

        // listingTime is equal to block.timestamp
        offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: deploymentTimestamp,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);

        // listingTime is in the future
        offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: deploymentTimestamp + 1 days,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCollectionIsBlacklisted() public {
        tokenIds.push(1);
        tokenIds.push(2);
        collections.push(address(nft1));
        collections.push(address(nft2));

        vm.prank(owner);
        policyManager.blacklistContract(address(nft2));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTokenIsNotAllowed() public {
        tokenIds.push(1);
        tokenIds.push(2);
        collections.push(address(nft1));
        collections.push(address(nft2));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(token1),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldSucceed_WhenOfferIsValid() public {
        tokenIds.push(1);
        tokenIds.push(2);
        collections.push(address(nft1));
        collections.push(address(nft2));
        assetTypes.push(AssetType.ERC721);
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        swapspot.listOffer{value: 50 ether}(offer);

        assertEq(address(swapspot).balance, 50 ether);
        assertEq(swapspot.swapId(), 1);
    }

    function testCancelOffer_ShouldRevert_WhenCallerIsNotTrader() public {
        Offer memory offer = _initSimpleOffer(OfferType.Sell);

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.WrongCaller.selector);
        swapspot.cancelOffer(offer);
    }

    function testCancelOffer_ShouldRevert_WhenAlreadyCancelled() public {
        Offer memory offer = _initSimpleOffer(OfferType.Sell);

        vm.prank(users[0]);
        swapspot.cancelOffer(offer);

        vm.prank(users[0]);
        vm.expectRevert(SwapSpot.AlreadyCancelledOrFilled.selector);
        swapspot.cancelOffer(offer);
    }

    function testCancelOffer_ShouldSucceed_WhenOfferIsValid() public {
        Offer memory offer = _initSimpleOffer(OfferType.Sell);

        vm.prank(users[0]);
        swapspot.cancelOffer(offer);
    }

    function testCancelOffers_ShouldSucceed_WhenOffersAreValid() public {
        Offer memory offer1 = _initSimpleOffer(OfferType.Sell);
        vm.warp(1 seconds);
        Offer memory offer2 = _initSimpleOffer(OfferType.Sell);
        offers.push(offer1);
        offers.push(offer2);

        vm.prank(users[0]);
        swapspot.cancelOffers(offers);
    }

    /*//////////////////////////////////////////////////////////////
                            MAKE OFFER TESTS
    //////////////////////////////////////////////////////////////*/

    function _initSimpleOffer(OfferType side) internal returns (Offer memory) {
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory offer = Offer({
            trader: users[0],
            side: side,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        if (side == OfferType.Sell) swapspot.listOffer{value: 50 ether}(offer);

        delete tokenIds;
        delete collections;
        delete assetTypes;

        return offer;
    }

    function testMakeOffer_ShouldRevert_WhenCallerIsNotTrader() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[2]);
        vm.expectRevert(SwapSpot.WrongCaller.selector);
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenNotEnoughEthValue1() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.NotEnoughFunds.selector);
        swapspot.makeOffer{value: 1 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenNotEnoughEthValue2() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 10 ether,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.NotEnoughFunds.selector);
        swapspot.makeOffer{value: 11 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenMakerOfferIsSameAsTakerOffer() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        tokenIds.push(2);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[0],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        vm.expectRevert("Cannot make offer with yourself");
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenTakerOfferDoesNotMatchMakerOfferMatchingIdBecauseOfPrice() public {
        // swapId 1
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);

        // swapId 2
        tokenIds.push(1);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory wrongOffer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 1,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 0,
            assetTypes: assetTypes
        });

        delete tokenIds;
        delete collections;

        // makerOffer
        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 2,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.OffersDoNotMatch.selector);
        swapspot.makeOffer{value: 2 ether}(makerOffer, wrongOffer);
    }

    function testMakeOffer_ShouldRevert_WhenTakerOfferDoesNotMatchMakerOfferMatchingId() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        vm.warp(deploymentTimestamp + 1 days);
        Offer memory secondOffer = _initSimpleOffer(OfferType.Sell);

        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 2,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(SwapSpot.OffersDoNotMatch.selector);
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenTakerOfferIsCancelled() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);

        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[0]);
        swapspot.cancelOffer(takerOffer);

        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenListingParameterIsSell() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);

        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert("Only buy offers are allowed");
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldRevert_WhenTakerOfferIsExpired() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);
        vm.warp(deploymentTimestamp + 11 days);

        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);
    }

    function testMakeOffer_ShouldSucceed_WhenOffersAreValid() public {
        Offer memory takerOffer = _initSimpleOffer(OfferType.Sell);

        tokenIds.push(11);
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);
        Offer memory makerOffer = Offer({
            trader: users[1],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: 1,
            assetTypes: assetTypes
        });

        vm.prank(users[1]);
        swapspot.makeOffer{value: 2 ether}(makerOffer, takerOffer);

        assertEq(feeAddress.balance, 2 ether);
        assertEq(swapspot.swapId(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST ACCEPT OFFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function _createSimpleOffer(OfferType side, address user, uint128 mId) internal returns (Offer memory offer) {
        if (user == users[0]) {
            tokenIds.push(1);
        } else if (user == users[1]) {
            tokenIds.push(11);
        }
        collections.push(address(nft1));
        assetTypes.push(AssetType.ERC721);

        uint96 price;
        if (side == OfferType.Sell) {
            mId = 0;
            price = 0 ether;
        } else {
            price = 10 ether;
        }

        offer = Offer({
            trader: user,
            side: side,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: price,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: mId,
            assetTypes: assetTypes
        });

        delete tokenIds;
        delete collections;
        delete assetTypes;
    }

    function _createSimpleOffer8Length(OfferType side, address user, uint128 mId) internal returns (Offer memory offer) {
        if (user == users[0]) {
            for(uint i = 1; i < 9; i++) {
                tokenIds.push(i);
            }
        } else if (user == users[1]) {
            for(uint i = 11; i < 19; i++) {
                tokenIds.push(i);
            }
        }

        for (uint i = 0; i < 8; i++) {
            collections.push(address(nft1));
            assetTypes.push(AssetType.ERC721);
        }

        uint96 price;
        if (side == OfferType.Sell) {
            mId = 0;
            price = 0 ether;
        } else {
            price = 10 ether;
        }

        offer = Offer({
            trader: user,
            side: side,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: price,
            listingTime: uint64(block.timestamp) - 1,
            expirationTime: uint64(block.timestamp) + 10 days,
            matchingId: mId,
            assetTypes: assetTypes
        });

        delete tokenIds;
        delete collections;
        delete assetTypes;
    }

    function testAcceptOffer_ShouldSucceed_WhenOffersAreValid() public {
        Offer memory takerOffer = _createSimpleOffer(OfferType.Sell, users[0], 0);
        Offer memory makerOffer = _createSimpleOffer(OfferType.Buy, users[1], 1);

        uint256 takerBalanceBefore = users[0].balance;
        uint256 makerBalanceBefore = users[1].balance;

        vm.prank(users[0]);
        swapspot.listOffer{value: 50 ether}(takerOffer);

        vm.prank(users[1]);
        swapspot.makeOffer{value: 12 ether}(makerOffer, takerOffer);

        vm.prank(owner);
        executionDelegate.approveContract(address(swapspot));


        vm.prank(users[0]);
        swapspot.acceptOffer(makerOffer, takerOffer);

        uint256 takerBalanceAfter = users[0].balance;
        uint256 makerBalanceAfter = users[1].balance;

        assertEq(feeAddress.balance, 52 ether);
        assertEq(users[0], nft1.ownerOf(11));
        assertEq(users[1], nft1.ownerOf(1));
        assertEq(swapspot.swapId(), 2);

        // takerBalance -> 50 ETH of listing fees, get 10 from taker offer -> difference of 40 ETH
        // makerBalance -> 2 ETH of offer fees + 10 ETH from offer price -> difference of 12
        assertEq(takerBalanceBefore - takerBalanceAfter, 40 ether);
        assertEq(makerBalanceBefore - makerBalanceAfter, 12 ether);
    }

    function testAcceptOffer8Length_ShouldSucceed_WhenOffersAreValid() public {
        Offer memory takerOffer = _createSimpleOffer8Length(OfferType.Sell, users[0], 0);
        Offer memory makerOffer = _createSimpleOffer8Length(OfferType.Buy, users[1], 1);

        uint256 takerBalanceBefore = users[0].balance;
        uint256 makerBalanceBefore = users[1].balance;

        vm.prank(users[0]);
        swapspot.listOffer{value: 50 ether}(takerOffer);

        vm.prank(users[1]);
        swapspot.makeOffer{value: 12 ether}(makerOffer, takerOffer);

        vm.prank(owner);
        executionDelegate.approveContract(address(swapspot));


        vm.prank(users[0]);
        swapspot.acceptOffer(makerOffer, takerOffer);

        uint256 takerBalanceAfter = users[0].balance;
        uint256 makerBalanceAfter = users[1].balance;

        assertEq(feeAddress.balance, 52 ether);
        assertEq(users[0], nft1.ownerOf(11));
        assertEq(users[1], nft1.ownerOf(1));
        assertEq(swapspot.swapId(), 2);

        // takerBalance -> 50 ETH of listing fees, get 10 from taker offer -> difference of 40 ETH
        // makerBalance -> 2 ETH of offer fees + 10 ETH from offer price -> difference of 12
        assertEq(takerBalanceBefore - takerBalanceAfter, 40 ether);
        assertEq(makerBalanceBefore - makerBalanceAfter, 12 ether);
    }
}
