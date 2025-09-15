// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/CSVVault.sol";

/**
 * @dev Test harness for CSVVault to expose internal pre-mint/vintage checks.
 *      Only included in test builds!
 */
contract CSVVaultHarness is CSVVault {
    constructor(address oracle) CSVVault(oracle) {}

    function __test__preMint(bytes32 carrier, uint64 issueTs, uint256 addBps) external view {
        _enforceVintage(issueTs);
        _preMintChecks(carrier, addBps);
    }
}