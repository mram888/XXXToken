pragma solidity 0.4.24;

import './Token.sol';

contract XXXToken is Token {
	string public name = 'XXXToken';
	string public symbol = 'XXX';
	uint256 public decimals = 18;
	address public crowdsaleAddress;
	address public owner;
	uint256 public ICOEndTime;

  // Added
  // The tokens already used for the presale buyers
  uint256 public tokensDistributedPresale = 0;

  // The tokens already used for the ICO buyers
  uint256 public tokensDistributedCrowdsale = 0;

  uint256 public totalSupply = 100e24; // 100M tokens with 18 decimals

  // The initial supply used for platform and development as specified in the whitepaper
  uint256 public initialSupply = 40e24;

  // The maximum amount of tokens sold in the crowdsale
  uint256 public limitCrowdsale = 60e24;

	modifier onlyCrowdsale {
		require(msg.sender == crowdsaleAddress);
		_;
	}

	modifier onlyOwner {
		require(msg.sender == owner);
		_;
	}

	modifier afterCrowdsale {
		require(now > ICOEndTime || msg.sender == crowdsaleAddress);
		_;
	}

  // When someone refunds tokens
  event RefundedTokens(address indexed user, uint256 tokens);

	constructor (uint256 _ICOEndTime) public Token() {
		require(_ICOEndTime > 0);
		owner = msg.sender;
		ICOEndTime = _ICOEndTime;

    // Added
    balances[msg.sender] = initialSupply;
	}

	function setCrowdsale(address _crowdsaleAddress) public onlyOwner {
		require(_crowdsaleAddress != address(0));
		crowdsaleAddress = _crowdsaleAddress;
	}

  /// @notice Distributes the presale tokens. Only the owner can do this
  /// @param _receiver The address of the buyer
  /// @param _amount The amount of tokens corresponding to that buyer
  /*function distributePresaleTokens(address _receiver, uint256 _amount) external onlyOwner {
    require(_receiver != address(0));
    require(_amount > 0 && _amount <= limitPresale);

    // Check that the limit of 10M presale tokens hasn't been met yet
    require(tokensDistributedPresale < limitPresale);
    require(tokensDistributedPresale.add(_amount) < limitPresale);

    tokensDistributedPresale = tokensDistributedPresale.add(_amount);
    balances[_receiver] = balances[_receiver].add(tokens);
  }*/

  /// @notice Distributes the ico tokens in the crowdsale
  /// @param _receiver The address of the buyer
  /// @param _amount The amount of tokens corresponding to that buyer
	function buyICOTokens(address _receiver, uint256 _amount) public onlyCrowdsale {
		require(_receiver != address(0));
		require(_amount > 0);

    // Added
    // Check that the limit of 50M ICO tokens hasn't been met yet
    require(tokensDistributedCrowdsale < limitCrowdsale);
    require(tokensDistributedCrowdsale.add(_amount) <= limitCrowdsale);

    tokensDistributedCrowdsale = tokensDistributedCrowdsale.add(_amount);
		// transfer(_receiver, _amount);
    // Added
    balances[_receiver] = balances[_receiver].add(_amount);
	}

  /// @notice Override the functions to not allow token transfers until the end of the ICO
  function transfer(address _to, uint256 _value) public afterCrowdsale returns(bool) {
    return super.transfer(_to, _value);
  }

  /// @notice Override the functions to not allow token transfers until the end of the ICO
  function transferFrom(address _from, address _to, uint256 _value) public afterCrowdsale returns(bool) {
    return super.transferFrom(_from, _to, _value);
  }

  /// @notice Override the functions to not allow token transfers until the end of the ICO
  function approve(address _spender, uint256 _value) public afterCrowdsale returns(bool) {
    return super.approve(_spender, _value);
  }

  /// @notice Override the functions to not allow token transfers until the end of the ICO
  function increaseApproval(address _spender, uint _addedValue) public afterCrowdsale returns(bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }

  /// @notice Override the functions to not allow token transfers until the end of the ICO
  function decreaseApproval(address _spender, uint _subtractedValue) public afterCrowdsale returns(bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }

  function emergencyExtract() external onlyOwner {
    owner.transfer(address(this).balance);
  }

  /// @notice Deletes the amount of tokens refunded from that buyer balance
  /// @param _buyer The buyer that wants the refund
  /// @param tokens The tokens to return
  function refundTokens(address _buyer, uint256 tokens) external onlyCrowdsale {
    require(_buyer != address(0));
    require(tokens > 0);
    require(balances[_buyer] >= tokens);

    balances[_buyer] = balances[_buyer].sub(tokens);
    emit RefundedTokens(_buyer, tokens);
  }
}
