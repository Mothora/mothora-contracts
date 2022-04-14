// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;
pragma abicoder v2;

library LibUtils {

    // takes an arbitrary amount of bytes and makes it a bytes 32 object by keeping the rightmost data
    // similar to having "wwww.example.com" and keeping "example.com"
    function bytesToBytes32Left(bytes memory _b, uint256 offset) internal pure returns (bytes32) {
        bytes32 out;
        for (uint256 i = 0; i < 32; i++) {
            // BITWISE OR
            out |= bytes32(_b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }

    function bytesToBytes4Left(bytes memory _b) internal pure returns (bytes4) {
        bytes4 out;
        for (uint256 i = 0; i < 4; i++) {
            // BITWISE OR
            out |= bytes4(_b[i] & 0xFF) >> (i * 8);
        }
        return out;
    }

    function concatenate(bytes4 prefix, bytes32 corecid) internal pure returns (bytes memory) {
        bytes memory prefixB = abi.encodePacked(prefix);
        bytes memory coreCidB = abi.encodePacked(corecid);
        return abi.encodePacked(prefixB, coreCidB);
    }

    function toHex16 (bytes16 data) private pure returns (bytes32 result) {
        result = bytes32 (data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 |
            (bytes32 (data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
        result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000 |
            (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
        result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000 |
            (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
        result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000 |
            (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
        result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4 |
            (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
        result = bytes32 (0x3030303030303030303030303030303030303030303030303030303030303030 +
            uint256 (result) +
            (uint256 (result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4 &
            0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 39);
    }

    function toHex (bytes32 data) internal pure returns (string memory) {
        return string (abi.encodePacked (toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128))));
    }
}