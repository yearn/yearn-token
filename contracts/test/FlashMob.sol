// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "@openzeppelinV3/contracts/token/ERC20/IERC20.sol";

interface IFlashMint is IERC20 {
    function flashLoan(address _reciever, address _token, uint256 _amount bytes calldata _data) external returns (bool);
}

contract FlashMob {
    IFlashMint token;

    bytes callData;

    // Call with this many reentrant calls
    uint256 callDepth = 10;

    constructor(address _token) public {
        token = IFlashMint(_token);
    }

    function callNormal(uint256 _amount) external {
        callData = "";
        // INVARIANT: Will fail if contract doesn't have 1% of _amount
        token.flashLoan(address(this), address(token), _amount, "");
    }

    function callWithData(uint256 _amount, bytes calldata data) external {
        callData = data;
        // INVARIANT: Will fail if contract doesn't have 1% of _amount
        token.flashLoan(address(this), address(token), _amount, data);
    }
    
    function onFlashLoan(address _initaitor, address _token, uint256 _amount, uint256 _fee, bytes calldata _data) external {
        require(keccak256(_data) == keccak256(callData), "!callback data mismatch");

        if (keccak256(_data) == keccak256("call twice")) token.flashMint(_amount);

        if (keccak256(_data) == keccak256("reentrancy") && callDepth > 0) {
            callDepth -= 1;
            token.flashMint(_amount, "reentrancy");
        }
    }
}
