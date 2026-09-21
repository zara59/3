// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenLauchpad.sol";

contract TokenLaunchpadTest is Test {
    TokenLaunchpad launchpad;

    address creator = address(1);
    address buyer = address(2);
    address stranger = address(3);

    uint256 tokenPrice = 0.001 ether;
    uint256 maxRaise = 10 ether;
    uint256 deadline;

    function setUp() public {
        deadline = block.timestamp + 7 days;

        vm.prank(creator);

        launchpad = new TokenLaunchpad(tokenPrice, maxRaise, deadline);
        vm.stopPrank();

        vm.deal(buyer, 20 ether);
    }

    function test_buyTokens() public {
        vm.prank(buyer);

        launchpad.buyTokens{value: 2 ether}();

        assertEq(launchpad.contributions(buyer), 2 ether);
        assertEq(launchpad.totalRaised(), 2 ether);
    }

    function test_cannotExceedMaxRaise() public {
        vm.prank(buyer);

        vm.expectRevert(TokenLaunchpad.MaxRaiseExceeded.selector);

        launchpad.buyTokens{value: 11 ether}();
    }

    function test_cannotBuyAfterDeadline() public {
        vm.warp(deadline);

        vm.prank(buyer);

        vm.expectRevert(TokenLaunchpad.SaleEnded.selector);

        launchpad.buyTokens{value: 1 ether}();
    }

    function test_strangerCannotFinalize() public {
        vm.prank(buyer);
        launchpad.buyTokens{value: 10 ether}();

        vm.prank(stranger);

        vm.expectRevert(TokenLaunchpad.NotCreator.selector);

        launchpad.finalize();
    }

    function test_finalizeAtMaxRaise() public {
        vm.prank(buyer);
        launchpad.buyTokens{value: 10 ether}();

        uint256 creatorBefore = creator.balance;

        vm.prank(creator);
        launchpad.finalize();

        assertTrue(launchpad.finalized());
        assertEq(creator.balance, creatorBefore + 10 ether);
    }

    function test_cancelAndRefund() public {
        vm.prank(buyer);
        launchpad.buyTokens{value: 2 ether}();

        vm.prank(creator);
        launchpad.cancel();

        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        launchpad.refund();

        assertEq(buyer.balance, balanceBefore + 2 ether);
        assertEq(launchpad.contributions(buyer), 0);
    }
}
