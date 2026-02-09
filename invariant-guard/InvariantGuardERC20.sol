// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
import "./InvariantGuardHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Wrapper for an array of ERC20 tokens subject to invariant checks
 */
struct ERC20ArrayInvariant {
    IERC20[] tokenERC20ArrayInvariant;
}

/// @notice ERC20 balance invariant violation
/// @custom:invariant erc20.balance: ERC20 balances must satisfy the delta constraint
error InvariantViolationERC20BalanceArray(ERC20ArrayInvariant tokenERC20ArrayInvariant, AccountArrayInvariant accountArrayInvariant, ValuePerPosition[] ERC20BalancePerPosition);

/**
 * @title InvariantGuardERC20
 * @author Helkomine (@Helkomine)
 *
 * @notice
 * Provides invariant protection for ERC20 token balances.
 *
 * @dev
 * This contract performs external balance queries against ERC20 token contracts.
 * As a result, it operates under a trust assumption:
 * - If a token contract exhibits non-standard, malicious, or metamorphic behavior,
 *   the observed balances may be non-deterministic.
 *
 * This design choice is intentional and accepted, as balance inspection requires
 * external calls by nature.
 *
 * Supported invariant categories:
 * - Balance invariants across one or more specified ERC20 tokens
 * - Balance invariants across one or more specified accounts
 *
 * Intended usage:
 * - Inherit this contract
 * - Apply the provided modifiers to state-mutating functions
 * - Reverts execution if any configured invariant is violated
 */
abstract contract InvariantGuardERC20 {
    using InvariantGuardHelper for *;

    /**
     * @notice
     * Ensures that ERC20 balances remain unchanged for the given token-account pairs
     * across the execution of the protected function.
     *
     * @param tokenArray   Array of ERC20 tokens to observe
     * @param accountArray Array of accounts whose balances are tracked
     */
    modifier invariantERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processConstantERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray);
    }

    /**
     * @notice
     * Asserts that the ERC20 balances equal the expected values after execution.
     *
     * @param tokenArray    Array of ERC20 tokens to observe
     * @param accountArray  Array of accounts whose balances are checked
     * @param expectedArray Expected balance values
     */
    modifier assertERC20BalanceEquals(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processConstantERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), actualBalanceArray, expectedArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances increase by an exact amount.
     */
    modifier exactIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processExactIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactIncreaseArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances increase by no more than the specified maximum.
     */
    modifier maxIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMaxIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxIncreaseArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances increase by at least the specified minimum.
     */
    modifier minIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMinIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minIncreaseArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances decrease by an exact amount.
     */
    modifier exactDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processExactDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactDecreaseArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances decrease by no more than the specified maximum.
     */
    modifier maxDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMaxDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxDecreaseArray);
    }

    /**
     * @notice
     * Ensures that ERC20 balances decrease by at least the specified minimum.
     */
    modifier minDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMinDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minDecreaseArray);
    }

    /**
     * @dev
     * Returns the ERC20 balance of a single account.
     */
    function _getERC20Balance(IERC20 token, address account) private view returns (uint256) {
        return token.balanceOf(account);
    }

    /**
     * @dev
     * Returns an array of ERC20 balances for corresponding token-account pairs.
     *
     * Requirements:
     * - `tokenArray.length == accountArray.length`
     * - Array length must not exceed the configured maximum
     */
    function _getERC20BalanceArray(IERC20[] memory tokenArray, address[] memory accountArray) private view returns (uint256[] memory) {
        uint256 length = accountArray._getAddressArrayLength();
        length._revertIfArrayTooLarge();
        uint256[] memory balanceArray = new uint256[](length);
        for (uint256 i = 0 ; i < length ; ) {
            balanceArray[i] = _getERC20Balance(tokenArray[i], accountArray[i]);
            unchecked { ++i; }
        }
        return balanceArray;
    }

    /**
     * @dev
     * Validates that ERC20 balances remain unchanged.
     */
    function _processConstantERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, beforeBalanceArray._getUint256ArrayLength()._emptyArray(), DeltaConstraint.NO_CHANGE);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processExactIncreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactIncreaseArray, DeltaConstraint.INCREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMaxIncreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxIncreaseArray, DeltaConstraint.INCREASE_MAX);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMinIncreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minIncreaseArray, DeltaConstraint.INCREASE_MIN);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processExactDecreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactDecreaseArray, DeltaConstraint.DECREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMaxDecreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxDecreaseArray, DeltaConstraint.DECREASE_MAX);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMinDecreaseERC20Balance(ERC20ArrayInvariant memory tokenERC20ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minDecreaseArray, DeltaConstraint.DECREASE_MIN);
        if (violationCount > 0) revert InvariantViolationERC20BalanceArray(tokenERC20ArrayInvariant, accountArrayInvariant, violations); 
    }

    // Remaining _process* functions intentionally follow the same pattern
    // and are omitted from NatSpec repetition for brevity and consistency.
}
