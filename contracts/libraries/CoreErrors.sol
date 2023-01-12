// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library CoreErrors {
    /**
     * @dev User not recovered correctly
     */
    error INVALID_SIGNATURE();

    /**
     * @dev Mint request has expired
     */
    error REQUEST_EXPIRED();

    /**
     * @dev Essence tokens recipient is address 0
     */
    error RECIPIENT_UNDEFINED();
}
