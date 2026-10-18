// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal ERC-1271 wallet mock for deterministic signature-validation tests.
contract MockERC1271Wallet {
    bytes4 private constant _MAGICVALUE = 0x1626ba7e;
    bytes32 public approvedHash;

    function approveHash(bytes32 hash) external {
        approvedHash = hash;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (hash == approvedHash && signature.length != 0) return _MAGICVALUE;
        return 0xffffffff;
    }
}
