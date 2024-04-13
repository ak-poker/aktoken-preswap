// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AKTokenPreSwap
 * @dev This contract implements the AKTokenPreSwap functionality.
 * It is an Ownable and Pausable contract.
 */
contract AKTokenPreSwap is Ownable, Pausable {

    // USDT token contract
    IERC20 public usdtToken;

    // AK token contract
    IERC20 public akToken;

    // AK token supply for swap in the current chain
    uint256 public akSupply;

    /**
     * @dev The price of swap (unit: wei)
     * @notice To be precise, here is the price of USDT relative to AK
     * @notice For example, if the price is 25, it means that 1 USDT can be exchanged for 25 AK
     */
    uint256 public akPrice;

    // The cumulative number of AK sold in the current chain
    uint256 public akSold;

    // The cumulative amount of USDT received in the current chain
    uint256 public usdtReceived;

    // Maximum quota for a single account in the current chain
    uint256 public accountMaxQuota;

    // The wallet address of the foundation
    address public foundationWallet;

    // The accumulated amount purchased by the user in the current chain
    // account => quota
    mapping(address => uint256) public accountQuotas;

    // Event to notify the swap of AK
    event SwapAK(
        address account,
        uint256 usdtAmount,
        uint256 akAmount,
        uint256 timestamp
    );

    /**
     * @dev Constructor
     * @param _usdtToken USDT token contract
     * @param _akToken AK token contract
     * @param _akSupply AK token supply for swap in the current chain
     * @param _akPrice The price of swap (unit: wei)
     * @param _accountMaxQuota Maximum quota for a single account in the current chain
     * @param _foundationWallet The wallet address of the foundation
     */
    constructor(
        IERC20 _usdtToken,
        IERC20 _akToken,
        uint256 _akSupply,
        uint256 _akPrice,
        uint256 _accountMaxQuota,
        address _foundationWallet
    ) Ownable(msg.sender) {
        usdtToken = _usdtToken;
        akToken = _akToken;
        akSupply = _akSupply;
        akPrice = _akPrice;
        accountMaxQuota = _accountMaxQuota;
        foundationWallet = _foundationWallet;
    }

    /**
     * @dev Set the price of swap
     * @param _akPrice The price of swap (unit: wei)
     * 
     * @notice For example:
     * if the _akPrice is 25, 
     * it means that 1 USDT can be exchanged for 25 AK
     */
    function setPrice(uint256 _akPrice) public onlyOwner {
        require(_akPrice > 0, "Token price must be greater than zero");
        akPrice = _akPrice;
    }

    /**
     * @dev Set the foundation wallet address
     * @param _foundationWallet The wallet address of the foundation
     */
    function setFoundationWallet(address _foundationWallet) public onlyOwner {
        require(_foundationWallet != address(0), "Foundation wallet can't be zero");
        foundationWallet = _foundationWallet;
    }

    /**
     * @dev Set the maximum quota for a single account
     * @param _accountMaxQuota Maximum quota for a single account
     */
    function setAccountMaxQuota(uint256 _accountMaxQuota) public onlyOwner {
        require(
            _accountMaxQuota > 0,
            "Account quota must be greater than zero"
        );
        accountMaxQuota = _accountMaxQuota;
    }

    /**
     * @dev Set the AK token supply for swap in the current chain
     * @param _akSupply AK token supply for swap in the current chain
     */
    function setAkSupply(uint256 _akSupply) public onlyOwner {
        require(
            _akSupply > 0,
            "_akSupply must be greater than zero"
        );
        akSupply = _akSupply;
    }

    /**
     * @dev Set the USDT and AK token contract
     * @param _usdt USDT token contract
     * @param _ak AK token contract
     */
    function setToken(IERC20 _usdt, IERC20 _ak) public onlyOwner {
        usdtToken = _usdt;
        akToken = _ak;
    }

    /**
     * @dev Calculate the amount of AK swaped by USDT
     * @param usdtAmount The amount of USDT
     */
    function evaSwapAK(uint256 usdtAmount) public view returns (uint256) {
        return (usdtAmount * akPrice) / 1e18;
    }

    /**
     * @dev Swap AK by USDT
     * @param usdtAmount The amount of USDT
     */
    function swapAK(uint256 usdtAmount) public whenNotPaused {
        uint256 akAmount = evaSwapAK(usdtAmount);
        require(foundationWallet != address(0), "Foundation wallet can't be zero");
        require(usdtAmount > 0, "USDT amount must be greater than zero");
        require((akAmount + akSold) <= akSupply, "Exceeded maximum AK supply");
        require(
            (akAmount + accountQuotas[msg.sender]) <= accountMaxQuota,
            "Exceeded account maximum quota"
        );
        require(
            usdtToken.allowance(msg.sender, address(this)) >= usdtAmount,
            "Insufficient allowance for USDT"
        );
        require(
            akToken.balanceOf(address(this)) >= akAmount,
            "Insufficient AK token balance"
        );

        usdtToken.transferFrom(msg.sender, foundationWallet, usdtAmount);
        akToken.transfer(msg.sender, akAmount);

        akSold += akAmount;
        usdtReceived += usdtAmount;
        accountQuotas[msg.sender] += akAmount;

        emit SwapAK(msg.sender, usdtAmount, akAmount, block.timestamp);
    }

    /**
     * @dev Withdraw tokens from the contract
     * only the owner can call, 
     * Prevent tokens from being transferred to this contract address due to errors.
     * 
     * @param token The token contract
     * @param to The recipient address
     * @param amount The amount of token
     */
    function withdraw(
        IERC20 token,
        address to,
        uint256 amount
    ) public onlyOwner {
        require(
            token.balanceOf(address(this)) >= amount,
            "Not enough token balance"
        );
        require(to != address(0), "Withdraw to the zero address");
        token.transfer(to, amount);
    }
    
    /**
     * @dev Get the account information
     * @param account The account address
     * 
     * @return _chainId Chain ID
     * @return _isPause Whether the purchase has been suspended
     * @return _usdtToken USDT token contract address
     * @return _akToken AK token contract address
     * @return _akSwap AK purchase contract address
     * @return _akSupply The maximum supply of AK in the current chain
     * @return _akPrice The price of AK (unit: wei)
     * @return _akSold The cumulative number of AK sold in the current chain
     * @return _usdtReceived Accumulate the amount of USDT received in the current chain
     * @return _accountMaxQuota Maximum quota for a single account
     * @return _accountQuota The accumulated amount purchased by the user in the current chain
     */
    function getAccountInfo(
        address account
    )
        public
        view
        returns (
            uint256 _chainId,
            bool _isPause,
            address _usdtToken,
            address _akToken,
            address _akSwap,
            uint256 _akSupply,
            uint256 _akPrice,
            uint256 _akSold,
            uint256 _usdtReceived,
            uint256 _accountMaxQuota,
            // **************************************************
            // If the user is not connected to the wallet, 
            // pass 0 address, and the following values are 0,
            // After the user successfully connects to the wallet, 
            // re-request the interface to obtain the user information.
            // **************************************************
            uint256 _accountQuota
        )
    {
        _akSwap = address(this);
        _chainId = block.chainid;
        _usdtToken = address(usdtToken);
        _akToken = address(akToken);
        _akSold = akSold;
        _akPrice = akPrice;
        _akSupply = akSupply;
        _accountMaxQuota = accountMaxQuota;
        _accountQuota = accountQuotas[account];
        _isPause = paused();
        _usdtReceived = usdtReceived;
    }
}
