// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {Utilities} from "test/utils/Utilities.sol";

import {SwapSpot} from "src/SwapSpot.sol";
import {PolicyManager} from "src/PolicyManager.sol";
import {ExecutionDelegate} from "src/ExecutionDelegate.sol";

import { Offer, Fee, OfferType } from "src/lib/OfferStruct.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {mockERC20} from "src/mock/mockERC20.sol";
import {mockERC721} from "src/mock/mockERC721.sol";
import {mockERC1155} from "src/mock/mockERC1155.sol";

import "forge-std/console.sol"; 

contract SwapSpotTest is DSTest {
    SwapSpot internal swapspot;
    PolicyManager internal policyManager;
    ExecutionDelegate executionDelegate;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address internal owner;

    mockERC20 internal token1;
    mockERC20 internal token2;

    mockERC721 internal nft1;
    mockERC721 internal nft2;
    mockERC721 internal nft3;

    mockERC1155 internal erc1155_1;
    mockERC1155 internal erc1155_2;

    uint256[] internal tokenIds;
    address[] internal collections;

    uint256 internal timestamp = block.timestamp;
    uint256 internal deploymentTimestamp = timestamp + 1 days;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(2);

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
        swapspot.initialize(address(executionDelegate), address(policyManager));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
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
        swapspot.initialize(address(executionDelegate), address(policyManager));
    }

    function testInitialize_ShouldHaveRightOwner_WhenDeployed() public {
        assertEq(address(swapspot.owner()), owner);
    }

    function testInitialize_ShouldHaveSetRightValues_WhenDeployed() public {
        assertEq(address(swapspot.executionDelegate()), address(executionDelegate));
        assertEq(address(swapspot.policyManager()), address(policyManager));
        assertEq(swapspot.isOpen(), 1);

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

    function testListOfer_ShouldRevert_WhenNotEnoughEthValue() public {
        tokenIds.push(1);
        collections.push(address(nft1));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
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

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[0]);
        vm.expectRevert(SwapSpot.NotOpen.selector);
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenListingParameterIsBuy() public {
        tokenIds.push(1);
        collections.push(address(nft1));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Buy,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[0]);
        vm.expectRevert("Only sell offers are allowed");
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenMatchingIdIs1() public {
        tokenIds.push(1);
        collections.push(address(nft1));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 1
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTokenIdsLengthIs0() public {
        collections.push(address(nft1));
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCollectionsLengthIs0() public {
        tokenIds.push(1);
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCollectionsAndTokensIdsLengthMismatched() public {
        tokenIds.push(1);
        tokenIds.push(2);
        collections.push(address(nft1));
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
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
            matchingId: 0
        });

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenCallerIsNotTrader() public {
        tokenIds.push(1);
        collections.push(address(nft1));

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[1]);
        vm.expectRevert(abi.encodeWithSelector(SwapSpot.OfferInvalidParameters.selector, 0));
        swapspot.listOffer{value: 50 ether}(offer);
    }

    function testListOffer_ShouldRevert_WhenTimestampIsNotInRange() public {
        tokenIds.push(1);
        collections.push(address(nft1));

        // listingTime is late than expirationTime
        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp + 10 days,
            expirationTime: block.timestamp,
            matchingId: 0
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
            matchingId: 0
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
            expirationTime: block.timestamp + 10 days,
            matchingId: 0
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
            expirationTime: block.timestamp + 10 days,
            matchingId: 0
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
            matchingId: 0
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
            matchingId: 0
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

        Offer memory offer = Offer({
            trader: users[0],
            side: OfferType.Sell,
            collections: collections,
            tokenIds: tokenIds,
            paymentToken: address(0),
            price: 0,
            listingTime: timestamp,
            expirationTime: deploymentTimestamp + 10 days,
            matchingId: 0
        });

        vm.prank(users[0]);
        swapspot.listOffer{value: 50 ether}(offer);

        assertEq(address(swapspot).balance, 50 ether);
    }


}