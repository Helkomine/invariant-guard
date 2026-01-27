// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
abstract contract InvariantGuardInternal {
    uint256 constant MAX_PROTECTED_SLOTS  = 0xffff;
    enum DeltaRule {
        CONSTANT,
        INCREASE_EXACT, 
        DECREASE_EXACT,
        INCREASE_MAX, 
        INCREASE_MIN, 
        DECREASE_MAX,
        DECREASE_MIN 
    }
    struct CodeInvariant {
        bytes32 beforeHash;
        bytes32 afterHash;
    }
    struct ValuePerPosition {
        uint256 beforeValue;
        uint256 afterValue;
        uint256 delta;
    }  
    error LengthMismatch();
    error UnsupportedInvariant();  
    error WrongErrorConfiguration(DeltaRule errorOption);
    error ArrayTooLarge(uint256 length, uint256 maxLength);
    error InvariantViolationCode(CodeInvariant code);
    error InvariantViolationNonce(ValuePerPosition noncePerPosition);
    error InvariantViolationBalance(ValuePerPosition balancePerPosition);
    error InvariantViolationStorage(ValuePerPosition[] storagePerPosition);
    error InvariantViolationTransientStorage(ValuePerPosition[] transientStoragePerPosition);

    // --------------------------- CODE -----------------------------------
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

    // -------------------------- BALANCE ---------------------------------
    function _getBalance() private view returns (uint256) {
        return address(this).balance;
    }

    function _processInvariance(uint256 beforeValue, uint256 afterValue, uint256 expectedDelta, DeltaRule selector) private pure returns (bool) {
        if (selector == DeltaRule.CONSTANT) {
            return beforeValue == afterValue;
        } else if (selector == DeltaRule.INCREASE_EXACT) {
            uint256 delta = afterValue - beforeValue;
            return delta == expectedDelta;
        } else if (selector == DeltaRule.DECREASE_EXACT) {
            uint256 delta = beforeValue - afterValue;
            return delta == expectedDelta;
        } else if (selector == DeltaRule.INCREASE_MAX) {
            uint256 delta = afterValue - beforeValue;
            return delta <= expectedDelta;
        } else if (selector == DeltaRule.INCREASE_MIN) {
            uint256 delta = afterValue - beforeValue;
            return delta >= expectedDelta;
        } else if (selector == DeltaRule.DECREASE_MAX) {
            uint256 delta = beforeValue - afterValue;
            return delta <= expectedDelta;
        } else if (selector == DeltaRule.DECREASE_MIN) {
            uint256 delta = beforeValue - afterValue;
            return delta >= expectedDelta;     
        } else {
            revert WrongErrorConfiguration(selector);
        }
    }

    function _validateDeltaBalance(uint256 beforeBalance, uint256 afterBalance) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, 0, DeltaRule.CONSTANT)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, 0));
    }

    function _processExactIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactIncrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, exactIncrease, DeltaRule.INCREASE_EXACT)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactIncrease));   
    }

    function _processExactDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 exactDecrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, exactDecrease, DeltaRule.DECREASE_EXACT)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, exactDecrease));   
    }

    function _processMaxIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxIncrease) private pure {       
        if (!_processInvariance(beforeBalance, afterBalance, maxIncrease, DeltaRule.INCREASE_MAX)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxIncrease));   
    }

    function _processMinIncreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minIncrease) private pure {     
        if (!_processInvariance(beforeBalance, afterBalance, minIncrease, DeltaRule.INCREASE_MIN)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minIncrease));      
    }

    function _processMaxDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 maxDecrease) private pure {             
        if (!_processInvariance(beforeBalance, afterBalance, maxDecrease, DeltaRule.DECREASE_MAX)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, maxDecrease));
    }

    function _processMinDecreaseBalance(uint256 beforeBalance, uint256 afterBalance, uint256 minIncrease) private pure {
        if (!_processInvariance(beforeBalance, afterBalance, minIncrease, DeltaRule.DECREASE_MIN)) revert InvariantViolationBalance(ValuePerPosition(beforeBalance, afterBalance, minIncrease));
    }

    modifier invariantBalance() {
        uint256 beforeBalance = _getBalance();
        _;
        uint256 afterBalance = _getBalance();
        _validateDeltaBalance(beforeBalance, afterBalance);
    }

    modifier assertBalanceEquals(uint256 expected) {
        _;
        uint256 actualBalance = _getBalance();
        _validateDeltaBalance(expected, actualBalance);
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
    
    function _processArray(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory expectedDeltaArray, DeltaRule selector) private pure returns (uint256, ValuePerPosition[] memory) {
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
   
    function _validateDeltaStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, new uint256[](beforeValueArray.length), DeltaRule.CONSTANT);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray); 
    }

    function _processExactIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactIncreaseArray, DeltaRule.INCREASE_EXACT);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processExactDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactDecreaseArray, DeltaRule.DECREASE_EXACT);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMaxIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxIncreaseArray, DeltaRule.INCREASE_MAX);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMinIncreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minIncreaseArray, DeltaRule.INCREASE_MIN);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMaxDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxDecreaseArray, DeltaRule.DECREASE_MAX);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }

    function _processMinDecreaseStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minDecreaseArray, DeltaRule.DECREASE_MIN);
        if (errorAccumulator > 0) revert InvariantViolationStorage(errorArray);
    }
   
    modifier invariantStorage(bytes32[] storage positions) {
        uint256[] memory beforeValueArray = _getStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getStorageArray(positions);
        _validateDeltaStorage(beforeValueArray, afterValueArray);
    }

    modifier assertStorageEquals(bytes32[] storage positions, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualStorageArray = _getStorageArray(positions);
        _validateDeltaStorage(expectedArray, actualStorageArray);
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
    function _getNumTransientStoragePositions(bytes32[] memory positions) private pure returns (uint256) {
        return positions.length;
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
               
    function _validateDeltaTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, new uint256[](beforeValueArray.length), DeltaRule.CONSTANT);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray); 
    }

    function _processExactIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactIncreaseArray, DeltaRule.INCREASE_EXACT);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processExactDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory exactDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, exactDecreaseArray, DeltaRule.DECREASE_EXACT);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMaxIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxIncreaseArray, DeltaRule.INCREASE_MAX);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMinIncreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minIncreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minIncreaseArray, DeltaRule.INCREASE_MIN);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMaxDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory maxDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, maxDecreaseArray, DeltaRule.DECREASE_MAX);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    function _processMinDecreaseTransientStorage(uint256[] memory beforeValueArray, uint256[] memory afterValueArray, uint256[] memory minDecreaseArray) private pure {
        (uint256 errorAccumulator, ValuePerPosition[] memory errorArray) = _processArray(beforeValueArray, afterValueArray, minDecreaseArray, DeltaRule.DECREASE_MIN);
        if (errorAccumulator > 0) revert InvariantViolationTransientStorage(errorArray);
    }

    modifier invariantTransientStorage(bytes32[] memory positions) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _validateDeltaTransientStorage(beforeValueArray, afterValueArray);
    }

    modifier assertTransientStorageEquals(bytes32[] memory positions, uint256[] memory expectedArray) {
        _;
        uint256[] memory actualStorageArray = _getTransientStorageArray(positions);
        _validateDeltaTransientStorage(expectedArray, actualStorageArray);
    }
    
    modifier exactIncreaseTransientStorage(bytes32[] memory positions, uint256[] memory exactIncreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processExactIncreaseTransientStorage(beforeValueArray, afterValueArray, exactIncreaseArray);
    }

    modifier exactDecreaseTransientStorage(bytes32[] memory positions, uint256[] memory exactDecreaseArray) {
        uint256[] memory beforeValueArray = _getTransientStorageArray(positions);
        _;
        uint256[] memory afterValueArray = _getTransientStorageArray(positions);
        _processExactDecreaseTransientStorage(beforeValueArray, afterValueArray, exactDecreaseArray);
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
}

