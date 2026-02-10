# INVARIANT-GUARD

Author: Helkomine (@Helkomine)

A framework to make `DELEGATECALL` safer.

## Background

`DELEGATECALL` was introduced very early in Ethereum (EIP-7) as a safer successor to `CALLCODE`.
It is a particularly powerful opcode: it allows a contract to load and execute code from a target address in the caller’s context. This implies that delegated code can freely modify the caller’s storage, something that plain `CALL` cannot fully replace.
In addition, `DELEGATECALL` preserves both msg.sender and msg.value, which makes it extremely useful for composability and immediate reasoning in delegated execution contexts.

However, despite its importance, the protocol has not introduced major improvements around this opcode since its inception. This does not mean that no issues exist. In practice, using DELEGATECALL imposes a significant additional burden on developers, especially regarding storage safety and layout management. Any inconsistency in layout assumptions or execution entry points can lead to catastrophic consequences.

A canonical example is the Parity multisig wallet incident, where an attacker invoked DELEGATECALL on the shared implementation contract. This triggered a SELFDESTRUCT, permanently destroying the logic contract and rendering all dependent wallets unusable.

(Reference link to be added)

### Existing Mitigations and Their Limitations

There have been attempts to mitigate these risks. One notable example is the introduction of explicit storage namespaces (ERC-7201), which aims to reduce layout collisions.
However, such solutions primarily address storage layout assumptions and rely on the proxy delegating to a well-behaved logic contract. This implicitly assumes that there exists at least one “valid” execution path. In reality, layouts can still be broken, for example by unintentionally activating malicious logic embedded in a backdoored contract.
This problem becomes particularly severe in modular smart contract architectures, where users are allowed to install custom modules. Most users lack the expertise to thoroughly analyze the safety of these modules. Once installed, a malicious module can remain dormant and later be triggered by seemingly harmless transactions, ultimately allowing an attacker to seize full control of a wallet and cause irreversible damage.
Some cautious teams have implemented pre- and post-execution value checks to reduce the impact of DELEGATECALL. While helpful, these patterns are not widely adopted, leaving most developers to repeatedly reinvent partial and fragile safety mechanisms. As a result, many deployed contracts remain fundamentally exposed: a single mistake during delegated execution can result in total loss of control.

## Motivation and Overview

Based on these observations, the author originally introduced a complete implementation named Safe-Delegatecall, later renamed to Invariant-Guard to reflect a more ambitious goal:

Not only controlling state changes caused by DELEGATECALL, but by any opcode or execution path that may alter critical invariants.

This repository presents the first public Solidity implementation of Invariant-Guard. Feedback from the community is highly appreciated.
The author is also preparing an EIP proposal to provide protocol-level invariant protection, enabling global guarantees that cannot be fully achieved at the contract level alone.

(Note: the EIP draft is not yet available.)

## Usage Guide

Invariant-Guard currently provides four variants:
InvariantGuardInternal
InvariantGuardExternal
InvariantGuardERC20
InvariantGuardERC721

If you are only interested in usage examples or prefer to read the implementation directly, please familiarize yourself with the design principles below to avoid confusion.

### Available Files

There are five Invariant-Guard files in total:
Four functional implementations (listed above)
One shared helper library: InvariantGuardHelper

### Core Mechanism

Invariant-Guard works by:
Taking snapshots of selected values before execution
Executing the target logic
Performing post-execution validation
This design is conceptually similar to the pattern used in flash loan validation.
Invariant Classification
Based on how value differences are evaluated, invariants are divided into two main categories:
Absolute Invariants
The value must remain exactly the same before and after execution.
Threshold-Based Invariants
The value may change, but only within a predefined threshold configuration.

## Difference Categories

Based on the nature of state differences, invariants are further divided into eight groups.
Note:
Example implementations are not yet provided, so usage guidance for certain cases—especially Storage and Transient Storage—will be refined in future revisions.

## Security Considerations

⚠️ Important:
This code has not been audited and must not be used in production.

### Understanding the Protection Limits

Developers must clearly understand the inherent limitations of this module and proactively account for areas it does not protect.
For this reason, the author strongly recommends using Invariant-Guard only for critical state locations, such as:
Proxy pointers
Ownership slots
State explicitly declared as invariant by the original specification

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

EIP-XXXX : Thêm mã lệnh bảo vệ bất biến bố cục

## Tóm tắt đơn giản

Giới thiệu cơ chế an toàn trạng thái ở cấp độ giao thức thông qua một mã lệnh mới.
 
## Tóm tắt

Thêm một mã lệnh mới `MUTABLE` cấm các thay đổi trạng thái ngoài phạm vi đã thiết lập. Bất kỳ nỗ lực nào làm thay đổi trạng thái ngoài phạm vi đã cho phải bị hoàn tác.

## Động lực

Việc thay đổi trạng thái ngoài ý muốn trong quá trình thực thi luôn là mối đe dọa tiềm tàng trong vận hành hợp đồng thông minh. Điều này càng trở nên nghiêm trọng đối với các trường hợp sử dụng hợp đồng proxy, vốn dựa trên mã lệnh `DELEGATECALL`, mã lệnh này đặt hợp đồng vào thế bị động gần như hoàn toàn vì không có cách nào để kiểm soát những thay đổi sẽ được thực hiện trong khung bên dưới. Việc giao thức có giải pháp nhằm ổn định bố cục trạng thái trong quá trình thực thi là vô cùng cần thiết, điều này mang lại tiềm năng mở rộng trong tương lai nhưng vẫn đảm bảo an toàn cho hệ sinh thái layer 1 ngày càng năng động.

Tính đến thời điểm hiện tại, đã có ít nhất một giải pháp kiểm soát sự thay đổi trạng thái ở cấp độ hợp đồng, chúng tôi gọi nó là một "rào chắn trong", lớp rào chắn này đem lại khả năng bảo vệ tốt và có thể lập trình được đối với những vị trí được chỉ định, tuy nhiên nó hoàn toàn không thể che chắn được những vị trí ngoài phạm vi đã cho. Do vậy chúng tôi cần một giải pháp đối tác gọi là "rào chắn ngoài" để đạt được sự bao phủ toàn diện trên trạng thái, điều này chỉ có thể đạt được thông qua sự thay đổi ở cấp độ giao thức. Bằng cách kết hợp cả "rào chắn trong" và "rào chắn ngoài" chúng ta thành công xây dựng một bức tường lửa kiên cố trước các tác động ngoài ý muốn khi thực hiện lời gọi ra bên ngoài.
 
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

#### Execution of the MUTABLE opcode

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
   
## Lý do

### `STATICCALL` Clarification

`STATICCALL` does not perform state mutation and is therefore not subject to `MUTABLE` enforcement.
