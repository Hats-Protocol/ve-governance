pragma solidity ^0.8.17;

import {Base} from "./Base.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";

contract TestDelegate is Base {
    function setUp() public override {
        super.setUp();
    }

    event DelegateChanged(address indexed from, address indexed to, address indexed delegate);

    modifier AutoDelegationEnabled() {
        dg.setAutoDelegationDisabled(false);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                      IVotes Delegate
    //////////////////////////////////////////////////////////////*/
    function test_shouldRevertIfPaused_IVotesDelegate() public {
        dg.pause();

        vm.expectRevert("Pausable: paused");
        dg.delegate(address(1));
    }

    function test_Sets_DelegateeForFirstTime() public {
        // In SelfDelegation adapter, can only delegate to self
        _mockOwnedTokens(address(this), new uint256[](0));

        // Should revert when trying to delegate to alice (not self)
        vm.expectRevert(DelegationNotAllowed.selector);
        dg.delegate(alice);

        // Should succeed when delegating to self
        vm.expectEmit();
        emit DelegateChanged(sender, address(0), sender);
        dg.delegate(sender);

        assertEq(dg.delegates(sender), sender);
        assertEq(dg.numberOfDelegatedTokens(sender), 0);
    }

    function test_Updates_Delegatee() public {
        // In SelfDelegation adapter, can only update to self
        _mockOwnedTokens(address(this), new uint256[](0));
        dg.delegate(sender);

        // Should revert when trying to update to bob (not self)
        vm.expectRevert(DelegationNotAllowed.selector);
        dg.delegate(bob);

        // Should succeed when updating to self (idempotent)
        vm.expectEmit();
        emit DelegateChanged(sender, sender, sender);
        dg.delegate(sender);

        assertEq(dg.delegates(sender), sender);
        assertEq(dg.numberOfDelegatedTokens(sender), 0);
    }

    function test_UndelegatesAndDelegatesToNewAddress() public {
        // In SelfDelegation adapter, can only delegate to self, not to bob
        // This test verifies that delegation to non-self addresses fails
        address sender = address(this);

        uint256[] memory ownedTokens = new uint256[](3);
        ownedTokens[0] = 1;
        ownedTokens[1] = 2;
        ownedTokens[2] = 3;

        _mockOwnedTokens(sender, ownedTokens);
        _mockLocked(ownedTokens[0], 101, weekStartTs(block.timestamp));
        _mockLocked(ownedTokens[1], 102, weekStartTs(block.timestamp));
        _mockLocked(ownedTokens[2], 103, weekStartTs(block.timestamp));
        _mockVotingPower(ownedTokens[0], 1);
        _mockVotingPower(ownedTokens[1], 1);
        _mockVotingPower(ownedTokens[2], 1);

        // Should revert when trying to delegate to alice (not self)
        dg.setAutoDelegationDisabled(true);
        vm.expectRevert(DelegationNotAllowed.selector);
        dg.delegate(alice);

        // Should revert when trying to delegate to bob (not self)
        dg.setAutoDelegationDisabled(false);
        vm.expectRevert(DelegationNotAllowed.selector);
        dg.delegate(bob);
    }

    /*//////////////////////////////////////////////////////////////
                    Delegate(uint256[] tokenIds)
    //////////////////////////////////////////////////////////////*/
    function test_shouldRevertIfPaused() public {
        // These tests are for delegate(tokenIds), which work independently
        // of self-delegation restrictions (they use the set delegatee address)
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        dg.pause();

        vm.expectRevert("Pausable: paused");
        dg.delegate(getIds(1));
    }

    function testRevert_IfNotAllowed() public {
        dao.revoke({
            _who: address(type(uint160).max),
            _where: address(dg),
            _permissionId: dg.DELEGATION_TOKEN_ROLE()
        });
        bytes memory data = abi.encodeWithSelector(
            DaoUnauthorized.selector,
            address(dao),
            address(dg),
            address(this),
            dg.DELEGATION_TOKEN_ROLE()
        );
        vm.expectRevert(data);
        dg.delegate(new uint256[](0));
    }

    function testRevert_IfNoDelegateeIsSet() public {
        vm.expectRevert(DelegateeNotSet.selector);

        dg.delegate(singleId);
    }

    function testRevert_IfTokenListEmpty() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        vm.expectRevert(TokenListEmpty.selector);
        dg.delegate(new uint256[](0));
    }

    function testRevert_IfVotingPowerZeroAtLeastForOneToken() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        _mockLocked(multiIds[0], 10, weekStartTs(block.timestamp));
        _mockLocked(multiIds[1], 10, weekStartTs(block.timestamp));

        _mockVotingPower(multiIds[0], 1);
        _mockVotingPower(multiIds[1], 0);

        vm.expectRevert(abi.encodeWithSelector(VotingPowerZero.selector, multiIds[1]));
        dg.delegate(multiIds);
    }

    function testRevert_IfNotApprovedOrOwner() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        _mockApprovedOwner(false);

        vm.expectRevert(NotApprovedOrOwner.selector);
        dg.delegate(singleId);
    }

    function testRevert_IfTokenAlreadyDelegated() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        _mockLocked(singleId[0], 10, weekStartTs(block.timestamp));
        dg.delegate(singleId);

        vm.expectRevert(abi.encodeWithSelector(TokenAlreadyDelegated.selector, singleId[0]));

        dg.delegate(singleId);
    }

    function test_EmitsTheEvents() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation

        _mockLocked(multiIds[0], 10, weekStartTs(block.timestamp));
        _mockLocked(multiIds[1], 10, weekStartTs(block.timestamp));

        vm.expectEmit();
        emit TokensDelegated(sender, sender, multiIds); // Changed alice to sender

        dg.delegate(multiIds);
    }

    function test_CorrectlySetsDelegatedTokenCount() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation
        uint256 start = weekStartTs((block.timestamp));

        _mockLocked(multiIds[0], 10, start);
        _mockLocked(multiIds[1], 10, start);
        dg.delegate(multiIds);

        assertEq(dg.numberOfDelegatedTokens(sender), multiIds.length);

        _mockLocked(3, 10, start);
        _mockVotingPower(3, 1);

        dg.delegate(getIds(3));

        assertEq(dg.numberOfDelegatedTokens(sender), multiIds.length + 1);
    }

    function test_SetsDelegatedTokenToTrue() public {
        dg.setDelegateAddress(sender); // Changed to sender for self-delegation
        _mockLocked(1, 10, weekStartTs((block.timestamp)));
        dg.delegate(getIds(1));

        assertEq(dg.tokenIsDelegated(1), true);
    }
}
