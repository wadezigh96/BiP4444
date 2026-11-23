// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentID} from "../../contracts/interfaces/IAgentID.sol";

/// @dev Minimal mock of the SPACE ID Agent ID contract for unit tests.
///      Agent ID is non-transferable and limited to one per user, so a
///      simple balance map (0/1) faithfully models the real contract's
///      `balanceOf` behaviour for gate purposes.
contract MockAgentID is IAgentID {
    mapping(address => uint256) private _balances;

    function setBalance(address owner_, uint256 balance_) external {
        _balances[owner_] = balance_;
    }

    function balanceOf(address owner_) external view override returns (uint256) {
        return _balances[owner_];
    }
}
