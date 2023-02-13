// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IStream {
    function preRateUpdate() external;

    function postRateUpdate() external;
}
