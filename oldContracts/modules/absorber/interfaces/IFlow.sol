// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IFlow {
    function preRateUpdate() external;

    function postRateUpdate() external;
}
