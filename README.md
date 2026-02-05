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

## Reference Implementation

```
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
contract ReferenceImplementation {
    struct AddressSet {     
        address object;
        bool isAllowedAddress;
        bool isAllowedCode;
        bool isAllowedNonce;
        bool isAllowedBalance;
        bytes32[] allowedStorageList;
        bytes32[] allowedTransientStorageList;
        bytes32[] commitList;
    }
    struct Set {
        bool isAllowedAddress;
        bool isAllowedCode;
        bool isAllowedNonce;
        bool isAllowedBalance;
        mapping(bytes32 => bool) isAllowedStorage;
        mapping(bytes32 => bool) isAllowedTransientStorage;
        mapping(bytes32 => bool) isAllowedCommit;    
    }
    mapping(address => Set) allowedSet;

    function addAllowedSet(AddressSet[] calldata addressSet) internal {
        for (uint256 i = 0 ; i < addressSet.length ; ++i) {
            Set storage set = allowedSet[addressSet[i].object];
            set.isAllowedAddress = addressSet[i].isAllowedAddress;
            set.isAllowedCode = addressSet[i].isAllowedCode;
            set.isAllowedNonce = addressSet[i].isAllowedNonce;
            set.isAllowedBalance = addressSet[i].isAllowedBalance;
            for (uint256 j = 0 ; j < addressSet[i].allowedStorageList.length ; ++j) {
                set.isAllowedStorage[addressSet[i].allowedStorageList[j]] = true;
            }
            for (uint256 k = 0 ; k < addressSet[i].allowedTransientStorageList.length ; ++k) {
                set.isAllowedTransientStorage[addressSet[i].allowedTransientStorageList[k]] = true;
            }
            for (uint256 l = 0 ; l < addressSet[i].allowedTransientStorageList.length ; ++l) {
                set.isAllowedCommit[addressSet[i].commitList[l]] = true;
            }
        }
    }

    function removeAllowedSet(AddressSet[] calldata addressSet) internal {
        for (uint256 i = 0 ; i < addressSet.length ; ++i) {
            Set storage set = allowedSet[addressSet[i].object];
            set.isAllowedAddress = false;
            set.isAllowedCode = false;
            set.isAllowedNonce = false;
            set.isAllowedBalance = false;
            for (uint256 j = 0 ; j < addressSet[i].allowedStorageList.length ; ++j) {
                set.isAllowedStorage[addressSet[i].allowedStorageList[j]] = false;
            }
            for (uint256 k = 0 ; k < addressSet[i].allowedTransientStorageList.length ; ++k) {
                set.isAllowedTransientStorage[addressSet[i].allowedTransientStorageList[k]] = false;
            }
            for (uint256 l = 0 ; l < addressSet[i].allowedTransientStorageList.length ; ++l) {
                set.isAllowedCommit[addressSet[i].commitList[l]] = false;
            }
        }
    }

    function concatAllowedSet(AddressSet[] calldata currentAddressSet, AddressSet[] calldata addAddressSet) internal pure returns (AddressSet[] memory newAddressSet) {
        newAddressSet = new AddressSet[](currentAddressSet.length + addAddressSet.length);
        for (uint256 i = 0 ; i < newAddressSet.length ; ++i) {
            /*
            Set storage set = allowedSet[addressSet[i].object];
            set.isAllowedAddress = false;
            set.isAllowedCode = false;
            set.isAllowedNonce = false;
            set.isAllowedBalance = false;
            for (uint256 j = 0 ; j < addressSet[i].allowedStorageList.length ; ++j) {
                set.isAllowedStorage[addressSet[i].allowedStorageList[j]] = false;
            }
            for (uint256 k = 0 ; k < addressSet[i].allowedTransientStorageList.length ; ++k) {
                set.isAllowedTransientStorage[addressSet[i].allowedTransientStorageList[k]] = false;
            }
            for (uint256 l = 0 ; l < addressSet[i].allowedTransientStorageList.length ; ++l) {
                set.isAllowedCommit[addressSet[i].commitList[l]] = false;
            }
            */
        }
    }

    function cutAllowedSet(AddressSet[] calldata currentAddressSet, AddressSet[] calldata removeAddressSet) internal pure returns (AddressSet[] memory newAddressSet) {
        newAddressSet = new AddressSet[](currentAddressSet.length + removeAddressSet.length);
        for (uint256 i = 0 ; i < newAddressSet.length ; ++i) {
            /*
            Set storage set = allowedSet[addressSet[i].object];
            set.isAllowedAddress = false;
            set.isAllowedCode = false;
            set.isAllowedNonce = false;
            set.isAllowedBalance = false;
            for (uint256 j = 0 ; j < addressSet[i].allowedStorageList.length ; ++j) {
                set.isAllowedStorage[addressSet[i].allowedStorageList[j]] = false;
            }
            for (uint256 k = 0 ; k < addressSet[i].allowedTransientStorageList.length ; ++k) {
                set.isAllowedTransientStorage[addressSet[i].allowedTransientStorageList[k]] = false;
            }
            for (uint256 l = 0 ; l < addressSet[i].allowedTransientStorageList.length ; ++l) {
                set.isAllowedCommit[addressSet[i].commitList[l]] = false;
            }
            */
        }
    }
    /*
    function executeFrame(bytes calldata bytecode) public {
        bool isPrevFrameGuard;
        bool isFrameGuard;   
        Set storage set = addressSet[address(this)]; 
        for (uint256 i = 0 ; i < bytecode.length ; ++i) {
            if (bytecode[i] == SELFDESTRUCT) {           
                if (isPrevFrameGuard || isFrameGuard) {
                    
                assert(set.isAllowedCode);                
            }
        } else if (bytecode[i] == CREATE) {
            if (isPrevFrameGuard || isFrameGuard) {
                Set storage set = addressSet[address(this)];
                assert(set.isAllowedNonce);
            }
        } else if (bytecode[i] == CREATE2) {
            if (isPrevFrameGuard || isFrameGuard) {
                Set storage set = addressSet[address(this)];
                assert(set.isAllowedNonce);
            }    
        } else if (bytecode[i] == CALL) {
            if (isPrevFrameGuard || isFrameGuard) {
                Set storage targetSet = addressSet[stack.target()];
                assert(targetSet.isAllowedAddress);
                if (stack.callvalue()) assert(set.isAllowedBalance);
            }
        } else if (bytecode[i] == SSTORE) {
            if (isPrevFrameGuard || isFrameGuard) assert(set.isAllowedStorage[stack.slot()]);
        } else if (bytecode[i] == TSTORE) {
            if (isPrevFrameGuard || isFrameGuard) assert(set.isAllowedTransientStorage[stack.slot()]);
        }
    }   
    */
}
```

## Bản thảo EIP

EIP-XXXX : Thêm mã lệnh bảo vệ bất biến bố cục

## Tóm tắt đơn giản

Giới thiệu cơ chế an toàn trạng thái ở cấp độ giao thức thông qua một mã lệnh mới.
 
## Tóm tắt

Thêm một mã lệnh mới `MUTABLE` cấm các thay đổi trạng thái ngoài phạm vi đã thiết lập.

## Động lực

 Việc thay đổi trạng thái ngoài ý muốn trong quá trình thực thi luôn là mối đe dọa tiềm tàng trong vận hành hợp đồng thông minh. Điều này càng trở nên nghiêm trọng đối với các trường hợp sử dụng hợp đồng proxy, vốn dựa trên mã lệnh `DELEGATECALL`, mã lệnh này đặt hợp đồng vào thế bị động gần như hoàn toàn vì không có cách nào để kiểm soát những thay đổi sẽ được thực hiện trong khung bên dưới. Việc giao thức có giải pháp nhằm ổn định bố cục trạng thái trong quá trình thực thi là vô cùng cần thiết, điều này mang lại tiềm năng mở rộng trong tương lai nhưng vẫn đảm bảo an toàn cho hệ sinh thái layer 1 ngày càng năng động.
 
## Thông số kỹ thuật

### Hằng số

 BASE_OPCODE_COST : 3
 
### Mã lệnh
 
`MUTABLE`
Stack input
   `offset` : Vị trí bắt đầu của dữ liệu cần lấy trên bộ nhớ
   `size` : Kích thước dữ liệu cần lấy trên bộ nhớ
   `isGuard` : Cờ bool cho biết có kích hoạt cơ chế bảo vệ hay không
   
### RLP Data Structures

`MUTABLE` sử dụng cấu trúc mã hóa rlp của dữ liệu trên bộ nhớ được dùng cho mã lệnh này, cấu trúc cụ thể có dạng như sau:

```
# Type aliases for RLP encoding
Address = bytes20   # 20-byte Ethereum address
AllowedCode = bool   # Cờ này cho phép thay đổi mã hay không
AllowedNonce = bool   # Cờ này cho phép thay đổi nonce hay không
AllowedBalance = bool   # Cờ này cho phép thay đổi số dư hay không
AllowedStorage = bytes32   # Storage slot key
AllowedTransientStorage = bytes32   # Transient Storage slot key
AllowedCommit = bytes32   # Băm lời gọi cho phép thực thi

MutableSet = [
    Address,
    AllowedCode,
    AllowedNonce,
    AllowedBalance,
    List[AllowedCommit],
    List[AllowedStorage],
    List[AllowedTransientStorage]
]

MutableSetList = List[MutableSet]
```

 Hành vi
  Khi bắt đầu giao dịch hãy khởi tạo hai cờ isPrevFrameGuard và isFrameGuard là false và tập hợp MutableSetList trống trên khung thực thi cao nhất. 
  Nếu khung thực thi hiện tại chuyển tiếp giao dịch xuống khung thực thi con thông qua các mã lệnh CALL, DELEGATECALL, CALLCODE, STATICCALL, CREATE và CREATE2, hãy chuyển tiếp giá trị isPrevFrameGuard và tập hợp MutableSetList trong khung thực thi hiện tại xuống khung thực thi con đồng thời đặt isFrameGuard là false trên khung thực thi con.
  Nếu trong quá trình thực thi sử dụng mã lệnh `MUTABLE` hãy thực hiện các bước sau:
   1. Khung thực thi PHẢI được hoàn nguyên nếu nó đang ở trong STATICCALL.
   2.   
  Trong quá trình thực thi, hãy thực hiện các bước sau đây nếu isPrevFrameGuard hoặc isFrameGuard là true:
   Nếu khung thực thi gọi SELFDESTRUCT, PHẢI hoàn tác nếu isAllowedCode là false.
   Nếu khung thực thi gọi CREATE hoặc CREATE2, PHẢI hoàn tác nếu isAllowedNonce là false.
   Nếu khung thực thi gọi CALL, PHẢI hoàn tác nếu isAllowedBalance là false.
   Nếu khung thực thi sử dụng SSTORE, PHẢI hoàn tác nếu slot được chỉ định là false.
   Nếu khung thực thi sử dụng TSTORE, PHẢI hoàn tác nếu slot được chỉ định là false.
  Các trường hợp ngoại lệ
   Hết gas
   Không đủ toán hạng trên ngăn xếp
   
Lý do
Tính đến thời điểm hiện tại, đã có ít nhất một giải pháp kiểm soát sự thay đổi trạng thái 
