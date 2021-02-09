pragma solidity ^0.5.4;

import "../Context.sol";
import "../ITRC20.sol";
import "../BaseTRC20.sol";

contract LeCasino is ITRC20, TRC20Detailed {
    constructor(address gr) public TRC20Detailed("LeCasino TOKEN", "LCA", 6) {
      require(gr != address(0), "invalid gr");
      _mint(gr, 1000000000 * 10 ** 6);
    }
}