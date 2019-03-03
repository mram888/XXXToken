pragma solidity 0.4.24;

import './SafeMath.sol';
import './XXXToken.sol';
import './RefundVault.sol';

// 1. First you set the address of the wallet in the RefundVault contract that will store the deposit of ether
// 2. If the goal is reached, the state of the vault will change and the ether will be sent to the address
// 3. If the goal is not reached , the state of the vault will change to refunding and the users will be able to call claimRefund() to get their ether

contract Crowdsale {
    using SafeMath for uint256;

    bool public icoCompleted;
    uint256 public icoStartTime;
    uint256 public icoEndTime;
    uint256 public tokenRate;
    XXXToken public token;
    uint256 public fundingGoal;
    address public owner;
    uint256 public tokensRaised;
    uint256 public etherRaised;
    uint256 public rateTier1 = 5000;
    uint256 public rateTier2 = 4000;
    uint256 public rateTier3 = 3000;
    uint256 public rateTier4 = 2000;
    uint256 public limitTier1 = 15e24;
    uint256 public limitTier2 = 30e24;
    uint256 public limitTier3 = 45e24;
    // uint256 public limitTierFour = 60e6 * (10 ** token.decimals());

	// Added
	// The amount of wei raised
   	uint256 public weiRaised = 0;

	// The vault that will store the ether until the goal is reached
    RefundVault public vault;

	// The minimum amount of Wei you must pay to participate in the crowdsale
   	uint256 public constant minPurchase = 100 finney; // 0.1 ether

   	// The max amount of Wei that you can pay to participate in the crowdsale
   	uint256 public constant maxPurchase = 2000 ether;

	// You can only buy up to 60 M tokens during the ICO
    uint256 public constant maxTokensRaised = 60e24;

	// Minimum amount of tokens to be raised
    uint256 public constant minimumGoal = 1e24;

    // If the crowdsale wasn't successful, this will be true and users will be able
    // to claim the refund of their ether
    bool public isRefunding = false;

    // If the crowdsale has ended or not
    bool public isEnded = false;

    // The number of transactions
    uint256 public numberOfTransactions;

    // The gas price to buy tokens must be 50 gwei or below
    uint256 public limitGasPrice = 50000000000 wei;

    // How much each user paid for the crowdsale
    mapping(address => uint256) public crowdsaleBalances;

    // How many tokens each user got for the crowdsale
    mapping(address => uint256) public tokensBought;

    // To indicate who purchased what amount of tokens and who received what amount of wei
    event TokenPurchase(address indexed buyer, uint256 value, uint256 amountOfTokens);

	// Indicates if the crowdsale has ended
    event Finalized();

    modifier whenIcoCompleted {
        require(icoCompleted);
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function () public payable {
        buy();
    }

    constructor(uint256 _icoStart, uint256 _icoEnd, uint256 _tokenRate, address _tokenAddress, address _refundAddress, uint256 _fundingGoal) public {
        require(_icoStart != 0 &&
            _icoEnd != 0 &&
            _icoStart < _icoEnd &&
            _tokenRate != 0 &&
            _tokenAddress != address(0) &&
						_refundAddress != address(0) &&
            _fundingGoal != 0);

        icoStartTime = _icoStart;
        icoEndTime = _icoEnd;
        tokenRate = _tokenRate;
        token = XXXToken(_tokenAddress);
		vault = new RefundVault(_refundAddress);
        fundingGoal = _fundingGoal;
        owner = msg.sender;
    }

    function calculateExcessTokens(
      uint256 amount,
      uint256 tokensThisTier,
      uint256 tierSelected,
      uint256 _rate
    ) public returns(uint256 totalTokens) {
        require(amount > 0 && tokensThisTier > 0 && _rate > 0);
        require(tierSelected >= 1 && tierSelected <= 4);

        uint weiThisTier = tokensThisTier.sub(tokensRaised).div(_rate);
        uint weiNextTier = amount.sub(weiThisTier);
        uint tokensNextTier = 0;
        bool returnTokens = false;

        // If there's excessive wei for the last tier, refund those
        if(tierSelected != 4)
            tokensNextTier = calculateTokensTier(weiNextTier, tierSelected.add(1));
        else
            returnTokens = true;

        totalTokens = tokensThisTier.sub(tokensRaised).add(tokensNextTier);

        // Do the transfer at the end
        if(returnTokens) msg.sender.transfer(weiNextTier);
   }

    function calculateTokensTier(uint256 weiPaid, uint256 tierSelected)
        internal constant returns(uint256 calculatedTokens)
    {
        require(weiPaid > 0);
        require(tierSelected >= 1 && tierSelected <= 4);

        if(tierSelected == 1)
            calculatedTokens = weiPaid.mul(rateTier1);
        else if(tierSelected == 2)
            calculatedTokens = weiPaid.mul(rateTier2);
        else if(tierSelected == 3)
            calculatedTokens = weiPaid.mul(rateTier3);
        else
            calculatedTokens = weiPaid.mul(rateTier4);
   }

    function buy() public payable {
				require(validPurchase());

				uint256 tokensToBuy;
				uint256 amountPaid = calculateExcessBalance();

				// If the tokens raised are less than 12.5 million with decimals, apply the first rate
				if(tokensRaised < limitTier1) {
					// Tier 1
		    		tokensToBuy = amountPaid * (10 ** token.decimals()) / 1 ether * rateTier1;

		    		// If the amount of tokens that you want to buy gets out of this tier
		    		if(tokensRaised + tokensToBuy > limitTier1) {
		    			tokensToBuy = calculateExcessTokens(amountPaid, limitTier1, 1, rateTier1);
		    		}
				} else if(tokensRaised >= limitTier1 && tokensRaised < limitTier2) {
					// Tier 2
					tokensToBuy = amountPaid * (10 ** token.decimals()) / 1 ether * rateTier2;

					// If the amount of tokens that you want to buy gets out of this tier
					if(tokensRaised + tokensToBuy > limitTier2) {
		    			tokensToBuy = calculateExcessTokens(amountPaid, limitTier2, 2, rateTier2);
		    		}
				} else if(tokensRaised >= limitTier2 && tokensRaised < limitTier3) {
					// Tier 3
					tokensToBuy = amountPaid * (10 ** token.decimals()) / 1 ether * rateTier3;

					// If the amount of tokens that you want to buy gets out of this tier
					if(tokensRaised + tokensToBuy > limitTier3) {
		    			tokensToBuy = calculateExcessTokens(amountPaid, limitTier3, 3, rateTier3);
		    		}
				} else if(tokensRaised >= limitTier3) {
					// Tier 4
					tokensToBuy = amountPaid * (10 ** token.decimals()) / 1 ether * rateTier4;
				}

				// Send the tokens to the buyer
				token.buyICOTokens(msg.sender, tokensToBuy);

				// Increase the tokens raised and ether raised state variables
				tokensRaised += tokensToBuy;

				// Added
				weiRaised = weiRaised.add(amountPaid);

				// Keep a record of how many tokens everybody gets in case we need to do refunds
				tokensBought[msg.sender] = tokensBought[msg.sender].add(tokensToBuy);
				emit TokenPurchase(msg.sender, amountPaid, tokensToBuy);
				numberOfTransactions = numberOfTransactions.add(1);

				if (tokensRaised < minimumGoal) {
					vault.deposit.value(amountPaid)(msg.sender);
					if (goalReached()){
						vault.close();
					}
				}

				// If the minimum goal of the ICO has been reach, close the vault to send
				// the ether to the wallet of the crowdsale
				checkCompletedCrowdsale();
	}

	/// @notice Calculates how many ether will be used to generate the tokens in
	/// case the buyer sends more than the maximum balance but has some balance left
	/// and updates the balance of that buyer.
	/// For instance if he's 500 balance and he sends 1000, it will return 500
	/// and refund the other 500 ether
	function calculateExcessBalance() internal returns(uint256) {
	    uint256 amountPaid = msg.value;
	    uint256 differenceWei = 0;
	    uint256 exceedingBalance = 0;

	    // If we're in the last tier, check that the limit hasn't been reached
	    // and if so, refund the difference and return what will be used to
	    // buy the remaining tokens
	    if(tokensRaised >= limitTier3) {
	      uint256 addedTokens = tokensRaised.add(amountPaid.mul(rateTier4));

	      // If tokensRaised + what you paid converted to tokens is bigger than the max
	      if(addedTokens > maxTokensRaised) {

	         // Refund the difference
	         uint256 difference = addedTokens.sub(maxTokensRaised);
	         differenceWei = difference.div(rateTier4);
	         amountPaid = amountPaid.sub(differenceWei);
	       }
	    }

	    uint256 addedBalance = crowdsaleBalances[msg.sender].add(amountPaid);

	    // Checking that the individual limit of 2000 ETH per user is not reached
	    if(addedBalance <= maxPurchase) {
	       crowdsaleBalances[msg.sender] = crowdsaleBalances[msg.sender].add(amountPaid);
	    } else {
			// Substracting 1000 ether in wei
			exceedingBalance = addedBalance.sub(maxPurchase);
			amountPaid = amountPaid.sub(exceedingBalance);

			// Add that balance to the balances
			crowdsaleBalances[msg.sender] = crowdsaleBalances[msg.sender].add(amountPaid);
	    }

	    // Make the transfers at the end of the function for security purposes
	    if(differenceWei > 0)
	       msg.sender.transfer(differenceWei);

	    if(exceedingBalance > 0) {

	       // Return the exceeding balance to the buyer
	       msg.sender.transfer(exceedingBalance);
	    }

	    return amountPaid;
	}

    function extractEther() public whenIcoCompleted onlyOwner {
        owner.transfer(address(this).balance);
    }


	// Added
	/// @notice Checks if a purchase is considered valid
	/// @return bool If the purchase is valid or not
	function validPurchase() internal constant returns(bool) {
	 	bool withinPeriod = now >= icoEndTime && now <= icoStartTime;
	 	bool nonZeroPurchase = msg.value > 0;
	 	bool withinTokenLimit = tokensRaised < fundingGoal;
	 	bool minimumPurchase = msg.value >= minPurchase;
	 	bool hasBalanceAvailable = crowdsaleBalances[msg.sender] < maxPurchase;

	 	// We want to limit the gas to avoid giving priority to the biggest paying contributors
	 	//bool limitGas = tx.gasprice <= limitGasPrice;

	 	return withinPeriod && nonZeroPurchase && withinTokenLimit && minimumPurchase && hasBalanceAvailable;
	}

	/// @notice To see if the minimum goal of tokens of the ICO has been reached
	/// @return bool True if the tokens raised are bigger than the goal or false otherwise
	function goalReached() public constant returns(bool) {
	 	return tokensRaised >= minimumGoal;
	}

	/// @notice Public function to check if the crowdsale has ended or not
	function hasEnded() public constant returns(bool) {
	 	return now > icoEndTime || tokensRaised >= maxTokensRaised;
	}

	/// @notice Allow to extend ICO end date
   	/// @param _endTime Endtime of ICO
   	function setEndDate(uint256 _endTime)	external onlyOwner {
		require(now <= _endTime);
		require(icoEndTime < _endTime);

		icoEndTime = _endTime;
   	}


	/// @notice Check if the crowdsale has ended and enables refunds only in case the
	/// goal hasn't been reached
	function checkCompletedCrowdsale() public {
		if(!isEnded) {
			if(hasEnded() && !goalReached()){
				vault.enableRefunds();

				isRefunding = true;
				isEnded = true;
				emit Finalized();
        } else if(hasEnded()  && goalReached()) {
            isEnded = true;
            emit Finalized();
        }
      }
   }

   /// @notice If crowdsale is unsuccessful, investors can claim refunds here
   function claimRefund() public {
     require(hasEnded() && !goalReached() && isRefunding);

     vault.refund(msg.sender);
     token.refundTokens(msg.sender, tokensBought[msg.sender]);
   }
}
