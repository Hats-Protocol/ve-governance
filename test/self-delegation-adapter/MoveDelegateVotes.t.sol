pragma solidity ^0.8.17;

import {Base} from "./Base.sol";
import {ILockedBalanceIncreasing, VotingEscrow} from "../v1_4_0/versions.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";

contract TestMoveDelegateVotes is Base {
    function setUp() public override {
        super.setUp();
    }

    function test_shouldRevertIfPaused() public {
        dg.pause();

        vm.expectRevert("Pausable: paused");
        dg.moveDelegateVotes(alice, bob, 1, ILockedBalanceIncreasing.LockedBalance(0, 0));
    }

    function testRevert_IfNotCalledByEscrow() public {
        vm.expectRevert(OnlyEscrow.selector);
        dg.moveDelegateVotes(alice, bob, 1, ILockedBalanceIncreasing.LockedBalance(0, 0));
    }

    function test_OnlyUpdatesFromDelegateeWhenToIsNotSet() public {
        address tokenOwner = address(567);
        uint256 start = weekStartTs((block.timestamp));

        {
            // In self-delegation adapter, tokenOwner can only delegate to themselves
            vm.startPrank(tokenOwner);
            uint256[] memory ids = getIds(1, 2);
            _mockOwnedTokens(tokenOwner, ids);
            _mockLocked(ids[0], 10, start);
            _mockLocked(ids[1], 15, start);
            dg.delegate(tokenOwner); // Changed from alice to tokenOwner (self-delegation)
            vm.stopPrank();
        }

        uint256 token1Bias = bias(10, block.timestamp - start);
        uint256 token2Bias = bias(15, block.timestamp - start);
        uint256 total = token1Bias + token2Bias;

        assertEq(dg.getVotes(tokenOwner), total); // Changed from alice to tokenOwner
        assertEq(dg.getVotes(bob), 0);

        vm.startPrank(address(escrow));
        {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = 1;
            vm.expectEmit();
            emit TokensUndelegated(tokenOwner, tokenOwner, tokenIds); // Changed from alice to tokenOwner
            dg.moveDelegateVotes(tokenOwner, bob, 1, VotingEscrow(address(escrow)).locked(1));
        }
        vm.stopPrank();

        assertEq(dg.getVotes(tokenOwner), token2Bias); // Changed from alice to tokenOwner
        assertEq(dg.getVotes(bob), 0);
    }

    function test_OnlyUpdatesToDelegateeWhenFromIsNotSet() public {
        address tokenReceiver = address(567);

        vm.startPrank(tokenReceiver);
        dg.setAutoDelegationDisabled(true);
        dg.setDelegateAddress(bob);
        vm.stopPrank();

        _mockLocked(1, 10, weekStartTs((block.timestamp)));

        assertEq(dg.getVotes(bob), 0);

        vm.startPrank(address(escrow));
        {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = 1;
            vm.expectEmit();
            emit TokensDelegated(tokenReceiver, bob, tokenIds);
            dg.moveDelegateVotes(sender, tokenReceiver, 1, VotingEscrow(address(escrow)).locked(1));
        }
        vm.stopPrank();

        assertEq(dg.getVotes(bob), bias(10, block.timestamp - weekStartTs((block.timestamp))));
    }

    function test_UpdateBothDelegates() public {
        address tokenOwner = address(567);
        address tokenReceiver = address(678);

        uint256 start = weekStartTs((block.timestamp));
        _mockLocked(1, 10, start);
        _mockLocked(2, 15, start);

        {
            // In self-delegation adapter, tokenOwner can only delegate to themselves
            vm.startPrank(tokenOwner);
            uint256[] memory ids = getIds(1, 2);
            _mockOwnedTokens(tokenOwner, ids);
            _mockLocked(ids[0], 10, start);
            _mockLocked(ids[1], 15, start);
            dg.delegate(tokenOwner); // Changed from alice to tokenOwner (self-delegation)
            vm.stopPrank();
        }

        {
            // In self-delegation adapter, tokenReceiver can only delegate to themselves
            vm.startPrank(tokenReceiver);
            dg.setAutoDelegationDisabled(true);
            dg.setDelegateAddress(tokenReceiver); // Changed from bob to tokenReceiver (self-delegation)
            vm.stopPrank();
        }

        uint256 token1Bias = bias(10, block.timestamp - start);
        uint256 token2Bias = bias(15, block.timestamp - start);
        uint256 total = token1Bias + token2Bias;

        assertEq(dg.getVotes(tokenOwner), total); // Changed from alice to tokenOwner
        assertEq(dg.getVotes(tokenReceiver), 0); // Changed from bob to tokenReceiver

        vm.startPrank(address(escrow));
        {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = 1;
            vm.expectEmit();
            emit TokensUndelegated(tokenOwner, tokenOwner, tokenIds); // Changed from alice to tokenOwner
            vm.expectEmit();
            emit TokensDelegated(tokenReceiver, tokenReceiver, tokenIds); // Changed from bob to tokenReceiver
            dg.moveDelegateVotes(
                tokenOwner,
                tokenReceiver,
                1,
                VotingEscrow(address(escrow)).locked(1)
            );
        }
        vm.stopPrank();

        assertEq(dg.getVotes(tokenOwner), token2Bias); // Changed from alice to tokenOwner
        assertEq(dg.getVotes(tokenReceiver), token1Bias); // Changed from bob to tokenReceiver
    }
}
