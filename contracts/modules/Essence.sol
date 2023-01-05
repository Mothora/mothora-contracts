// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC1238/ERC1238.sol";
import "../ERC1238/utils/AddressMinimal.sol";

contract Essence is ERC1238 {
    using Address for address;
    address public owner;

    constructor(address owner_, string memory baseURI_) ERC1238(baseURI_) {
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: sender is not the owner");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1238) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address for new owner");
        owner = newOwner;
    }

    function mintToEOA(
        address to,
        uint256 id,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 approvalExpiry,
        bytes calldata data
    ) external onlyOwner {
        _mintToEOA(to, id, amount, v, r, s, approvalExpiry, data);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external onlyOwner {
        _burn(from, id, amount);
    }
}
