// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
abstract contract SafeStateInternal {
    uint256 constant MAX_PROTECTED_SLOTS  = 0xffff;
    enum ValidateSelector {
        IS_CONSTANT_VALUE_AND_DELTA_EQUAL,
        IS_INCREASE_VALUE_AND_DELTA_EQUAL, 
        IS_DECREASE_VALUE_AND_DELTA_EQUAL,
        IS_INCREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL, 
        IS_INCREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL, 
        IS_DECREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL,
        IS_DECREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL 
    }
    struct ValuePerPosition {
        uint256 beforeValue;
        uint256 afterValue;
        uint256 delta;
    }  
    error LengthMismatch();
    error UnsupportedInvariant();  
    error WrongErrorConfiguration(ValidateSelector errorOption);
    error ArrayTooLarge(uint256 length, uint256 maxLength);
    error InvariantViolationCode(bytes32 beforeCodeHash, bytes32 afterCodeHash);
    error InvariantViolationNonce(ValuePerPosition noncePerPosition);
    error InvariantViolationBalance(ValuePerPosition balancePerPosition);
    error InvariantViolationStorage(ValuePerPosition[] storagePerPosition);
    error InvariantViolationTransientStorage(ValuePerPosition[] transientStoragePerPosition);

    function _revertIfTransientStorageMismatch() private {}

    // --------------------------- CODE -----------------------------------
    function _getCodeHash() private view returns (bytes32) {
        bytes32 codeHash;
        assembly {
            codeHash := extcodehash(address())
        }
        return codeHash;
    }

    function _processInvariantCode(bytes32 beforeCodeHash, bytes32 afterCodeHash) private pure {
        if (beforeCodeHash != afterCodeHash) revert InvariantViolationCode(beforeCodeHash, afterCodeHash);
    } 

    modifier invariantCode() {
        bytes32 beforeCodeHash = _getCodeHash();
        _;
        bytes32 afterCodeHash = _getCodeHash();
        _processInvariantCode(beforeCodeHash, afterCodeHash);
    }

    // -------------------------------- NONCE ------------------------------------  
    modifier invariantNonce() {
        revert UnsupportedInvariant();
        _;
    }

    modifier expectedInvariantNonce(uint256 expectedInvariant) {
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

    // -------------------------- BALANCE ---------------------------------
    function _getBalance() private view returns (uint256) {
        return address(this).balance;
    }

    function _processInvariance(uint256 beforeValue, uint256 afterValue, uint256 expectedDelta, ValidateSelector selector) private pure returns (bool) {
        if (selector == ValidateSelector.IS_CONSTANT_VALUE_AND_DELTA_EQUAL) {
            return beforeValue == afterValue;
        } else if (selector == ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_EQUAL) {
            uint256 delta = afterValue - beforeValue;
            return delta == expectedDelta;
        } else if (selector == ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_EQUAL) {
            uint256 delta = beforeValue - afterValue;
            return delta == expectedDelta;
        } else if (selector == ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL) {
            uint256 delta = afterValue - beforeValue;
            return delta <= expectedDelta;
        } else if (selector == ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL) {
            uint256 delta = afterValue - beforeValue;
            return delta >= expectedDelta;
        } else if (selector == ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL) {
            uint256 delta = beforeValue - afterValue;
            return delta <= expectedDelta;
        } else if (selector == ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL) {
            uint256 delta = beforeValue - afterValue;
            return delta >= expectedDelta;     
        } else {
            revert WrongErrorConfiguration(selector);
        }
    }

    function _processExpectedInvariantBalance(uint256 beforeBalance, uint256 afterBalance) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, 0, ValidateSelector.IS_CONSTANT_VALUE_AND_DELTA_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, 0));
    }

    function _processExactIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactIncrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, exactIncrease, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactIncrease));   
    }

    function _processExactDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactDecrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, exactDecrease, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactDecrease));   
    }

    function _processMaxIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxIncrease) private pure {       
        if (!_processInvariance(beforeBalance, afterBalance, maxIncrease, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxIncrease));   
    }

    function _processMinIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minIncrease) private pure {     
        if (!_processInvariance(beforeBalance, afterBalance, minIncrease, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minIncrease));      
    }

    function _processMaxDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxDecrease) private pure {             
        if (!_processInvariance(beforeBalance, afterBalance, maxDecrease, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxDecrease));
    }

    function _processMinDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minIncrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, minIncrease, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minIncrease));
    }

    modifier invariantBalance() {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processExpectedInvariantBalance(beforeBalance, afterBalance);
    }

    modifier expectedInvariantBalance(uint256 expectedInvariant) {
        _;
        uint256 actualBalance = _getBalance();
        _processExpectedInvariantBalance(expectedInvariant, actualBalance);
    }

    modifier exactIncreaseBalance(uint256 exactIncrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processExactIncreaseBalance(beforeBalance, afterBalance, exactIncrease);      
    }

    modifier exactDecreaseBalance(uint256 exactDecrease) {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _processExactDecreaseBalance(beforeBalance, afterBalance, exactDecrease);  
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

    // ------------------------------ STORAGE -------------------------------

    function _getNumStoragePositions(bytes32[] storage positions) private view returns (uint256) {
        return positions.length;
    }
    
    function _revertIfArrayTooLarge(uint256 numPositions) private pure {
        if (numPositions > MAX_PROTECTED_SLOTS) revert ArrayTooLarge(numPositions, MAX_PROTECTED_SLOTS);
    }  

    function _getStorageArray(bytes32[] storage positions) private view returns (uint256[] memory) {
        uint256 numPositions = _getNumStoragePositions(positions);
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
    
    function _processArray(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory expectedDeltaArray, ValidateSelector selector) private pure returns (uint256, ValuePerPosition[] memory) {
        uint256 length = expectedDeltaArray.length;
        _revertIfArrayTooLarge(length);
        if (beforeValueArray.length != length || afterValueArray.length != length) revert LengthMismatch();
        bool valueMismatch;       
        uint256 errorAccumulator;
        ValuePerPosition[] memory errorArray = new ValuePerPosition[](length);
        for (uint256 i = 0 ; i < length ; ) {            
            valueMismatch = _processInvariance(beforeValueArray[i], afterValueArray[i], expectedDeltaArray[i], selector);
            assembly {
                errorAccumulator := add(errorAccumulator, valueMismatch)
            }
            errorArray[i] = ValuePerPosition(beforeValueArray[i], afterValueArray[i], expectedDeltaArray[i]);
            unchecked { ++i; }
        }
        return (errorAccumulator, errorArray);
    }        
   
    function _processExpectedInvariantStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, new uint256[](beforeValueArray.length), ValidateSelector.IS_CONSTANT_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray); 
    }

    function _processExactIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processExactDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMaxIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMinIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMaxDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMinDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }
   
    modifier invariantStorage(bytes32[] storage positions) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExpectedInvariantStorage(beforeValueArray, afterValueArray);
    }

    modifier expectedInvariantStorage(bytes32[] storage positions, uint256[] memory expectedInvariantArray) {
        _;
        uint256[] memory actualStorageArray = _getStorageArray(positions);
        _processExpectedInvariantStorage(expectedInvariantArray, actualStorageArray);
    }
    
    modifier exactIncreaseStorage(bytes32[] storage positions, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactIncreaseStorage(beforeValueArray, afterValueArray, exactIncreaseArray);
    }

    modifier exactDecreaseStorage(bytes32[] storage positions, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactDecreaseStorage(beforeValueArray, afterValueArray, exactDecreaseArray);
    }
    
    modifier maxIncreaseStorage(bytes32[] storage positions, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxIncreaseStorage(beforeValueArray, afterValueArray, maxIncreaseArray);
    }
    
    modifier minIncreaseStorage(bytes32[] storage positions, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinIncreaseStorage(beforeValueArray, afterValueArray, minIncreaseArray);
    }
    
    modifier maxDecreaseStorage(bytes32[] storage positions, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxDecreaseStorage(beforeValueArray, afterValueArray, maxDecreaseArray);
    }
    
    modifier minDecreaseStorage(bytes32[] storage positions, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinDecreaseStorage(beforeValueArray, afterValueArray, minDecreaseArray);
    }  

// ------------------- TRANSIENT STORAGE ------------------------------                    
    function _getNumTransientStoragePositions(bytes32[] memory positions) private view returns (uint256) {
        return positions.length;
    }
    
    function _revertIfArrayTooLarge(uint256 numPositions) private pure {
        if (numPositions > MAX_PROTECTED_SLOTS) revert ArrayTooLarge(numPositions, MAX_PROTECTED_SLOTS);
    }  

    function _getTransientStorageArray(bytes32[] memory positions) private view returns (uint256[] memory) {
        uint256 numPositions = _getNumTransientStoragePositions(positions);
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
               
    function _processExpectedInvariantTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, new uint256[](beforeValueArray.length), ValidateSelector.IS_CONSTANT_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray); 
    }

    function _processExactIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processExactDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMaxIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMinIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minIncreaseArray, ValidateSelector.IS_INCREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMaxDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_LESS_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMinDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minDecreaseArray, ValidateSelector.IS_DECREASE_VALUE_AND_DELTA_GREATER_THAN_OR_EQUAL);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    modifier invariantTransientStorage(bytes32[] storage positions) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExpectedInvariantTransientStorage(beforeValueArray, afterValueArray);
    }

    modifier expectedInvariantTransientStorage(bytes32[] storage positions, uint256[] memory expectedInvariantArray) {
        _;
        uint256[] memory actualStorageArray = _getStorageArray(positions);
        _processExpectedInvariantTransientStorage(expectedInvariantArray, actualStorageArray);
    }
    
    modifier exactIncreaseTransientStorage(bytes32[] storage positions, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactIncreaseTransientStorage(beforeValueArray, afterValueArray, exactIncreaseArray);
    }

    modifier exactDecreaseTransientStorage(bytes32[] storage positions, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processExactDecreaseTransientStorage(beforeValueArray, afterValueArray, exactDecreaseArray);
    }
    
    modifier maxIncreaseTransientStorage(bytes32[] storage positions, uint256[] memory maxIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxIncreaseTransientStorage(beforeValueArray, afterValueArray, maxIncreaseArray);
    }
    
    modifier minIncreaseTransientStorage(bytes32[] storage positions, uint256[] memory minIncreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinIncreaseTransientStorage(beforeValueArray, afterValueArray, minIncreaseArray);
    }
    
    modifier maxDecreaseTransientStorage(bytes32[] storage positions, uint256[] memory maxDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMaxDecreaseTransientStorage(beforeValueArray, afterValueArray, maxDecreaseArray);
    }
    
    modifier minDecreaseTransientStorage(bytes32[] storage positions, uint256[] memory minDecreaseArray) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _processMinDecreaseTransientStorage(beforeValueArray, afterValueArray, minDecreaseArray);
    }  
}
