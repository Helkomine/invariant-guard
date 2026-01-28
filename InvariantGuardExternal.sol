// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;
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

// -------- ETH BALANCE ---------
    function _getExtETHBalance(address account) private view returns (uint256) {
        return account.balance;
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }

    modifier invariantExtETHBalance(address account) {
        uint256 beforeBalance = _getExtETHBalance(account);
        _;
        uint256 afterBalance = _getExtETHBalance(account);
        _processInvariantBalance(beforeBalance, afterBalance);
    }
}

abstract contract InvariantGuardERC20 {
// Số dư token ERC20, ERC721 trên chính nó
// và các hợp đồng nằm trong khung thực 
// thi của nó (áp dụng giả định tin tưởng 
// vào hợp đồng token, vì vậy có thể phát
// sinh các tình huống không xác định nếu
// hợp đồng token bất thường (metamorphic
// logic)).

// -------- ERC20 BALANCE -----------

// -------- ERC20 APPROVAL ----------
// Để sử dụng chức năng này, các hợp đồng mục tiêu phải triển khai giao diện sau :
// `function getApprovedERC20(address owner) external view returns (uint256[] memory);`
}

abstract contract InvariantGuardERC721 {
// Hạn mức phê duyệt token ERC721 (ERC20
// hiện chưa được hỗ trợ vì chúng không có
// giao diện trả về tất cả người được phê
// duyệt như `getApproved()` của ERC721)
// trên chính nó và các hợp đồng nằm trong
// khung thực thi của nó (áp dụng giả định
// tin tưởng vào hợp đồng token, vì vậy có 
// thể phát sinh các tình huống không xác
// định nếu hợp đồng token bất thường
// (metamorphic logic)).
// -------- ERC721 BALANCE ----------

// -------- ERC721 APPROVAL ----------
}
