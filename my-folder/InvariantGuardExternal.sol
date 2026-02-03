// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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

struct AddressInvariant {
    address beforeOwner;
    address afterOwner;
}

struct AccountArrayInvariant {
    address[] accountArray;
}

struct ERC20ArrayInvariant {
    IERC20[] tokenERC20ArrayInvariant;
}

struct ERC721ArrayInvariant {
    IERC721[] tokenERC721ArrayInvariant;
}

struct ERC721TokenIdArray {
    uint256[] tokenIdERC721Array;
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

error InvariantViolationExtETHBalanceArray(AccountArrayInvariant accountArrayInvariant, ValuePerPosition[] extETHBalancePerPosition);

error InvariantViolationERC20BalanceArray(ERC20ArrayInvariant tokenERC20ArrayInvariant, AccountArrayInvariant accountArrayInvariant, ValuePerPosition[] ERC20BalancePerPosition);

error InvariantViolationERC721BalanceArray(ERC721ArrayInvariant tokenERC721ArrayInvariant, AccountArrayInvariant accountArrayInvariant, ValuePerPosition[] ERC721BalancePerPosition);

error InvariantViolationERC721OwnerArray(ERC721ArrayInvariant tokenERC721ArrayInvariant, ERC721TokenIdArray tokenIdERC721Array, AddressInvariant[] addressInvariantArray);

library InvariantGuardHelper {
    uint256 private constant MAX_PROTECTED_SLOTS  = 0xffff;

    function _emptyArray(uint256 length) internal pure returns (uint256[] memory) {
        return new uint256[](length);
    }
    
    function _getBytes32ArrayLength(bytes32[] memory bytes32Array) internal pure returns (uint256) {
        return bytes32Array.length;
    } 

    function _getUint256ArrayLength(uint256[] memory uint256Array) internal pure returns (uint256) {
        return uint256Array.length;
    }

    function _revertIfArrayTooLarge(uint256 numPositions) internal pure {
        if (numPositions > MAX_PROTECTED_SLOTS) revert ArrayTooLarge(numPositions, MAX_PROTECTED_SLOTS);
    }  

    /**
     * @notice Validates a before/after delta using a DeltaRule
     * @return True if the invariant holds, false otherwise
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
     * @notice Validates array-based invariants
     * @return violationCount Number of invariant violations
     * @return violations Detailed per-position violations
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

    function _getCodeHash() internal view returns (bytes32) {
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
     * @dev Uses raw `SLOAD` via assembly
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
// Cung cấp khả năng bảo vệ trạng thái 
// bên ngoài hợp đồng hiện tại
// Các hạng mục bảo vệ :
// Số dư ETH địa chỉ bên ngoài (không
// cho phép chúng vi phạm bất biến nếu
// nằm trong khung thực thi của hợp đồng
// hiện tại).
// Lưu ý rằng chúng tôi không hỗ trợ quan 
// sát mã bên ngoài nhằm tuân thủ lộ trình
// EOF.
abstract contract InvariantGuardExternal {
    using InvariantGuardHelper for uint256;
    using InvariantGuardHelper for uint256[];
    
    function _getAddressArrayLength(address[] memory accountArray) private pure returns (uint256) {
        return accountArray.length;
    }

    function _getExtETHBalance(address account) private view returns (uint256) {
        return account.balance;
    }

    function _getExtETHBalanceArray(address[] memory accountArray) private view returns (uint256[] memory) {
        uint256 length = _getAddressArrayLength(accountArray);
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
}


// Hợp đồng này bảo vệ bất biến trên các token ERC20
// Áp dụng giả định tin tưởng do thực hiện truy vấn bên
// ngoài, vì vậy có thể phát sinh các tình huống không xác
// định nếu hợp đồng token bất thường (metamorphic logic)).
// Các hạng mục bảo vệ : 
// Số dư trên một hoặc nhiều token ERC20 được chỉ định
abstract contract InvariantGuardERC20 {
    using InvariantGuardHelper for uint256;
    using InvariantGuardHelper for uint256[];

    function _getAddressArrayLength(address[] memory accountArray) private pure returns (uint256) {
        return accountArray.length;
    }

    function _getERC20Balance(IERC20 token, address account) private view returns (uint256) {
        return token.balanceOf(account);
    }

    function _getERC20BalanceArray(IERC20[] memory tokenArray, address[] memory accountArray) private view returns (uint256[] memory) {
        uint256 length = _getAddressArrayLength(accountArray);
        length._revertIfArrayTooLarge();
        uint256[] memory balanceArray = new uint256[](length);
        for (uint256 i = 0 ; i < length ; ) {
            balanceArray[i] = _getERC20Balance(tokenArray[i], accountArray[i]);
            unchecked { ++i; }
        }
        return balanceArray;
    }

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

    modifier invariantERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processConstantERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray);
    }

    modifier assertERC20BalanceEquals(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processConstantERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), actualBalanceArray, expectedArray);
    }

    modifier exactIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processExactIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactIncreaseArray);
    }

    modifier maxIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMaxIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxIncreaseArray);
    }

    modifier minIncreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMinIncreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minIncreaseArray);
    }

    modifier exactDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processExactDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactDecreaseArray);
    }

    modifier maxDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMaxDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxDecreaseArray);
    }

    modifier minDecreaseERC20Balance(IERC20[] memory tokenArray, address[] memory accountArray, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC20BalanceArray(tokenArray, accountArray);
        _processMinDecreaseERC20Balance(ERC20ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minDecreaseArray);
    }
}

// Hợp đồng này bảo vệ bất biến trên các token ERC721
// Áp dụng giả định tin tưởng do thực hiện truy vấn bên
// ngoài, vì vậy có thể phát sinh các tình huống không xác
// định nếu hợp đồng token bất thường (metamorphic logic)).
// Số dư token ERC721 trên chính nó và các hợp đồng nằm trong
// khung thực thi của nó (áp dụng giả định
// tin tưởng vào hợp đồng token
// Các hạng mục bảo vệ : 
// Số dư trên một hoặc nhiều token ERC721 được chỉ định
// Chủ sở hữu trên một hoặc nhiều token ERC721 được chỉ định
abstract contract InvariantGuardERC721 {
    using InvariantGuardHelper for uint256;
    using InvariantGuardHelper for uint256[];

    function _getAddressArrayLength(address[] memory accountArray) private pure returns (uint256) {
        return accountArray.length;
    }

    // BALANCE OF
    function _getERC721Balance(IERC721 token, address account) private view returns (uint256) {
        return token.balanceOf(account);
    }

    function _getERC721BalanceArray(IERC721[] memory tokenArray, address[] memory accountArray) private view returns (uint256[] memory) {
        uint256 length = _getAddressArrayLength(accountArray);
        length._revertIfArrayTooLarge();
        uint256[] memory balanceArray = new uint256[](length);
        for (uint256 i = 0 ; i < length ; ) {
            balanceArray[i] = _getERC721Balance(tokenArray[i], accountArray[i]);
            unchecked { ++i; }
        }
        return balanceArray;
    }

    function _processConstantERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, beforeBalanceArray._getUint256ArrayLength()._emptyArray(), DeltaConstraint.NO_CHANGE);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processExactIncreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactIncreaseArray, DeltaConstraint.INCREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMaxIncreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxIncreaseArray, DeltaConstraint.INCREASE_MAX);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMinIncreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minIncreaseArray, DeltaConstraint.INCREASE_MIN);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processExactDecreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, exactDecreaseArray, DeltaConstraint.DECREASE_EXACT);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMaxDecreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, maxDecreaseArray, DeltaConstraint.DECREASE_MAX);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    function _processMinDecreaseERC721Balance(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, AccountArrayInvariant memory accountArrayInvariant, uint256[] memory beforeBalanceArray, uint256[] memory afterBalanceArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) = beforeBalanceArray._validateDeltaArray(afterBalanceArray, minDecreaseArray, DeltaConstraint.DECREASE_MIN);
        if (violationCount > 0) revert InvariantViolationERC721BalanceArray(tokenERC721ArrayInvariant, accountArrayInvariant, violations); 
    }

    modifier invariantERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processConstantERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray);
    }

    modifier assertERC721BalanceEquals(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processConstantERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), expectedArray, actualBalanceArray);
    }

    modifier exactIncreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processExactIncreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactIncreaseArray);
    }

    modifier maxIncreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMaxIncreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxIncreaseArray);
    }

    modifier minIncreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMinIncreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minIncreaseArray);
    }

    modifier exactDecreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processExactDecreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, exactDecreaseArray);
    }

    modifier maxDecreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMaxDecreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, maxDecreaseArray);
    }

    modifier minDecreaseERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMinDecreaseERC721Balance(ERC721ArrayInvariant(tokenArray), AccountArrayInvariant(accountArray), beforeBalanceArray, afterBalanceArray, minDecreaseArray);
    }

    // OWNER OF
    function _getERC721Owner(IERC721 token, uint256 tokenId) private view returns (address) {
        return token.ownerOf(tokenId);
    }

    function _getERC721OwnerArray(IERC721[] memory tokenArray, uint256[] memory tokenIdArray) private view returns (address[] memory) {
        uint256 length = tokenArray.length;
        length._revertIfArrayTooLarge();
        address[] memory ownerArray = new address[](length);
        for (uint256 i = 0 ; i < length ; ) {
            ownerArray[i] = _getERC721Owner(tokenArray[i], tokenIdArray[i]);
        }
        return ownerArray;
    }

    // bất biến chủ sở hữu trước và sau khi thực thi
    modifier invariantERC721Owner(IERC721[] memory tokenArray, uint256[] memory tokenIdArray) {
        address[] memory beforeOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _;
        address[] memory afterOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _processConstantERC721Owner(ERC721ArrayInvariant(tokenArray), ERC721TokenIdArray(tokenIdArray), beforeOwnerArray, afterOwnerArray);
    }

    // bất biến chủ sở hữu kì vọng và thực tế sau khi thực thi
    modifier assertERC721OwnerEquals(IERC721[] memory tokenArray, uint256[] memory tokenIdArray, address[] memory expectedArray) {
        _;
        address[] memory actualOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _processConstantERC721Owner(ERC721ArrayInvariant(tokenArray), ERC721TokenIdArray(tokenIdArray), expectedArray, actualOwnerArray);
    }

    function _processConstantERC721Owner(ERC721ArrayInvariant memory tokenERC721ArrayInvariant, ERC721TokenIdArray memory tokenIdERC721Array, address[] memory beforeOwnerArray, address[] memory afterOwnerArray) private pure {
        (uint256 violationCount, AddressInvariant[] memory violations) = _validateAddressArray(beforeOwnerArray, afterOwnerArray);
        if (violationCount > 0) revert InvariantViolationERC721OwnerArray(tokenERC721ArrayInvariant, tokenIdERC721Array, violations); 
    }

    function _validateAddressArray(address[] memory beforeOwnerArray, address[] memory afterOwnerArray) private pure returns (uint256, AddressInvariant[] memory) {
        uint256 length = _getAddressArrayLength(afterOwnerArray);
        length._revertIfArrayTooLarge();
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
