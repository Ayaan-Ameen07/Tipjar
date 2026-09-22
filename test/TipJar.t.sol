// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TipJar} from "../src/TipJar.sol";

contract TipJarTest is Test {
    TipJar public jar;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event Tipped(address indexed from, uint256 amount, uint256 newTotal);

    function setUp() public {
        jar = new TipJar();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // Lets this test contract (the owner in these tests) accept the ETH from withdraw().
    receive() external payable {}

    function test_OwnerIsDeployer() public view {
        assertEq(jar.owner(), owner);
    }

    function test_Deposit_TracksPerAddressTotal() public {
        vm.prank(alice);
        jar.deposit{value: 1 ether}();

        assertEq(jar.totalTipped(alice), 1 ether);
        assertEq(jar.totalReceived(), 1 ether);
    }

    function test_Deposit_AccumulatesAcrossRepeatCalls() public {
        vm.startPrank(alice);
        jar.deposit{value: 1 ether}();
        jar.deposit{value: 2 ether}();
        vm.stopPrank();

        assertEq(jar.totalTipped(alice), 3 ether);
        assertEq(jar.totalReceived(), 3 ether);
    }

    function test_Deposit_TracksMultipleAddressesIndependently() public {
        vm.prank(alice);
        jar.deposit{value: 1 ether}();

        vm.prank(bob);
        jar.deposit{value: 5 ether}();

        assertEq(jar.totalTipped(alice), 1 ether);
        assertEq(jar.totalTipped(bob), 5 ether);
        assertEq(jar.totalReceived(), 6 ether);
    }

    function test_Deposit_RevertsOnZeroValue() public {
        vm.prank(alice);
        vm.expectRevert("TipJar: zero deposit");
        jar.deposit{value: 0}();
    }

    function test_Deposit_EmitsTippedEventWithRunningTotal() public {
        vm.prank(alice);
        jar.deposit{value: 1 ether}();

        vm.expectEmit(true, false, false, true);
        emit Tipped(alice, 2 ether, 3 ether);
        vm.prank(alice);
        jar.deposit{value: 2 ether}();
    }

    function test_ReceiveFallback_CountsAsTip() public {
        vm.prank(alice);
        (bool success, ) = address(jar).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(jar.totalTipped(alice), 1 ether);
    }

    function test_Withdraw_SendsFullBalanceToOwner() public {
        vm.prank(alice);
        jar.deposit{value: 3 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        jar.withdraw();

        assertEq(address(jar).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + 3 ether);
    }

    function test_Withdraw_DoesNotResetLifetimeTotals() public {
        vm.prank(alice);
        jar.deposit{value: 3 ether}();

        jar.withdraw();

        assertEq(jar.totalTipped(alice), 3 ether);
        assertEq(jar.totalReceived(), 3 ether);
    }

    function test_Withdraw_RevertsForNonOwner() public {
        vm.prank(alice);
        jar.deposit{value: 1 ether}();

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob)
        );
        jar.withdraw();
    }

    function test_Withdraw_RevertsWhenNothingToWithdraw() public {
        vm.expectRevert("TipJar: nothing to withdraw");
        jar.withdraw();
    }

    function testFuzz_Deposit_AccumulatesCorrectly(uint96 a, uint96 b) public {
        vm.assume(a > 0 && b > 0);
        vm.deal(alice, uint256(a) + uint256(b));

        vm.startPrank(alice);
        jar.deposit{value: a}();
        jar.deposit{value: b}();
        vm.stopPrank();

        assertEq(jar.totalTipped(alice), uint256(a) + uint256(b));
    }
}
