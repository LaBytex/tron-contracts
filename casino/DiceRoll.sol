pragma solidity ^0.5.4;

import "../Ownable.sol";
import "../ITRC20.sol";

contract DiceRoll is Ownable {

  struct Game {
    address payable player;
    uint256 bet;
    uint256 prize;
    uint256 choice;
    uint256 result;
    bool over;
    uint8 state;
    uint8 currency;
  }
    
  mapping (bytes32 => Game) public games;
    
  // Minimum and maximum bets.
  uint256 public minBet = 15000000;
  uint256 public maxBet = 1000000000;

  uint256 public byxMinBet = 20000000;
  uint256 public byxMaxBet = 2000000000;

  uint256 public minChoice = 500;
  uint256 public maxChoice = 9500;

  uint256 public played;
  uint256 public winnings;
  uint256 private modulo = 10000;

  uint8 public edge = 2;
  uint8 public trxRewardRate = 5;
  uint8 public byxRewardRate = 10;

  ITRC20 byxToken;
  ITRC20 rewardToken;

  constructor(address _byxToken, address _rewardToken) public {
    byxToken = ITRC20(_byxToken);
    rewardToken = ITRC20(_rewardToken);
  } 
    
  event GameStarted(address indexed user, bytes32 seed, bool over, uint256 amount, uint8 currency);
  event GameResult(address indexed player, bytes32 seed, uint prize, uint rewardToken, uint256 result);

  function setBetRange(uint256 _min, uint256 _max) public onlyOwner {
    minBet = _min;
    maxBet = _max;
  }

  function setByxBetRange(uint256 _min, uint256 _max) public onlyOwner {
    byxMinBet = _min;
    byxMaxBet = _max;
  }

  function setChoiceRange(uint256 _min, uint256 _max) public onlyOwner {
    minChoice = _min;
    maxChoice = _max;
  }

  function setEdge(uint8 _edge) public onlyOwner {
    edge = _edge;
  }

  function setRewardRate(uint8 _trxRate, uint8 _byxRate) public onlyOwner {
    trxRewardRate = _trxRate;
    byxRewardRate = _byxRate;
  }

  function playGame(bytes32 _seed, uint256 _choice, bool _over) public payable {
    require (msg.value >= minBet && msg.value <= maxBet, "Amount out of range");
    _playGame(_seed, _choice, _over, msg.value, 0);
    emit GameStarted(msg.sender, _seed, _over, msg.value, 0);
  }

  function playGameWithBYX(bytes32 _seed, uint256 _choice, bool _over, uint256 _amount) public {
    require (_amount >= byxMinBet && _amount <= byxMaxBet, "Amount out of range");
    _playGame(_seed, _choice, _over, _amount, 1);
    byxToken.transferFrom(msg.sender, address(this), _amount);
    emit GameStarted(msg.sender, _seed, _over, _amount, 1);
  }

  function _playGame(bytes32 _seed, uint256 _choice, bool _over, uint256 _amount, uint8 _currency) internal {
    require (_choice >= minChoice && _choice <= maxChoice, "Choice out of range");

    // Check that the game is in 'clean' state.
    Game storage game = games[_seed];
    require (game.player == address(0), "Invalid game state");

    game.player = msg.sender;
    game.bet = _amount;
    game.choice = _choice;
    game.over = _over;
    game.currency = _currency;
    game.state = 1;
  }

  function confirm(bytes32 _seed, uint8 _v, bytes32 _r, bytes32 _s) public onlyOwner {
    bytes memory prefix = "\x19TRON Signed Message:\n32";
    bytes32 signatureHash = keccak256(abi.encodePacked(prefix, _seed));
    require (owner == ecrecover(signatureHash, _v, _r, _s), "ECDSA signature is not valid.");

    Game storage game = games[_seed];
    require(game.player != address(0) && game.state == 1, "Invalid game state");

    game.result = mod(uint256(_s), uint256(10000));
    game.state = 2;

    // Check if player wins, then calcuate the prize and send TRX or BYX token
    if ((game.over && game.result > game.choice) || (!game.over && game.result < game.choice)) {
      uint256 houseEdge = game.bet * edge / 100;
      game.prize = (game.bet - houseEdge) * modulo / game.choice;
      if (game.currency == 0) {
        safeTrxTransfer(game.player, game.prize);
      } else {
        safeTokenTransfer(game.player, game.prize);
      }
    } else {
      game.prize = 0;
    }

    uint256 rewardSent;
    // Send mined casino tokens based on wager currency rate
    if (game.currency == 0) {
      rewardSent = safeRewardTokenTransfer(game.player, game.bet / trxRewardRate);
    } else {
      rewardSent = safeRewardTokenTransfer(game.player, game.bet / byxRewardRate);
    }

    played = played + 1;
    winnings = winnings + game.prize;

    emit GameResult(game.player, _seed, game.prize, rewardSent, game.result);
  }

  function stats() public view returns (uint gamesPlayed, uint totalWinnings){
    gamesPlayed = played;
    totalWinnings = winnings;
  }
  
  function collectTrxProfit(address payable _to, uint _amount) public onlyOwner {
    safeTrxTransfer(_to, _amount);
  }

  function collectByxProfit(address _to, uint _amount) public onlyOwner {
    safeTokenTransfer(_to, _amount);
  }

  function emergencyWithdrawal(address payable _to) public onlyOwner {
    safeRewardTokenTransfer(_to, rewardToken.balanceOf(address(this)));
    safeTokenTransfer(_to, byxToken.balanceOf(address(this)));
    safeTrxTransfer(_to, address(this).balance);
  }

  function safeTrxTransfer(address payable _to, uint _amount) internal {
    _amount = _amount < address(this).balance ? _amount : address(this).balance;
    _to.transfer(_amount);
  }

  function safeRewardTokenTransfer(address _to, uint _amount) internal returns(uint amount) {
    uint balance = rewardToken.balanceOf(address(this));
    amount = (_amount > balance) ? balance : _amount;
    rewardToken.transfer(_to, amount);
  }

  function safeTokenTransfer(address _to, uint _amount) internal {
    uint balance = byxToken.balanceOf(address(this));
    _amount = (_amount > balance) ? balance : _amount;
    byxToken.transfer(_to, _amount);
  }

  function mod(uint a, uint b) internal pure returns (uint) {
    require(b != 0, "SafeMath: modulo by zero");
    return a % b;
  }
    
}