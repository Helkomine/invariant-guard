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
 
## Thông số kỹ thuật

### Hằng số

BASE_OPCODE_COST : 3
 
### Mã lệnh
 
`MUTABLE (0x2f)`

Stack input

- `offset` : Vị trí bắt đầu của dữ liệu cần lấy trên bộ nhớ
- `length` : Kích thước dữ liệu tối đa được truy cập trên bộ nhớ
- `isGuard` : Cờ bool cho biết có kích hoạt cơ chế bảo vệ hay không

### Biến guardOrigin 

Biến này dùng để quản lý việc kích hoạt các điều khoản hạn chế trên toàn bộ khung thực thi trong suốt giao dịch. Các lựa chọn của biến này được cho như sau:

- `NONE` : Chưa kích hoạt điều khoản hạn chế.
- `LOCAL` : Điều khoản hạn chế chỉ được áp dụng trên khung thực thi hiện tại.
- `INHERITED` : Điều khoản hạn chế được kế thừa từ khung thực thi cha.

### RLP Data Structures

`MUTABLE` sử dụng cấu trúc mã hóa rlp của dữ liệu trên bộ nhớ của khung thực thi gọi nó, cấu trúc cụ thể có dạng như sau:

```
# Type aliases for RLP encoding
Option = uint8   # Danh sách lựa chọn trạng thái
Active = bool   # Cờ này cho biết loại trạng thái đã chọn được miễn trừ kiểm tra hay không
Address = bytes20   # 20-byte Ethereum address
AllowedStorage = bytes32   # Storage slot key
AllowedTransientStorage = bytes32   # Transient Storage slot key

Option = {
    0x00 : Code,   # Miễn trừ áp đặt trạng thái trên code
    0x01 : Nonce,   # Miễn trừ áp đặt trạng thái trên nonce
    0x02 : Balance,   # Miễn trừ áp đặt trạng thái trên balance
    0x03 : Storage,   # Miễn trừ áp đặt trạng thái trên toàn bộ slot của storage
    0x04 : TransientStorage   # Miễn trừ áp đặt trạng thái trên toàn bộ slot của transient storage
}

# Danh sách các thiết lập điều khoản hạn chế tương ứng với Option
Payload = {
    0x00 : Null,
    0x01 : Null,
    0x02 : Null,
    0x03 : List[AllowedStorage],
    0x04 : List[AllowedTransientStorage]
}

# Tập hợp các thiết lập tương ứng dựa trên Option
PolicyEntry = [
    Option,
    Active,
    Payload
]

# Tập hợp các thiết lập trên một địa chỉ được chọn
MutableSet = [
    Address,
    List[PolicyEntry]
]

# Mảng MutableSet
MutableSetList = List[MutableSet]

## Note : Mã giả Solidity nhằm mô tả hành vi, vui lòng thay thế vị trí có sử dụng nó bằng văn bản đặc tả thực tế và sau đó xóa mã giả đi.
struct PolicyEntry {
  bool active;
  mapping(bytes32 => bool) allowedSlot;
}
mapping(address => mapping(uint8 option => PolicyEntry)) lookup;
```

### Hành vi

#### Khởi tạo giao dịch

Khi bắt đầu giao dịch hãy khởi tạo biến `guardOrigin` là `NONE` và tập hợp `MutableSetList` trống trên khung thực thi cao nhất. 

#### Truyền bá điều khoản hạn chế 

Nếu khung thực thi hiện tại chuyển tiếp giao dịch xuống khung thực thi con thông qua các mã lệnh `CALL`, `DELEGATECALL`, `CALLCODE`, `STATICCALL`, `CREATE` và `CREATE2`, hãy chuyển tiếp toàn bộ `MutableSetList` của khung thực thi hiện tại và guardOrigin xuống khung thực thi con theo quy tắc sau đây:

- Nếu khung thực thi hiện tại đang có guardOrigin là NONE hãy chuyển tiếp guardOrigin là NONE xuống khung thực thi con.
- Nếu khung thực thi hiện tại đang có guardOrigin là LOCAL hoặc INHERITED hãy chuyển tiếp guardOrigin là INHERITED xuống khung thực thi con.

#### Thực thi mã lệnh MUTABLE trong khung hiện tại

Nếu đối số `isGuard` được đặt là false, hãy đặt lại guardOrigin là NONE chỉ khi guardOrigin là NONE hoặc LOCAL.

Nếu đối số `isGuard` được đặt là true:

- Nếu guardOrigin là NONE hoặc LOCAL hãy đặt MutableSetList là phần dữ liệu được giải mã trên bộ nhớ đã cho.
- Nếu guardOrigin là INHERITED, hãy đặt MutableSetList là phần giao của phần dữ liệu được giải mã trên bộ nhớ đã cho và MutableSetList kế thừa từ khung thực thi cha.

#### Thực thi bất biến trên mã lệnh thay đổi trạng thái

Trên khung thực thi hiện tại, nếu guardOrigin là LOCAL hoặc INHERITED thì các hành động sau đây PHẢI bị hoàn tác tương tự như khi gặp lỗi hết gas:

Note : Thay bằng ngôn ngữ đặc tả cho mã giả này
- Thực thi CALLCODE. 
- Thực thi SELFDESTRUCT.
- Thực thi CALL trong đó value > 0 và (lookup[address(this)][0x02].active == false hoặc lookup[targetAddress][0x02].active == false).
- Thực thi CREATE hoặc CREATE2 với (lookup[computedTargetAddress][0x00].active == false) hoặc (lookup[address(this)][0x01] == false hoặc lookup[computedTargetAddress][0x01] == false) hoặc (value > 0 và (lookup[address(this)][0x02].active == false hoặc lookup[computedTargetAddress][0x02].active == false)).
- Slot mục tiêu của SSTORE là lookup[address(this)][0x03].active == false và lookup[address(this)][0x03].allowedSlot[targetSlot] == false.
- Slot mục tiêu của TSTORE là lookup[address(this)][0x04].active == false và lookup[address(this)][0x04].allowedSlot[targetSlot] == false.

Lưu ý rằng các mã lệnh mới có tạo ra sự thay đổi trạng thái hoặc các loại trạng thái mới được thêm vào trong tương lai PHẢI điều chỉnh hành vi sao cho phù hợp với thông số kỹ thuật của mã lệnh này để tránh các vấn đề tương thích ngược.

### Các trường hợp ngoại lệ

- Hết gas
- Không đủ toán hạng trên ngăn xếp
- Kích thước tự mô tả của từng phần tử RLP trên bộ nhớ vượt quá giá trị `length` đã cho. 

### Chi phí gas

Chi phí gas cho mã lệnh `MUTABLE` bao gồm phí cơ bản `BASE_OPCODE_COST`, ngoài ra còn có chi phí mở rộng bộ nhớ theo quy tắc tính phí EVM hiện hành và chi phí tính trên mỗi chunk (32-byte) tương ứng với `length` được chỉ định nhằm hỗ trợ phân tích rlp.
   
## Lý do
