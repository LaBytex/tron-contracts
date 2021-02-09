pragma solidity ^0.5.4;

import "../SafeMath.sol";
import "../Ownable.sol";
import "../ITRC20.sol";

/**
 * @title BytexSale
 * @dev BytexSale contract is Ownable
 **/
contract BytexSale is Ownable {
  using SafeMath for uint256;
  ITRC20 bytexToken;

  uint256 public RATE = 2; // Number of tokens per TRX
  uint256 public CAP = 3000000; // Cap in TRX
  uint256 public START = 1613134800; // Feb 12, 2021 @ 12:00 EST
  uint256 public DAYS = 5; // 45 Day
  
  uint256 public initialTokens = 2000000 * 10**6; // Initial number of tokens available
  bool public initialized = false;
  uint256 public raisedAmount = 0;
  
  /**
   * TokensSold
   * @dev Log tokens sold onto the blockchain
   */
  event TokensSold(address indexed to, uint256 value);

  /**
   * isSaleActive
   * @dev ensures that the contract is still active
   **/
  modifier isSaleActive() {
    // Check if sale is active
    assert(isActive());
    _;
  }
  
  /**
   * BytexSale
   * @dev BytexSale constructor
   **/
  constructor(address _tokenAddr) public {
      require(_tokenAddr != address(0x0));
      bytexToken = ITRC20(_tokenAddr);
  }
  
  /**
   * initialize
   * @dev Initialize the contract
   **/
  function initialize() public onlyOwner {
      require(initialized == false); // Can only be initialized once
      require(tokensAvailable() == initialTokens); // Must have enough tokens allocated
      initialized = true;
  }

  /**
   * isActive
   * @dev Determines if the contract is still active
   **/
  function isActive() public view returns (bool) {
    return (
        initialized == true &&
        now >= START && // Must be after the START date
        now <= START.add(DAYS * 1 days) && // Must be before the end date
        goalReached() == false // Goal must not already be reached
    );
  }

  /**
   * goalReached
   * @dev Function to determine if goal has been reached
   **/
  function goalReached() public view returns (bool) {
    return (raisedAmount >= CAP * 1 trx);
  }

  /**
   * @dev Fallback function if trx is sent to address instead of buyTokens function
   **/
  function () external payable {
    buyTokens();
  }

  /**
   * buyTokens
   * @dev function that sells available tokens
   **/
  function buyTokens() public payable isSaleActive {
    uint256 sunAmount = msg.value; // Calculate tokens to sell
    uint256 tokens = sunAmount.mul(RATE);
    
    emit TokensSold(msg.sender, tokens); // log event onto the blockchain
    raisedAmount = raisedAmount.add(msg.value); // Increment raised amount
    bytexToken.transfer(msg.sender, tokens); // Send tokens to buyer
    
    owner.transfer(msg.value);// Send money to owner
  }

  /**
   * tokensAvailable
   * @dev returns the number of tokens allocated to this contract
   **/
  function tokensAvailable() public view returns (uint256) {
    return bytexToken.balanceOf(address(this));
  }

  /**
   * destroy
   * @notice Terminate contract and refund to owner
   **/
  function destroy() onlyOwner public {
    // Transfer tokens back to owner
    uint256 balance = bytexToken.balanceOf(address(this));
    assert(balance > 0);
    bytexToken.transfer(owner, balance);
    // There should be no ether in the contract but just in case
    selfdestruct(owner);
  }
}