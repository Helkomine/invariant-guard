// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/**
 * @notice Rules describing how before/after deltas are validated
 */
enum DeltaConstraint {
    NO_CHANGE,         // before == after
    INCREASE_EXACT,    // after - before == delta
    INCREASE_MAX,      // after - before <= delta
    INCREASE_MIN,      // after - before >= delta
    DECREASE_EXACT,    // before - after == delta
    DECREASE_MAX,      // before - after <= delta
    DECREASE_MIN       // before - after >= delta  
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

/**
 * @notice Snapshot of an address value before and after execution
 * @dev Used to validate ownership or authority invariants
 */
struct AddressInvariant {
    address beforeOwner;
    address afterOwner;
}

/**
 * @notice Wrapper for an array of accounts subject to invariant checks
 */
struct AccountArrayInvariant {
    address[] accountArray;
}

/// @notice Mismatched array lengths during invariant validation
error LengthMismatch();

/// @notice Invariant category is not supported
error UnsupportedInvariant();  

/// @notice Invalid or unsupported DeltaConstraint
error InvalidDeltaConstraint(DeltaConstraint deltaConstraint);

/// @notice Too many slots requested for invariant protection
error ArrayTooLarge(uint256 length, uint256 maxLength);

/// @notice Code hash invariant violation
/// @custom:invariant code: contract bytecode hash must remain unchanged
error InvariantViolationCode(CodeInvariant codeInvariant);

/// @notice Nonce invariant violation
/// @custom:invariant nonce: nonce must satisfy the configured delta constraint
error InvariantViolationNonce(ValuePerPosition noncePerPosition);

/// @notice Balance invariant violation
/// @custom:invariant balance: contract ETH balance must satisfy the delta constraint
error InvariantViolationBalance(ValuePerPosition balancePerPosition);

/// @notice Storage invariant violation
/// @custom:invariant storage: specified storage slots must satisfy the delta constraint
error InvariantViolationStorage(ValuePerPosition[] storagePerPosition);

/// @notice Transient storage invariant violation
/// @custom:invariant tstorage: specified transient storage slots must satisfy the delta constraint
error InvariantViolationTransientStorage(ValuePerPosition[] transientStoragePerPosition);

/**
 * @title InvariantGuardHelper
 * @author Helkomine (@Helkomine)
 *
 * @notice Shared helper library for invariant validation logic
 * @dev Contains reusable validation utilities for InvariantGuard variants
 */
library InvariantGuardHelper {
    /// @notice Maximum number of positions that can be protected in a single invariant check
    uint256 internal constant MAX_PROTECTED_SLOTS  = 0xffff;

    /**
     * @notice Creates an empty uint256 array of given length
     */
    function _emptyArray(uint256 length) internal pure returns (uint256[] memory) {
        return new uint256[](length);
    }
    
    /**
     * @notice Returns the length of a bytes32 array
     */
    function _getBytes32ArrayLength(bytes32[] memory bytes32Array) internal pure returns (uint256) {
        return bytes32Array.length;
    } 

    /**
     * @notice Returns the length of a uint256 array
     */
    function _getUint256ArrayLength(uint256[] memory uint256Array) internal pure returns (uint256) {
        return uint256Array.length;
    }

    /**
     * @notice Returns the length of an address array
     */
    function _getAddressArrayLength(address[] memory addressArray) internal pure returns (uint256) {
        return addressArray.length;
    }

    /**
     * @notice Reverts if the number of protected positions exceeds the allowed maximum
     * @dev Prevents excessive gas usage and DoS vectors
     */
    function _revertIfArrayTooLarge(uint256 numPositions) internal pure {
        if (numPositions > MAX_PROTECTED_SLOTS) revert ArrayTooLarge(numPositions, MAX_PROTECTED_SLOTS);
    }  

    /**
     * @notice Checks whether a before/after value pair violates a delta constraint
     * @param beforeValue Value before execution
     * @param afterValue Value after execution
     * @param expectedDelta Expected delta constraint
     * @param deltaConstraint Delta constraint to apply
     * @return True if the invariant is violated, false otherwise
     */
    function _isDeltaViolation(uint256 beforeValue, uint256 afterValue, uint256 expectedDelta, DeltaConstraint deltaConstraint) internal pure returns (bool) {
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
     * @notice Validates array-based delta invariants
     * @dev Returns detailed per-position violations for invariant reporting
     * @param beforeValueArray Snapshot before execution
     * @param afterValueArray Snapshot after execution
     * @param expectedDeltaArray Expected deltas per position
     * @param deltaConstraint Delta constraint applied to all positions
     * @return violationCount Number of invariant violations
     * @return violations Detailed per-position invariant data
     */
    function _validateDeltaArray(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory expectedDeltaArray, DeltaConstraint deltaConstraint) internal pure returns (uint256, ValuePerPosition[] memory) {
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
    
    /**
     * @notice Validates that address values remain unchanged between snapshots
     * @dev Used for ownership or authority invariants
     * @param beforeOwnerArray Address snapshot before execution
     * @param afterOwnerArray Address snapshot after execution
     * @return violationCount Number of detected address changes
     * @return violations Detailed address changes per position
     */
    function _validateAddressArray(address[] memory beforeOwnerArray, address[] memory afterOwnerArray) internal pure returns (uint256, AddressInvariant[] memory) {
        uint256 length = _getAddressArrayLength(afterOwnerArray);
        _revertIfArrayTooLarge(length);
        bool valueMismatch;
        uint256 violationCount;
        AddressInvariant[] memory violations = new AddressInvariant[](length);
        for (uint256 i = 0 ; i < length ; ) {            
            valueMismatch = beforeOwnerArray[i] != afterOwnerArray[i];
            assembly {
                violationCount := add(violationCount, valueMismatch)
            }
            violations[i] = AddressInvariant(beforeOwnerArray[i], afterOwnerArray[i]);
            unchecked { ++i; }
        }
        return (violationCount, violations);
    }
}
