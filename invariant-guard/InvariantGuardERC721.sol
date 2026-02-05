// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
import "./InvariantGuardHelper.sol";

/**
 * @title InvariantGuardERC721
 * @author Helkomine (@Helkomine)
 *
 * @notice
 * Provides invariant protection for ERC721 token state.
 *
 * @dev
 * This contract enforces invariants by performing external queries to ERC721
 * token contracts. As a result, it operates under a trust assumption:
 * - If a token contract exhibits non-standard, malicious, or metamorphic behavior,
 *   observed balances or ownership data may become non-deterministic.
 *
 * This tradeoff is accepted by design, as ERC721 state inspection necessarily
 * relies on external calls.
 *
 * The contract intentionally does NOT attempt to observe or validate external
 * contract bytecode, in order to remain compatible with the Ethereum EOF roadmap.
 *
 * Supported invariant categories:
 * - Balance invariants for one or more specified ERC721 tokens
 * - Ownership invariants for one or more specified ERC721 token IDs
 */
abstract contract InvariantGuardERC721 {
    using InvariantGuardHelper for *;

    /**
     * @notice
     * Ensures that ERC721 balances for the specified token-account pairs
     * remain unchanged across the execution of the protected function.
     */
    modifier invariantERC721Balance(IERC721[] memory tokenArray, address[] memory accountArray) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processConstantERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray
        );
    }

    /**
     * @notice
     * Asserts that ERC721 balances equal the expected values after execution.
     */
    modifier assertERC721BalanceEquals(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory expectedArray
    ) {
        _;
        uint256[] memory actualBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processConstantERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            expectedArray,
            actualBalanceArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances increase by an exact amount.
     */
    modifier exactIncreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory exactIncreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processExactIncreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            exactIncreaseArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances increase by no more than the specified maximum.
     */
    modifier maxIncreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory maxIncreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMaxIncreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            maxIncreaseArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances increase by at least the specified minimum.
     */
    modifier minIncreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory minIncreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMinIncreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            minIncreaseArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances decrease by an exact amount.
     */
    modifier exactDecreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory exactDecreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processExactDecreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            exactDecreaseArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances decrease by no more than the specified maximum.
     */
    modifier maxDecreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory maxDecreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMaxDecreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            maxDecreaseArray
        );
    }

    /**
     * @notice
     * Ensures that ERC721 balances decrease by at least the specified minimum.
     */
    modifier minDecreaseERC721Balance(
        IERC721[] memory tokenArray,
        address[] memory accountArray,
        uint256[] memory minDecreaseArray
    ) {
        uint256[] memory beforeBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _;
        uint256[] memory afterBalanceArray = _getERC721BalanceArray(tokenArray, accountArray);
        _processMinDecreaseERC721Balance(
            ERC721ArrayInvariant(tokenArray),
            AccountArrayInvariant(accountArray),
            beforeBalanceArray,
            afterBalanceArray,
            minDecreaseArray
        );
    }

    /*//////////////////////////////////////////////////////////////
                                OWNER OF
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice
     * Ensures that ERC721 ownership for the specified token IDs
     * remains unchanged across execution.
     */
    modifier invariantERC721Owner(IERC721[] memory tokenArray, uint256[] memory tokenIdArray) {
        address[] memory beforeOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _;
        address[] memory afterOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _processConstantERC721Owner(
            ERC721ArrayInvariant(tokenArray),
            ERC721TokenIdArray(tokenIdArray),
            beforeOwnerArray,
            afterOwnerArray
        );
    }

    /**
     * @notice
     * Asserts that ERC721 ownership equals the expected owner set after execution.
     */
    modifier assertERC721OwnerEquals(
        IERC721[] memory tokenArray,
        uint256[] memory tokenIdArray,
        address[] memory expectedArray
    ) {
        _;
        address[] memory actualOwnerArray = _getERC721OwnerArray(tokenArray, tokenIdArray);
        _processConstantERC721Owner(
            ERC721ArrayInvariant(tokenArray),
            ERC721TokenIdArray(tokenIdArray),
            expectedArray,
            actualOwnerArray
        );
    }

    /**
     * @dev
     * Validates that ERC721 ownership remains unchanged.
     */
    function _processConstantERC721Owner(
        ERC721ArrayInvariant memory tokenERC721ArrayInvariant,
        ERC721TokenIdArray memory tokenIdERC721Array,
        address[] memory beforeOwnerArray,
        address[] memory afterOwnerArray
    ) private pure {
        (uint256 violationCount, AddressInvariant[] memory violations) =
            beforeOwnerArray._validateAddressArray(afterOwnerArray);

        if (violationCount > 0) {
            revert InvariantViolationERC721OwnerArray(
                tokenERC721ArrayInvariant,
                tokenIdERC721Array,
                violations
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                              BALANCE OF
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev
     * Returns the ERC721 balance of a single account.
     */
    function _getERC721Balance(IERC721 token, address account) private view returns (uint256) {
        return token.balanceOf(account);
    }

    /**
     * @dev
     * Returns an array of ERC721 balances for corresponding token-account pairs.
     */
    function _getERC721BalanceArray(
        IERC721[] memory tokenArray,
        address[] memory accountArray
    ) private view returns (uint256[] memory) {
        uint256 length = accountArray._getAddressArrayLength();
        length._revertIfArrayTooLarge();

        uint256[] memory balanceArray = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            balanceArray[i] = _getERC721Balance(tokenArray[i], accountArray[i]);
            unchecked { ++i; }
        }
        return balanceArray;
    }

    /**
     * @dev
     * Validates that ERC721 balances remain unchanged.
     */
    function _processConstantERC721Balance(
        ERC721ArrayInvariant memory tokenERC721ArrayInvariant,
        AccountArrayInvariant memory accountArrayInvariant,
        uint256[] memory beforeBalanceArray,
        uint256[] memory afterBalanceArray
    ) private pure {
        (uint256 violationCount, ValuePerPosition[] memory violations) =
            beforeBalanceArray._validateDeltaArray(
                afterBalanceArray,
                beforeBalanceArray._getUint256ArrayLength()._emptyArray(),
                DeltaConstraint.NO_CHANGE
            );

        if (violationCount > 0) {
            revert InvariantViolationERC721BalanceArray(
                tokenERC721ArrayInvariant,
                accountArrayInvariant,
                violations
            );
        }
    }

    /**
     * @dev
     * Returns the owner of a specific ERC721 token ID.
     */
    function _getERC721Owner(IERC721 token, uint256 tokenId) private view returns (address) {
        return token.ownerOf(tokenId);
    }

    /**
     * @dev
     * Returns an array of owners for corresponding ERC721 token and tokenId pairs.
     */
    function _getERC721OwnerArray(
        IERC721[] memory tokenArray,
        uint256[] memory tokenIdArray
    ) private view returns (address[] memory) {
        uint256 length = tokenArray.length;
        length._revertIfArrayTooLarge();

        address[] memory ownerArray = new address[](length);
        for (uint256 i = 0; i < length; ) {
            ownerArray[i] = _getERC721Owner(tokenArray[i], tokenIdArray[i]);
            unchecked { ++i; }
        }
        return ownerArray;
    }
}
