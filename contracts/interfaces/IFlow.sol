// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IFlow {
    function preRateUpdate() external;

    function postRateUpdate() external;
}
