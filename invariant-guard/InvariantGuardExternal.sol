// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
import "./InvariantGuardHelper.sol";

/**
 * @title InvariantGuardExternal

 * @notice Provides invariant protection for state external to the current contract
 *
 * @dev This contract enables invariant checks on external ETH balances
 *      during the execution context of the inheriting contract.
 *
 *      Supported invariant category:
 *      - External ETH balances of specified accounts
 *
 *      External accounts are not allowed to violate configured invariants
 *      while execution is within the scope of the current contract.
 *
 *      External bytecode / code hash observation is intentionally NOT supported
 *      to remain compatible with the EOF roadmap.
 */
abstract contract InvariantGuardExternal {
    using InvariantGuardHelper for *;

    modifier invariantExtETHBalance(address[] memory accountArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processConstantExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray);
    }

    modifier assertExtETHBalanceEquals(address[] memory accountArray, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualBalanceArray = _getExtETHBalanceArray(accountArray);
        _processConstantExtETHBalance(AccountArrayInvariant(accountArray), expectedArray, actualBalanceArray);
    }

    modifier exactIncreaseExtETHBalance(address[] memory accountArray, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processExactIncreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactIncreaseArray);
    }

    modifier maxIncreaseExtETHBalance(address[] memory accountArray, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processMaxIncreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxIncreaseArray);
    }

    modifier minIncreaseExtETHBalance(address[] memory accountArray, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processMinIncreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minIncreaseArray);
    }

    modifier exactDecreaseExtETHBalance(address[] memory accountArray, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processExactDecreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactDecreaseArray);
    }

    modifier maxDecreaseExtETHBalance(address[] memory accountArray, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processMaxDecreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxDecreaseArray);
    }

    modifier minDecreaseExtETHBalance(address[] memory accountArray, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getExtETHBalanceArray(accountArray);
        _;
        uint256[] memory afterBalanceArray = _getExtETHBalanceArray(accountArray);
        _processMinDecreaseExtETHBalance(AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minDecreaseArray);
    }

    function _getExtETHBalance(address account) private view returns (uint256) {
        return account.balance;
    }

    function _getExtETHBalanceArray(address[] memory accountArray) private view returns (uint256[] memory) {
        uint256 length = accountArray._getAddressArrayLength();
        length._revertIfArrayTooLarge();
        uint256[] memory balanceArray = new uint256[](length);
        for (uint256 i = 0 ; i < length ; ) {
            balanceArray[i] = _getExtETHBalance(accountArray[i]);
            unchecked { ++i; }
        }
        return balanceArray;
    }

    function _processConstantExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, beforeBalanceArray._getUint256ArrayLength()._emptyArray(), DeltaConstraint.NO_CHANGE);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processExactIncreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactIncreaseArray, DeltaConstraint.INCREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processMaxIncreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxIncreaseArray, DeltaConstraint.INCREASE_MAX);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processMinIncreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minIncreaseArray, DeltaConstraint.INCREASE_MIN);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processExactDecreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactDecreaseArray, DeltaConstraint.DECREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processMaxDecreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxDecreaseArray, DeltaConstraint.DECREASE_MAX);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }

    function _processMinDecreaseExtETHBalance(AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minDecreaseArray, DeltaConstraint.DECREASE_MIN);
        if (violationCount > 0) revert InvariantViolationExtETHBalanceArray(accountArrayInvariant, violations); 
    }
}
