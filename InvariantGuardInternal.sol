// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
/**
 * @title InvariantGuardInternal
 * @author Helkomine (@Helkomine)
 *
 * @notice
 * Abstract contract providing a set of modifiers to enforce state invariants
 * based on explicitly specified positions.
 *
 * @dev
 * Supported invariant categories:
 * - Code hash (contract bytecode immutability)
 * - Balance (ETH balance of the contract)
 * - Storage (explicit storage slots)
 * - Transient Storage (EIP-1153)
 *
 * Not supported:
 * - Nonce (currently reverts with UnsupportedInvariant)
 *
 * ⚠️ Important notes:
 * - Storage and Transient Storage invariants CANNOT protect mappings or
 *   dynamic arrays unless their exact storage slots are explicitly provided.
 * - For arrays or complex structures, callers must manually derive and pass
 *   the list of storage slot positions (bytes32[]).
 * - Callers must pass pointers (slot lists), NOT high-level Solidity types.
 *
 * This contract is designed as an "Invariant DSL" (domain-specific language):
 * - Modifiers act as the public invariant interface.
 * - All validation logic is implemented in private utility functions.
 */
abstract contract InvariantGuardInternal {
    /**
     * @notice Maximum number of slots that can be protected in a single invariant check
     * @dev Prevents out-of-gas and griefing attacks
     */
    uint256 private constant MAX_PROTECTED_SLOTS  = 0xffff;

    /**
     * @notice Rules describing how before/after deltas are validated
     */
    enum DeltaConstraint {
        NO_CHANGE,         // before == after
        INCREASE_EXACT,   // after - before == delta
        INCREASE_MAX,     // after - before <= delta
        INCREASE_MIN,     // after - before >= delta
        DECREASE_EXACT,   // before - after == delta
        DECREASE_MAX,     // before - after <= delta
        DECREASE_MIN      // before - after >= delta  
    }


    /**
     * @notice Snapshot of contract bytecode hash before and after execution
     */
    struct CodeInvariant {
        bytes32 beforeCodeHash;
        bytes32 afterCodeHash;
    }

    /**
     * @notice Snapshot of a value before and after execution
     */
    struct ValuePerPosition {
        uint256 beforeValue;
        uint256 afterValue;
        uint256 delta;
    }  

    /// @notice Mismatched array lengths during invariant validation
    error LengthMismatch();

    /// @notice Invariant category is not supported
    error UnsupportedInvariant();  

    /// @notice Invalid or unsupported DeltaRule
    error InvalidDeltaConstraint(DeltaConstraint deltaConstraint);

    /// @notice Too many slots requested for invariant protection
    error ArrayTooLarge(uint256 length, uint256 maxLength);

    /// @notice Code hash invariant violation
    error InvariantViolationCode(CodeInvariant codeInvariant);

    /// @notice Nonce invariant violation
    error InvariantViolationNonce(ValuePerPosition noncePerPosition);

    /// @notice Balance invariant violation
    error InvariantViolationBalance(ValuePerPosition balancePerPosition);

    /// @notice Storage invariant violation
    error InvariantViolationStorage(ValuePerPosition[] storagePerPosition);

    /// @notice Transient storage invariant violation
    error InvariantViolationTransientStorage(ValuePerPosition[] transientStoragePerPosition);

    /**
     * @notice Ensures that the contract bytecode does not change
     * @dev Compares extcodehash before and after execution
     */
    modifier invariantCode() {
        bytes32 beforeCodeHash = _getCodeHash();
        _;
        bytes32 afterCodeHash = _getCodeHash();
        _processInvariantCode(beforeCodeHash, afterCodeHash);
    }

    /**
     * @notice Placeholder for nonce invariants
     * @dev Currently unsupported and always reverts
     */  
    modifier invariantNonce() {
        revert UnsupportedInvariant();
        _;
    }

    modifier assertNonceEquals(uint256 expected) {
        revert UnsupportedInvariant();
        _;
    }

    modifier exactIncreaseNonce(uint256 exactIncrease) {
        revert UnsupportedInvariant();
        _;
    }

    modifier maxIncreaseNonce(uint256 maxIncrease) {
        revert UnsupportedInvariant();
        _;
    }

    modifier minIncreaseNonce(uint256 minIncrease) {
        revert UnsupportedInvariant();
        _; 
    }

    /**
     * @notice Ensures the contract ETH balance remains unchanged
     */
    modifier invariantBalance() {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processConstantBalance(beforeBalance, afterBalance);
    }

    /**
     * @notice Asserts the contract balance equals an expected value after execution
     */
    modifier assertBalanceEquals(uint256 expected) {
        _;
        uint256 actualBalance = _getBalance();
        _processConstantBalance(expected, actualBalance);
    }

    /**
     * @notice Ensures the contract balance increases by an exact amount
     */
    modifier exactIncreaseBalance(uint256 exactIncrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processExactIncreaseBalance(beforeBalance, afterBalance, exactIncrease);      
    }

    modifier maxIncreaseBalance(uint256 maxIncrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processMaxIncreaseBalance(beforeBalance, afterBalance, maxIncrease);
    }

    modifier minIncreaseBalance(uint256 minIncrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processMinIncreaseBalance(beforeBalance, afterBalance, minIncrease);       
    }
   
    /**
     * @notice Ensures the contract balance decreases by an exact amount
     */
    modifier exactDecreaseBalance(uint256 exactDecrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processExactDecreaseBalance(beforeBalance, afterBalance, exactDecrease);  
    }

    modifier maxDecreaseBalance(uint256 maxDecrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();             
        _processMaxDecreaseBalance(beforeBalance, afterBalance, maxDecrease);
    }

    modifier minDecreaseBalance(uint256 minDecrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processMinDecreaseBalance(beforeBalance, afterBalance, minDecrease);
    }

    /**
     * @notice Ensures specified storage slots remain unchanged
     * @param positions List of storage slot positions to protect
     */
    modifier invariantStorage(bytes32[] memory positions) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processConstantStorage(beforeValueArray, afterValueArray);
    }

    /**
     * @notice Asserts storage values equal expected values after execution
     */
    modifier assertStorageEquals(bytes32[] memory positions, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualStorageArray = _getStorageArray(positions);
        _processConstantStorage(expectedArray, actualStorageArray);
    }
    
    modifier exactIncreaseStorage(bytes32[] memory positions, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactIncreaseStorage(beforeValueArray, afterValueArray, exactIncreaseArray);
    }
    
    modifier maxIncreaseStorage(bytes32[] memory positions, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxIncreaseStorage(beforeValueArray, afterValueArray, maxIncreaseArray);
    }
    
    modifier minIncreaseStorage(bytes32[] memory positions, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinIncreaseStorage(beforeValueArray, afterValueArray, minIncreaseArray);
    }

    modifier exactDecreaseStorage(bytes32[] memory positions, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactDecreaseStorage(beforeValueArray, afterValueArray, exactDecreaseArray);
    }

    modifier maxDecreaseStorage(bytes32[] memory positions, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxDecreaseStorage(beforeValueArray, afterValueArray, maxDecreaseArray);
    }
    
    modifier minDecreaseStorage(bytes32[] memory positions, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinDecreaseStorage(beforeValueArray, afterValueArray, minDecreaseArray);
    }  

    /**
     * @notice Ensures specified transient storage slots remain unchanged
     * @dev Uses `TLOAD` (EIP-1153)
     */
    modifier invariantTransientStorage(bytes32[] memory positions) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processConstantTransientStorage(beforeValueArray, afterValueArray);
    }

    modifier assertTransientStorageEquals(bytes32[] memory positions, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualStorageArray = _getTransientStorageArray(positions);
        _processConstantTransientStorage(expectedArray, actualStorageArray);
    }
    
    modifier exactIncreaseTransientStorage(bytes32[] memory positions, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processExactIncreaseTransientStorage(beforeValueArray, afterValueArray, exactIncreaseArray);
    }
    
    modifier maxIncreaseTransientStorage(bytes32[] memory positions, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processMaxIncreaseTransientStorage(beforeValueArray, afterValueArray, maxIncreaseArray);
    }
    
    modifier minIncreaseTransientStorage(bytes32[] memory positions, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processMinIncreaseTransientStorage(beforeValueArray, afterValueArray, minIncreaseArray);
    }

    modifier exactDecreaseTransientStorage(bytes32[] memory positions, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processExactDecreaseTransientStorage(beforeValueArray, afterValueArray, exactDecreaseArray);
    }

    modifier maxDecreaseTransientStorage(bytes32[] memory positions, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processMaxDecreaseTransientStorage(beforeValueArray, afterValueArray, maxDecreaseArray);
    }
    
    modifier minDecreaseTransientStorage(bytes32[] memory positions, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processMinDecreaseTransientStorage(beforeValueArray, afterValueArray, minDecreaseArray);
    }  

    
    function _emptyArray(uint256 length) private pure returns (uint256[] memory) {
        return new uint256[](length);
    }
    
    function _getBytes32ArrayLength(bytes32[] memory bytes32Array) private pure returns (uint256) {
        return bytes32Array.length;
    } 

    function _getUint256ArrayLength(uint256[] memory uint256Array) private pure returns (uint256) {
        return uint256Array.length;
    }

    function _revertIfArrayTooLarge(uint256 numPositions) private pure {
        if (numPositions > MAX_PROTECTED_SLOTS) revert ArrayTooLarge(numPositions, MAX_PROTECTED_SLOTS);
    }  

    /**
     * @notice Validates a before/after delta using a DeltaRule
     * @return True if the invariant holds, false otherwise
     */
    function _isDeltaViolation(uint256 beforeValue, uint256 afterValue, uint256 expectedDelta, DeltaConstraint deltaConstraint) private pure returns (bool) {
        if (deltaConstraint == DeltaConstraint.NO_CHANGE) {
            return beforeValue != afterValue;
        } else if (deltaConstraint == DeltaConstraint.INCREASE_EXACT) {
            if (afterValue < beforeValue) return true;
            unchecked {
                return afterValue - beforeValue != expectedDelta;
            }
        } else if (deltaConstraint == DeltaConstraint.INCREASE_MAX) {
            if (afterValue < beforeValue) return true;
            unchecked {
                return afterValue - beforeValue > expectedDelta;
            }
        } else if (deltaConstraint == DeltaConstraint.INCREASE_MIN) {
            if (afterValue < beforeValue) return true;
            unchecked {
                return afterValue - beforeValue < expectedDelta;
            }
        } else if (deltaConstraint == DeltaConstraint.DECREASE_EXACT) {
            if (beforeValue < afterValue) return true;
            unchecked {
                return beforeValue - afterValue != expectedDelta;
            }
        } else if (deltaConstraint == DeltaConstraint.DECREASE_MAX) {
            if (beforeValue < afterValue) return true;
            unchecked {
                return beforeValue - afterValue > expectedDelta;
            }
        } else if (deltaConstraint == DeltaConstraint.DECREASE_MIN) {
            if (beforeValue < afterValue) return true;
            unchecked {
                return beforeValue - afterValue < expectedDelta;
            }     
        } else {
            revert InvalidDeltaConstraint(deltaConstraint);
        }
    }

    /**
     * @notice Validates array-based invariants
     * @return violationCount Number of invariant violations
     * @return violations Detailed per-position violations
     */
    function _validateDeltaArray(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory expectedDeltaArray, DeltaConstraint deltaConstraint) private pure returns (uint256, ValuePerPosition[] memory) {
        uint256 length = _getUint256ArrayLength(expectedDeltaArray);
        _revertIfArrayTooLarge(length);
        if (_getUint256ArrayLength(beforeValueArray) != length || _getUint256ArrayLength(afterValueArray) != length) revert LengthMismatch();
        bool valueMismatch;       
        uint256 violationCount;
        ValuePerPosition[] memory violations = new ValuePerPosition[](length);
        for (uint256 i = 0 ; i < length ; ) {            
            valueMismatch = _isDeltaViolation(beforeValueArray[i], afterValueArray[i], expectedDeltaArray[i], deltaConstraint);
            assembly {
                violationCount := add(violationCount, valueMismatch)
            }
            violations[i] = ValuePerPosition(beforeValueArray[i], afterValueArray[i], expectedDeltaArray[i]);
            unchecked { ++i; }
        }
        return (violationCount, violations);
    } 

    function _getCodeHash() private view returns (bytes32) {
        bytes32 codeHash;
        assembly {
            codeHash := extcodehash(address())
        }
        return codeHash;
    }

    function _processInvariantCode(bytes32 beforeCodeHash, bytes32 afterCodeHash) private pure {
        if (beforeCodeHash != afterCodeHash) revert InvariantViolationCode(CodeInvariant(beforeCodeHash, afterCodeHash));
    } 

    function _getBalance() private view returns (uint256) {
        return address(this).balance;
    }

    function _processConstantBalance(uint256 beforeBalance, uint256 afterBalance) private pure {
        if (_isDeltaViolation(beforeBalance, afterBalance, 0, DeltaConstraint.NO_CHANGE)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, 0));
    }

    function _processExactIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactIncrease) private pure {
        if (_isDeltaViolation(beforeBalance, afterBalance, exactIncrease, DeltaConstraint.INCREASE_EXACT)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactIncrease));   
    }

    function _processMaxIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxIncrease) private pure {       
        if (_isDeltaViolation(beforeBalance, afterBalance, maxIncrease, DeltaConstraint.INCREASE_MAX)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxIncrease));   
    }

    function _processMinIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minIncrease) private pure {     
        if (_isDeltaViolation(beforeBalance, afterBalance, minIncrease, DeltaConstraint.INCREASE_MIN)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minIncrease));      
    }

    function _processExactDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactDecrease) private pure {
        if (_isDeltaViolation(beforeBalance, afterBalance, exactDecrease, DeltaConstraint.DECREASE_EXACT)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactDecrease));   
    }

    function _processMaxDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxDecrease) private pure {             
        if (_isDeltaViolation(beforeBalance, afterBalance, maxDecrease, DeltaConstraint.DECREASE_MAX)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxDecrease));
    }

    function _processMinDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minDecrease) private pure {
        if (_isDeltaViolation(beforeBalance, afterBalance, minDecrease, DeltaConstraint.DECREASE_MIN)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minDecrease));
    }

    /**
     * @notice Loads values from explicit storage slots
     * @dev Uses raw sload via assembly
     */
    function _getStorageArray(bytes32[] memory positions) private view returns (uint256[] memory) {
        uint256 numPositions = _getBytes32ArrayLength(positions);
        _revertIfArrayTooLarge(numPositions);
        uint256[] memory valueArray = new uint256[](numPositions);
        for (uint256 i = 0; i < numPositions; ) {
            bytes32 slot = positions[i];
            uint256 slotValue;
            assembly {
                slotValue := sload(slot)
            }
            valueArray[i] = slotValue;
            unchecked { ++i; }
        }
        return valueArray;
    }          
   
    function _processConstantStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, _emptyArray(_getUint256ArrayLength(beforeValueArray)), DeltaConstraint.NO_CHANGE);
        if (violationCount > 0) revert InvariantViolationStorage(violations); 
    }

    function _processExactIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, exactIncreaseArray, DeltaConstraint.INCREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    function _processMaxIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, maxIncreaseArray, DeltaConstraint.INCREASE_MAX);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    function _processMinIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, minIncreaseArray, DeltaConstraint.INCREASE_MIN);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    function _processExactDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, exactDecreaseArray, DeltaConstraint.DECREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    function _processMaxDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, maxDecreaseArray, DeltaConstraint.DECREASE_MAX);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    function _processMinDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, minDecreaseArray, DeltaConstraint.DECREASE_MIN);
        if (violationCount > 0) revert InvariantViolationStorage(violations);
    }

    /**
     * @notice Loads values from transient storage slots
     * @dev Uses `TLOAD` (EIP-1153)
     */
    function _getTransientStorageArray(bytes32[] memory positions) private view returns (uint256[] memory) {
        uint256 numPositions = _getBytes32ArrayLength(positions);
        _revertIfArrayTooLarge(numPositions);
        uint256[] memory valueArray = new uint256[](numPositions);
        for (uint256 i = 0; i < numPositions; ) {
            bytes32 slot = positions[i];
            uint256 slotValue;
            assembly {
                slotValue := tload(slot)
            }
            valueArray[i] = slotValue;
            unchecked { ++i; }
        }
        return valueArray;
    }    
               
    function _processConstantTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, _emptyArray(_getUint256ArrayLength(beforeValueArray)), DeltaConstraint.NO_CHANGE);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations); 
    }

    function _processExactIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, exactIncreaseArray, DeltaConstraint.INCREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }

    function _processMaxIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, maxIncreaseArray, DeltaConstraint.INCREASE_MAX);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }

    function _processMinIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, minIncreaseArray, DeltaConstraint.INCREASE_MIN);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }

    function _processExactDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, exactDecreaseArray, DeltaConstraint.DECREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }

    function _processMaxDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, maxDecreaseArray, DeltaConstraint.DECREASE_MAX);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }

    function _processMinDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = _validateDeltaArray(beforeValueArray, afterValueArray, minDecreaseArray, DeltaConstraint.DECREASE_MIN);
        if (violationCount > 0) revert InvariantViolationTransientStorage(violations);
    }
}
