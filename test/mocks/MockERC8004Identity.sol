// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004Identity} from "../../contracts/interfaces/IERC8004Identity.sol";

/// @dev Minimal mock of ERC-8004 Identity Registry for unit tests.
contract MockERC8004Identity is IERC8004Identity {
    mapping(uint256 => address) private _owners;

    error NonexistentAgent();

    function setOwner(uint256 agentId, address owner_) external {
        _owners[agentId] = owner_;
    }

    function ownerOf(uint256 agentId) external view override returns (address) {
        address o = _owners[agentId];
        if (o == address(0)) revert NonexistentAgent();
        return o;
    }

    function getAgent(uint256 agentId)
        external
        view
        override
        returns (address owner, string memory metadataURI, uint256 registeredAt)
    {
        owner = this.ownerOf(agentId);
        metadataURI = "";
        registeredAt = 0;
    }
}
