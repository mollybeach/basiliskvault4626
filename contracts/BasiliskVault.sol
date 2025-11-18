// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PolicyManager.sol";

/**
 * @title BasiliskVault
 * @notice ERC-4626 compliant vault for institutional DeFi yield strategies on Rayls
 * @dev Manages deposits, withdrawals, accounting, and share issuance with policy enforcement
 */
contract BasiliskVault is ERC4626, AccessControl {
    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    
    PolicyManager public policyManager;
    
    // Total assets under management
    uint256 private _totalAssets;
    
    // Rebalancing state
    bool public isRebalancing;
    
    // Events
    event PolicyManagerUpdated(address indexed newPolicyManager);
    event RebalancingStarted();
    event RebalancingCompleted(uint256 newTotalAssets);
    event YieldAccrued(uint256 amount);
    
    /**
     * @notice Initialize the vault with an underlying asset
     * @param asset The ERC20 token that will be deposited into the vault
     * @param name Name of the vault token
     * @param symbol Symbol of the vault token
     * @param _policyManager Address of the PolicyManager contract
     */
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        address _policyManager
    ) ERC4626(asset) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ADMIN_ROLE, msg.sender);
        policyManager = PolicyManager(_policyManager);
    }
    
    /**
     * @notice Deposit assets into the vault
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive vault shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        returns (uint256 shares)
    {
        // Check policy constraints before deposit
        require(
            policyManager.canDeposit(msg.sender, assets),
            "BasiliskVault: deposit violates policy constraints"
        );
        
        return super.deposit(assets, receiver);
    }
    
    /**
     * @notice Mint vault shares
     * @param shares Amount of shares to mint
     * @param receiver Address to receive vault shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        returns (uint256 assets)
    {
        // Check policy constraints before mint
        require(
            policyManager.canDeposit(msg.sender, shares),
            "BasiliskVault: mint violates policy constraints"
        );
        
        return super.mint(shares, receiver);
    }
    
    /**
     * @notice Withdraw assets from the vault
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }
    
    /**
     * @notice Redeem vault shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 assets)
    {
        return super.redeem(shares, receiver, owner);
    }
    
    /**
     * @notice Get total assets managed by the vault
     * @return Total amount of underlying assets
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _totalAssets;
    }
    
    /**
     * @notice Update total assets (called after yield accrual or rebalancing)
     * @param newTotalAssets New total assets value
     */
    function updateTotalAssets(uint256 newTotalAssets)
        external
        onlyRole(REBALANCER_ROLE)
    {
        uint256 oldTotalAssets = _totalAssets;
        _totalAssets = newTotalAssets;
        
        if (newTotalAssets > oldTotalAssets) {
            emit YieldAccrued(newTotalAssets - oldTotalAssets);
        }
    }
    
    /**
     * @notice Start rebalancing operation
     * @dev Sets rebalancing flag and checks policy constraints
     */
    function startRebalancing() external onlyRole(REBALANCER_ROLE) {
        require(!isRebalancing, "BasiliskVault: rebalancing already in progress");
        
        // Verify policy constraints before rebalancing
        require(
            policyManager.canRebalance(),
            "BasiliskVault: rebalancing violates policy constraints"
        );
        
        isRebalancing = true;
        emit RebalancingStarted();
    }
    
    /**
     * @notice Complete rebalancing operation
     * @param newTotalAssets Updated total assets after rebalancing
     */
    function completeRebalancing(uint256 newTotalAssets)
        external
        onlyRole(REBALANCER_ROLE)
    {
        require(isRebalancing, "BasiliskVault: no rebalancing in progress");
        
        // Verify policy constraints after rebalancing
        require(
            policyManager.validateRebalance(newTotalAssets),
            "BasiliskVault: rebalance result violates policy constraints"
        );
        
        _totalAssets = newTotalAssets;
        isRebalancing = false;
        
        emit RebalancingCompleted(newTotalAssets);
    }
    
    /**
     * @notice Update the PolicyManager contract address
     * @param newPolicyManager Address of the new PolicyManager
     */
    function setPolicyManager(address newPolicyManager)
        external
        onlyRole(VAULT_ADMIN_ROLE)
    {
        require(newPolicyManager != address(0), "BasiliskVault: invalid address");
        policyManager = PolicyManager(newPolicyManager);
        emit PolicyManagerUpdated(newPolicyManager);
    }
    
    /**
     * @notice Convert assets to shares
     * @param assets Amount of assets
     * @return shares Equivalent amount of shares
     */
    function convertToShares(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256 shares)
    {
        return super.convertToShares(assets);
    }
    
    /**
     * @notice Convert shares to assets
     * @param shares Amount of shares
     * @return assets Equivalent amount of assets
     */
    function convertToAssets(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256 assets)
    {
        return super.convertToAssets(shares);
    }
}

