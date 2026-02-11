# INVARIANT-GUARD

Author: Helkomine (@Helkomine)

A framework to make `DELEGATECALL` safer.

## Background

`DELEGATECALL` was introduced very early in Ethereum [EIP-7](https://eips.ethereum.org/EIPS/eip-7) as a safer successor to `CALLCODE`.
It is a particularly powerful opcode: it allows a contract to load and execute code from a target address in the caller’s context. This implies that delegated code can freely modify the caller’s storage, something that plain `CALL` cannot fully replace.
In addition, `DELEGATECALL` preserves both `msg.sender` and `msg.value`, which makes it extremely useful for composability and immediate reasoning in delegated execution contexts.

However, despite its importance, the protocol has not introduced major improvements around this opcode since its inception. This does not mean that no issues exist. In practice, using `DELEGATECALL` imposes a significant additional burden on developers, especially regarding storage safety and layout management. Any inconsistency in layout assumptions can lead to catastrophic consequences.

### Existing Mitigations and Their Limitations

There have been attempts to mitigate these risks. One notable example is the introduction of explicit storage namespaces [ERC-7201](https://eips.ethereum.org/EIPS/eip-7201), which aims to reduce layout collisions.
However, such solutions primarily address storage layout assumptions and rely on the proxy delegating to a well-behaved logic contract. This implicitly assumes that there exists at least one “valid” execution path. In reality, layouts can still be broken, for example by unintentionally activating malicious logic embedded in a backdoored contract.
This problem becomes particularly severe in modular smart contract architectures, where users are allowed to install custom modules. Most users lack the expertise to thoroughly analyze the safety of these modules. Once installed, a malicious module can remain dormant and later be triggered by seemingly harmless transactions, ultimately allowing an attacker to seize full control of a wallet and cause irreversible damage.
Some cautious teams have implemented pre- and post-execution value checks to reduce the impact of `DELEGATECALL`. While helpful, these patterns are not widely adopted, leaving most developers to repeatedly reinvent partial and fragile safety mechanisms. As a result, many deployed contracts remain fundamentally exposed: a single mistake during delegated execution can result in total loss of control.

## Motivation and Overview

Based on these observations, the author originally introduced a complete implementation named `Safe-Delegatecall`, later renamed to `Invariant-Guard` to reflect a more ambitious goal:

Not only controlling state changes caused by `DELEGATECALL`, but by any opcode or execution path that may alter critical invariants.

This repository presents the first public Solidity implementation of `Invariant-Guard`. Feedback from the community is highly appreciated.
The author is also preparing an EIP proposal to provide protocol-level invariant protection, enabling global guarantees that cannot be fully achieved at the contract level alone.

(Note: the EIP draft is not yet available.)

## Usage Guide

`Invariant-Guard` currently provides four variants:

- `InvariantGuardInternal`
- `InvariantGuardExternal`
- `InvariantGuardERC20`
- `InvariantGuardERC721`

If you are only interested in usage examples or prefer to read the implementation directly, please familiarize yourself with the design principles below to avoid confusion.

### Available Files

There are five `Invariant-Guard` files in total:

- Four functional implementations (listed above)
- One shared helper library: `InvariantGuardHelper`.

### Core Mechanism

`Invariant-Guard` works by:

- Taking snapshots of selected values before execution
- Executing the target logic
- Performing post-execution validation

This design is conceptually similar to the pattern used in flash loan validation.

### Invariant Classification

In the design of `InvariantGuard`, invariants are extended along two dimensions:

**1. State Categories**
The following state types are supported:

- **Code**
- **Nonce**
- **Balance**
- **Storage**
- **Transient Storage**

**2. Threshold Configurations**

Each state category can be configured with a threshold policy:

- **EXACT** – Value must remain exactly unchanged
- **INCREASE_EXACT** – Must increase by an exact amount
- **INCREASE_MAX** – May increase up to a maximum bound
- **INCREASE_MIN** – Must increase by at least a minimum bound
- **DECREASE_EXACT** – Must decrease by an exact amount
- **DECREASE_MAX** – May decrease up to a maximum bound
- **DECREASE_MIN** – Must decrease by at least a minimum bound
 
Each invariant is exposed as a Solidity modifier whose name is composed of:

```
<Threshold> + <StateType>
```

**Special Case: Expectation-Based Invariants**
There is a special class of invariants prefixed with `assert`.
In this case, the expected value is provided explicitly by the calling contract rather than being read directly from the current state.
Despite this difference in value sourcing, these invariants are still classified under the **EXACT** category. 
Additional configurations may be researched and introduced in future versions.

### Integration into Client Contracts

To integrate InvariantGuard into your contract, import the appropriate module into your existing `.sol` file:

- `InvariantGuardInternal`:

```
import "https://github.com/Helkomine/invariant-guard/blob/main/invariant-guard/InvariantGuardInternal.sol";
```

- `InvariantGuardExternal`:

```
https://github.com/Helkomine/invariant-guard/blob/main/invariant-guard/InvariantGuardExternal.sol
```

- `InvariantGuardERC20`:

```
https://github.com/Helkomine/invariant-guard/blob/main/invariant-guard/InvariantGuardERC20.sol
```

- `InternalGuardERC721`:

```
https://github.com/Helkomine/invariant-guard/blob/main/invariant-guard/InvariantGuardERC721.sol
```

After importing, apply the provided modifiers to the functions you wish to protect.
Example:

```
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "https://github.com/Helkomine/invariant-guard/blob/main/invariant-guard/InvariantGuardInternal.sol";
import "@openzeppelin/contracts/utils/Address.sol";
contract InvariantSimple is InvariantGuardInternal {
    address owner;

    function selfDelegateCall(address target, bytes calldata data) public payable invariantStorage(_getSlot()) {
        Address.functionDelegateCall(target, data);
    }

    function _getSlot() internal pure returns (bytes32[] memory slots) {
        bytes32 slot;
        assembly {
            slot := owner.slot
        }
        slots = new bytes32[](1);
        slots[0] = slot;
    }
}
```

## Security Considerations

⚠️ Important:
This code has not been audited and must not be used in production.

### Understanding the Protection Limits

Developers must clearly understand the inherent limitations of this module and proactively account for areas it does not protect.
For this reason, the author strongly recommends using Invariant-Guard only for critical state locations, such as:

- Proxy pointers
- Ownership slots
- State explicitly declared as invariant by the original specification

### Difference from ReentrancyGuard

At first glance, the execution logic of InvariantGuard may resemble OpenZeppelin’s `ReentrancyGuard`. However, their execution models are fundamentally different.
Execution Flow Comparison
`ReentrancyGuard` follows the pattern:

```
Check → Write → Execute → Write
```

`InvariantGuard` follows the pattern:

```
Read → Execute → Read → Check
```

The only common element is that the protected execution occurs in the middle.
All other aspects differ.
State Impact and Cost Model
`ReentrancyGuard`
Introduces new state (older versions use storage).
Newer versions rely on transient storage, but still introduce local state mutation.
Has higher operational cost.
Is restricted in static execution contexts.
`InvariantGuard`
Only reads state before and after execution.
Does not introduce new state.
The primary cost comes from state access.
Has lower operational overhead.
Is not restricted under static execution contexts.
Functional Purpose
Most importantly:
ReentrancyGuard prevents reentrancy attacks.
InvariantGuard prevents unintended invariant violations.
These are distinct security concerns. Developers must clearly understand their differences to avoid misuse.
Combining both mechanisms is possible but should be done carefully, as their interaction may introduce unintended execution behavior.

## EIP Proposal

Based on the Solidity implementation of Invariant-Guard, the author has identified a clear separation between:

The inner ring: explicitly selected and guarded state locations (well-covered by this library)

The outer ring: all unspecified state locations (vast in number and impractical to enumerate)

This outer ring represents the fundamental weakness of any contract-level approach.
Solving this problem requires protocol-level support, such as:
A new opcode, or
A dedicated precompile that can “fence off” all non-designated state locations

For this reason, the author has decided to propose an EIP that introduces a robust, global solution, effectively eliminating attacks originating from the outer ring and elevating state safety to an absolute level.

(Note: the detailed draft is currently under development.)

## Final Remarks

Through this implementation, the author hopes to encourage serious discussion around invariant protection during execution, especially in the context of DELEGATECALL.

This topic is increasingly critical as Account Abstraction gains traction, driving widespread adoption of modular smart accounts. Security and scalability should not be treated as mutually exclusive trade-offs.

If you discover any issues in the code—logic errors, naming problems, or otherwise—please feel free to open a pull request.

Thank you very much.

## Bản thảo EIP

EIP-XXXX: Invariant Layout Guard Opcode

## Simple Summary

Introduce a protocol-level state safety mechanism through a new opcode.

## Abstract

This EIP introduces a new opcode, MUTABLE, which restricts state changes to an explicitly defined scope. Any attempt to modify state outside the permitted scope MUST cause execution to revert.

## Motivation

Unintended state mutation during execution is a persistent security risk in smart contract systems. This risk is especially pronounced in proxy-based architectures that rely on `DELEGATECALL`, where the calling contract effectively relinquishes control over which state changes may occur in the callee’s execution context.
At the protocol level, there is currently no mechanism to stabilize or constrain state layout during execution. Introducing such a mechanism enables safer composition of contracts, supports future extensibility, and improves overall robustness for an increasingly dynamic Layer 1 ecosystem.  
At present, there exist contract-level approaches for constraining state mutation, which we refer to as an inner guard. These mechanisms offer strong and programmable protection for explicitly declared locations but fundamentally cannot defend against mutations outside the specified set. Because the number of potentially mutable locations is unbounded, attempting full coverage at the contract level is infeasible under current gas constraints.
To achieve comprehensive protection, a complementary outer guard is required. This can only be implemented at the protocol level. By combining an inner guard with the proposed outer guard, contracts can form a robust firewall against unintended or malicious side effects arising from external calls. 

## Specification

### Constants

`BASE_OPCODE_COST` : `3`

### Opcode

`MUTABLE (0x2f)`

#### Stack input:

- `offset`: Memory offset at which the RLP-encoded data begins.
- `length`: Maximum number of bytes that may be read from memory.
- `isGuard`: Boolean flag indicating whether the guard mechanism is enabled.

#### `guardOrigin`

The `guardOrigin` variable tracks the origin and propagation of mutation restrictions throughout execution frames within a transaction. It SHALL take one of the following values:

- `NONE`: No mutation restrictions are active.
- `LOCAL`: Mutation restrictions are active and were established in the current execution frame.
- `INHERITED`: Mutation restrictions are active and were inherited from a parent execution frame.

### RLP Data Structures

The `MUTABLE` opcode interprets RLP-encoded data located in the caller’s memory.

#### Type aliases

- `Option`: `uint8`
- `Allowed`: `bool`
- `Address`: `bytes20`
- `AllowedStorage`: `bytes32`
- `AllowedTransientStorage`: `bytes32`

#### Option values

`Option` is a `uint8` value with the following meanings:
- `0x00`: Code
- `0x01`: Nonce
- `0x02`: Balance
- `0x03`: Storage
- `0x04`: TransientStorage

#### Payload interpretation

The `Payload` field SHALL be interpreted according to the associated Option value:

- For `0x00`, `0x01`, `0x02`: the payload MUST be empty.
- For `0x03`: the payload MUST be an RLP list of `AllowedStorage` values.
- For `0x04`: the payload MUST be an RLP list of `AllowedTransientStorage` values.

#### Structures

- `PolicyEntry`:

```
[ Option, Allowed, Payload ]
```

- `MutableSet`:

```
[ Address, List[PolicyEntry] ]
```

- `MutableSetList`:

```
List[MutableSet]
```

If multiple `PolicyEntry` elements for the same `Option` appear within a `MutableSet`, only the last occurrence in RLP order SHALL be applied.
If multiple `MutableSet` elements reference the same Address, they SHALL be processed in RLP order, with later entries overriding earlier ones.

### Semantics

#### Transaction initialization

At the start of transaction execution, `guardOrigin` SHALL be initialized to `NONE`, and the effective `MutableSetList` SHALL be empty in the top-level execution frame.

#### Propagation of mutation restrictions 

When an execution frame spawns a child frame via `CALL`, `DELEGATECALL`, `CALLCODE`, `STATICCALL`, `CREATE`, or `CREATE2`, both `guardOrigin` and the effective `MutableSetList` SHALL be propagated as follows:

- If `guardOrigin` is `NONE`, the child frame SHALL receive `guardOrigin = NONE`.
- If `guardOrigin` is `LOCAL` or `INHERITED`, the child frame SHALL receive `guardOrigin = INHERITED`.

#### Execution of the `MUTABLE` opcode

When executing the `MUTABLE` opcode, the EVM SHALL decode the RLP-encoded `MutableSetList` from memory starting at `offset`, reading at most `length` bytes.
If `isGuard` is set to `false`, the EVM SHALL set `guardOrigin` to `NONE` **only if** the current value of `guardOrigin` is `NONE` or `LOCAL`. If `guardOrigin` is `INHERITED`, this operation SHALL have no effect.
If `isGuard` is set to `true`:

- If `guardOrigin` is `NONE` or `LOCAL`, the decoded `MutableSetList` SHALL replace the current `MutableSetList`, and `guardOrigin` SHALL be set to `LOCAL`.
- If `guardOrigin` is `INHERITED`, the effective `MutableSetList` SHALL be computed as the intersection of the decoded `MutableSetList` and the inherited `MutableSetList` from the parent execution frame, and `guardOrigin` `SHALL` remain `INHERITED`.

#### Enforcement of mutation invariants

While executing an execution frame where `guardOrigin` is `LOCAL` or `INHERITED`, any instruction that attempts to mutate state outside the permitted scope defined by the effective `MutableSetList` SHALL result in an exceptional halt equivalent to an out-of-gas condition.
The following operations SHALL always result in an exceptional halt when `guardOrigin` is not `NONE`:

- Execution of `CALLCODE`.
- Execution of `SELFDESTRUCT`.

The following operations SHALL result in an exceptional halt unless explicitly permitted by the effective `MutableSetList`:

- `CALL` with a non-zero value, unless mutation of `Balance` is permitted for both the caller address and the target address.
- `CREATE` or `CREATE2`, unless mutation of `Code` and `Nonce` is permitted for the created address, and mutation of `Nonce` is permitted for the caller address. If a non-zero value is transferred, mutation of `Balance` MUST also be permitted for both addresses.
- `SSTORE`, unless mutation of `Storage` is permitted for the executing address and the target storage slot is explicitly allowed.
- `TSTORE`, unless mutation of `TransientStorage` is permitted for the executing address and the target transient storage slot is explicitly allowed.

Any future opcode or protocol change that introduces new forms of state mutation MUST define its interaction with `MUTABLE` in a manner consistent with the enforcement rules defined herein.

### Exceptional conditions

Execution of `MUTABLE` SHALL result in an exceptional halt if any of the following occur:

- Out-of-gas.
- Insufficient stack items.
- Any attempt to decode RLP data that would require reading beyond `length` bytes.
- The RLP payload does not conform to the `MutableSetList` structure defined in this specification.

### Gas cost

The gas cost of the `MUTABLE` opcode consists of:

- The base opcode cost `BASE_OPCODE_COST`.
- Memory expansion costs, calculated according to existing EVM rules.
- A per-chunk (32-byte) cost proportional to `length`, to account for RLP decoding overhead.
   
## Rationale

### Design Intent

The initial design goal was to enable safe and transparent use of modular smart contracts, allowing modules to be freely integrated while preserving the safety guarantees of the host contract.
Based on this idea, we developed `InvariantGuard`, a contract-level pattern that provides powerful and flexible modifiers for protecting state with fine-grained control. However, this and similar patterns were found to be inherently limited: they cannot protect unspecified state locations, and the number of such locations is too large to enumerate exhaustively.
Therefore, achieving full state coverage requires direct support from the protocol. The `MUTABLE` opcode addresses this gap by enforcing invariants at the execution environment level.

### No Prohibition Under STATICCALL

The `MUTABLE` opcode only configures execution constraints and does not itself introduce new state changes. As such, there is no technical justification for prohibiting its use in a `STATICCALL` execution context.

### Minimal Handling of CALLCODE and SELFDESTRUCT

Both `CALLCODE` and `SELFDESTRUCT` are considered deprecated. Consequently, only minimal checks are applied to these opcodes to ensure that no unintended bypass of `MUTABLE` constraints is possible.

### Extensible Option Design

The `MutableSetList` structure is explicitly designed to be extensible. This allows new invariant types or state categories to be added in the future without breaking contracts that rely on earlier versions of the `MUTABLE` opcode, and without introducing significant additional gas costs.

### length as a Maximum Size Hint

Since RLP encoding is self-describing, the length parameter serves solely as a hint for clients to quickly determine an upper bound on the data size when decoding a `MutableSetList`. It does not alter semantic interpretation.

### Allowing Option Overrides

Allowing later options to override earlier ones preserves flexibility and reduces the likelihood of unexpected failures caused by minor execution changes.

### No Threshold Limits

Introducing threshold limits for disallowed state locations provides no clear benefit. For allowed locations, programmable limits can already be effectively enforced using contract-level patterns such as `InvariantGuard`.

### Additional Parsing Cost for MUTABLE

An additional gas cost is introduced to account for RLP parsing and invariant management throughout execution. This cost is comparable to the `JUMPDEST` analysis cost applied to init_code during contract creation.

## Backwards Compatibility

### Opcode Behavior Changes

State-affecting opcodes are constrained by `MUTABLE` in a manner analogous to their behavior under `STATICCALL`. These effects are strictly transaction-scoped and do not alter the intrinsic semantics of the opcodes outside the configured execution environment.

### Upgrade Compatibility

Because `MutableSetList` relies on extensible Option encoding, future additions to the invariant system do not change the behavior of contracts that use earlier versions of `MUTABLE`.

## Security Considerations

### Safety–Flexibility Tradeoff

For maximum protection, contracts must precisely specify all permitted state mutations. This is a non-trivial task for most dApps.
Accordingly, this EIP allows dApps to omit fine-grained checks on individual storage and transient storage slots to simplify integration. In such cases, wallets or dApps are expected to assess whether the target contract is sufficiently safe for user interaction.
While this approach carries higher risk than exact slot-level enforcement, the risk can be mitigated through rigorous contract auditing.

### Compiler Support

Compilers should provide ergonomic high-level access to state under invariant constraints. At present, Solidity does not support complex transient storage variables, which significantly limits the usability of advanced safety mechanisms.
Close coordination between protocol upgrades and compiler enhancements is therefore essential to fully realize the security benefits of this design.

## Test Implementations

To be announced.

## Reference Implementation

To be announced.

## Copyright

Copyright and related rights waived via CC0.
