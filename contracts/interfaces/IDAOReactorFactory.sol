// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IRewardsPipeline.sol";

interface IDAOReactorFactory {
    function essence() external view returns (IERC20);

    function rewards() external view returns (IRewardsPipeline);

    function getAllDAOReactors() external view returns (address[] memory);

    function getAllActiveDAOReactors() external view returns (address[] memory);
}
