// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EscrowIVotesAdapter} from "@delegation/EscrowIVotesAdapter.sol";

/// @title SelfDelegationEscrowIVotesAdapter
/// @notice A minimal fork of EscrowIVotesAdapter that enforces self-delegation only
/// @dev Restricts users to only delegate their voting power to themselves.
///      Preserves all auto-delegation behavior from the parent contract:
///      1. Calling delegate(self) auto-delegates all existing tokens
///      2. Future locks are auto-delegated via moveDelegateVotes hook
contract SelfDelegationEscrowIVotesAdapter is EscrowIVotesAdapter {
    /// @notice Constructor with same signature as parent for deployment compatibility
    /// @param _coefficients Array of [constant, linear, quadratic] coefficients for voting power curve
    /// @param _maxEpochs Maximum number of epochs for the curve
    constructor(
        int256[3] memory _coefficients,
        uint256 _maxEpochs
    ) EscrowIVotesAdapter(_coefficients, _maxEpochs) {}

    /// @notice Override to enforce self-delegation only
    /// @dev Users can ONLY delegate to themselves. Attempting to delegate to others reverts.
    ///      Auto-delegation behavior is preserved:
    ///      - All existing tokens are immediately delegated to self
    ///      - Future locks auto-delegate via moveDelegateVotes hook
    /// @param _delegatee Must equal msg.sender, otherwise reverts with DelegationNotAllowed
    function delegate(address _delegatee) public override whenNotPaused {
        address sender = _msgSender();

        // ENFORCE: Only self-delegation allowed
        if (_delegatee != sender) {
            revert DelegationNotAllowed();
        }

        // Call parent implementation to preserve all auto-delegation logic
        super.delegate(_delegatee);
    }
}
