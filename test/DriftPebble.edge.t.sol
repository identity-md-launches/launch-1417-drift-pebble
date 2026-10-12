// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {DriftPebble} from "src/DriftPebble.sol";

/// forge-config: default.fuzz.runs = 1000
contract DriftPebbleEdgeTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    DriftPebble private token;
    address private holder;
    address private recipient;
    address private spender;
    address private stranger;

    function setUp() public {
        holder = makeAddr("edge holder");
        recipient = makeAddr("edge recipient");
        spender = makeAddr("edge spender");
        stranger = makeAddr("edge stranger");
        vm.prank(holder);
        token = new DriftPebble();
    }

    function test_oneSmallestUnitTransfersWithoutRounding() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(holder, recipient, 1);
        vm.prank(holder);
        assertTrue(token.transfer(recipient, 1));
        assertEq(token.balanceOf(holder), SUPPLY - 1);
        assertEq(token.balanceOf(recipient), 1);
        vm.prank(recipient);
        assertTrue(token.transfer(holder, 1));
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumTransferFailsWithoutArithmeticPanic() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, SUPPLY, type(uint256).max)
        );
        vm.prank(holder);
        token.transfer(recipient, type(uint256).max);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumDelegatedTransferCannotOverflowOrSpendAllowance() public {
        _approve(holder, spender, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, SUPPLY, type(uint256).max)
        );
        vm.prank(spender);
        token.transferFrom(holder, recipient, type(uint256).max);
        assertEq(token.allowance(holder, spender), type(uint256).max);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumMinusOneIsFiniteAllowance() public {
        _approve(holder, spender, type(uint256).max - 1);
        vm.startPrank(spender);
        assertTrue(token.transferFrom(holder, recipient, 1));
        assertTrue(token.transferFrom(holder, recipient, SUPPLY - 1));
        vm.stopPrank();
        assertEq(token.allowance(holder, spender), type(uint256).max - 1 - SUPPLY);
        assertEq(token.balanceOf(holder), 0);
        assertEq(token.balanceOf(recipient), SUPPLY);
    }

    function test_ownerCallingTransferFromStillNeedsSelfAllowance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, holder, 0, 1));
        vm.prank(holder);
        token.transferFrom(holder, recipient, 1);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);

        _approve(holder, holder, 1);
        vm.prank(holder);
        assertTrue(token.transferFrom(holder, recipient, 1));
        assertEq(token.allowance(holder, holder), 0);
        assertEq(token.balanceOf(holder), SUPPLY - 1);
        assertEq(token.balanceOf(recipient), 1);
    }

    function test_selfTransfersStillCheckBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, SUPPLY, SUPPLY + 1)
        );
        vm.prank(holder);
        token.transfer(holder, SUPPLY + 1);

        _approve(holder, spender, SUPPLY + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, SUPPLY, SUPPLY + 1)
        );
        vm.prank(spender);
        token.transferFrom(holder, holder, SUPPLY + 1);
        assertEq(token.allowance(holder, spender), SUPPLY + 1);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroDelegatedTransferStillRejectsZeroRecipient() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(holder, address(0), 0);
        assertEq(token.allowance(holder, spender), 0);

        _approve(holder, spender, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(holder, address(0), 0);
        assertEq(token.allowance(holder, spender), type(uint256).max);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferFromZeroCannotMintEvenForZeroAmount() public {
        // Only rejection is specified here: allowance validation may run before sender validation.
        uint256[3] memory amounts = [uint256(0), uint256(1), type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            vm.expectRevert();
            vm.prank(spender);
            token.transferFrom(address(0), recipient, amounts[i]);
        }
        assertEq(token.allowance(address(0), spender), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroApprovalStillRejectsZeroSpender() public {
        _approve(holder, spender, 7);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(holder);
        token.approve(address(0), 0);
        assertEq(token.allowance(holder, spender), 7);
        assertEq(token.allowance(holder, address(0)), 0);
        assertEq(token.balanceOf(holder), SUPPLY);
    }

    function test_originCannotAuthorizeAnUnapprovedCaller() public {
        _approve(holder, spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, stranger, 0, 1));
        vm.prank(stranger, spender);
        token.transferFrom(holder, recipient, 1);
        assertEq(token.allowance(holder, spender), 10);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, stranger, 0, 1));
        vm.prank(stranger, holder);
        token.transfer(recipient, 1);

        vm.prank(stranger, holder);
        assertTrue(token.approve(spender, 3));
        assertEq(token.allowance(stranger, spender), 3);
        assertEq(token.allowance(holder, spender), 10);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
    }

    function test_approvalCanPrecedeFundingAndIsIsolatedByOwnerAndSpender() public {
        _approve(recipient, spender, type(uint256).max);
        _approve(holder, spender, 7);
        _approve(recipient, stranger, 9);
        vm.prank(holder);
        assertTrue(token.transfer(recipient, 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(recipient, holder, 1));
        assertEq(token.allowance(recipient, spender), type(uint256).max);
        assertEq(token.allowance(holder, spender), 7);
        assertEq(token.allowance(recipient, stranger), 9);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
    }

    function test_spenderCanBeRecipientAndSpendEntireSupply() public {
        _approve(holder, spender, SUPPLY);
        vm.prank(spender);
        assertTrue(token.transferFrom(holder, spender, SUPPLY));
        assertEq(token.balanceOf(holder), 0);
        assertEq(token.balanceOf(spender), SUPPLY);
        assertEq(token.allowance(holder, spender), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(holder, spender, 1);
        assertEq(token.balanceOf(spender), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferRoundTripPreservesBalancesAndApprovals(uint256 amount, uint256 approved) public {
        amount = bound(amount, 0, SUPPLY);
        _approve(holder, spender, approved);
        _approve(recipient, spender, approved);
        vm.prank(holder);
        assertTrue(token.transfer(recipient, amount));
        vm.prank(recipient);
        assertTrue(token.transfer(holder, amount));
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.allowance(holder, spender), approved);
        assertEq(token.allowance(recipient, spender), approved);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitTransfersEqualSingleTransfer(uint256 amount, uint256 first) public {
        amount = bound(amount, 0, SUPPLY);
        first = bound(first, 0, amount);
        vm.prank(holder);
        DriftPebble single = new DriftPebble();
        vm.startPrank(holder);
        assertTrue(single.transfer(recipient, amount));
        assertTrue(token.transfer(recipient, first));
        assertTrue(token.transfer(recipient, amount - first));
        vm.stopPrank();
        assertEq(token.balanceOf(holder), single.balanceOf(holder));
        assertEq(token.balanceOf(recipient), single.balanceOf(recipient));
        assertEq(token.totalSupply(), single.totalSupply());
    }

    function testFuzz_failedSpendCanSucceedAfterFunding(uint256 balance, uint256 amount, bool unlimited) public {
        balance = bound(balance, 0, SUPPLY - 1);
        amount = bound(amount, balance + 1, SUPPLY);
        vm.prank(holder);
        assertTrue(token.transfer(recipient, balance));
        uint256 approved = unlimited ? type(uint256).max : amount;
        _approve(recipient, spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, recipient, balance, amount)
        );
        vm.prank(spender);
        token.transferFrom(recipient, holder, amount);
        assertEq(token.allowance(recipient, spender), approved);
        assertEq(token.balanceOf(recipient), balance);
        assertEq(token.balanceOf(holder), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);

        vm.prank(holder);
        assertTrue(token.transfer(recipient, amount - balance));
        vm.prank(spender);
        assertTrue(token.transferFrom(recipient, holder, amount));
        assertEq(token.allowance(recipient, spender), unlimited ? type(uint256).max : 0);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_replacingInfiniteApprovalEnforcesNewLimit(uint256 limit) public {
        limit = bound(limit, 0, SUPPLY - 1);
        _approve(holder, spender, type(uint256).max);
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(holder, spender, limit);
        _approve(holder, spender, limit);
        assertEq(token.allowance(holder, spender), limit);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, limit, limit + 1)
        );
        vm.prank(spender);
        token.transferFrom(holder, recipient, limit + 1);
        assertEq(token.allowance(holder, spender), limit);
        assertEq(token.balanceOf(holder), SUPPLY);
        assertEq(token.balanceOf(recipient), 0);

        vm.prank(spender);
        assertTrue(token.transferFrom(holder, recipient, limit));
        assertEq(token.allowance(holder, spender), 0);
        assertEq(token.balanceOf(holder), SUPPLY - limit);
        assertEq(token.balanceOf(recipient), limit);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function _approve(address owner, address approvedSpender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(approvedSpender, amount));
    }
}
