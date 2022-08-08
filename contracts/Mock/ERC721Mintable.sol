// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract ERC721Mintable is ERC721PresetMinterPauserAutoId("name", "symbol", "uri/") {
    function mint(address to) public override {
        _setupRole(MINTER_ROLE, msg.sender);
        super.mint(to);
    }

    function mintWithId(address to, uint256 tokenId) public {
        _setupRole(MINTER_ROLE, msg.sender);
        super._mint(to, tokenId);
    }
}
