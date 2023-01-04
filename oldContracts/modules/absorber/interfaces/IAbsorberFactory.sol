// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IEssencePipeline.sol";

interface IAbsorberFactory {
    function essence() external view returns (IERC20);

    function essencePipeline() external view returns (IEssencePipeline);

    function getAllAbsorbers() external view returns (address[] memory);

    function getAllActiveAbsorbers() external view returns (address[] memory);
}
