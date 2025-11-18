// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PolicyManager
 * @notice Manages and enforces investment policy constraints for Basilisk Vault
 * @dev Stores AI-generated constraints and validates operations against them
 */
contract PolicyManager is AccessControl {
    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");
    bytes32 public constant AI_ENGINE_ROLE = keccak256("AI_ENGINE_ROLE");
    
    // Policy constraint structure
    struct PolicyConstraint {
        string constraintId;           // Unique identifier for the constraint
        string description;            // Human-readable description
        uint256 minUSDPeggedPercent;   // Minimum percentage in USD-pegged assets (basis points)
        uint256 maxUnbackedCryptoPercent; // Maximum percentage in unbacked crypto (basis points)
        uint256 maxDailyVaR;           // Maximum daily Value-at-Risk (basis points)
        uint256 maxSingleAssetExposure; // Maximum exposure to single asset (basis points)
        bool isActive;                  // Whether constraint is active
        uint256 lastUpdated;            // Timestamp of last update
    }
    
    // Mapping of constraint ID to constraint data
    mapping(string => PolicyConstraint) public constraints;
    
    // List of all constraint IDs
    string[] public constraintIds;
    
    // Current portfolio state (for validation)
    struct PortfolioState {
        uint256 totalAssets;
        uint256 usdPeggedAssets;
        uint256 unbackedCryptoAssets;
        uint256 dailyVaR;
        mapping(address => uint256) assetExposures;
    }
    
    PortfolioState public currentState;
    
    // Events
    event ConstraintAdded(string indexed constraintId, string description);
    event ConstraintUpdated(string indexed constraintId);
    event ConstraintDeactivated(string indexed constraintId);
    event PolicyViolation(string indexed constraintId, string reason);
    event PortfolioStateUpdated(uint256 totalAssets);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POLICY_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Add a new policy constraint
     * @param constraintId Unique identifier for the constraint
     * @param description Human-readable description
     * @param minUSDPeggedPercent Minimum USD-pegged assets (basis points, e.g., 7000 = 70%)
     * @param maxUnbackedCryptoPercent Maximum unbacked crypto (basis points, e.g., 1000 = 10%)
     * @param maxDailyVaR Maximum daily VaR (basis points, e.g., 400 = 4%)
     * @param maxSingleAssetExposure Maximum single asset exposure (basis points)
     */
    function addConstraint(
        string memory constraintId,
        string memory description,
        uint256 minUSDPeggedPercent,
        uint256 maxUnbackedCryptoPercent,
        uint256 maxDailyVaR,
        uint256 maxSingleAssetExposure
    ) external onlyRole(AI_ENGINE_ROLE) {
        require(
            bytes(constraints[constraintId].constraintId).length == 0,
            "PolicyManager: constraint already exists"
        );
        
        constraints[constraintId] = PolicyConstraint({
            constraintId: constraintId,
            description: description,
            minUSDPeggedPercent: minUSDPeggedPercent,
            maxUnbackedCryptoPercent: maxUnbackedCryptoPercent,
            maxDailyVaR: maxDailyVaR,
            maxSingleAssetExposure: maxSingleAssetExposure,
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        constraintIds.push(constraintId);
        
        emit ConstraintAdded(constraintId, description);
    }
    
    /**
     * @notice Update an existing policy constraint
     * @param constraintId Identifier of the constraint to update
     * @param minUSDPeggedPercent New minimum USD-pegged assets (basis points)
     * @param maxUnbackedCryptoPercent New maximum unbacked crypto (basis points)
     * @param maxDailyVaR New maximum daily VaR (basis points)
     * @param maxSingleAssetExposure New maximum single asset exposure (basis points)
     */
    function updateConstraint(
        string memory constraintId,
        uint256 minUSDPeggedPercent,
        uint256 maxUnbackedCryptoPercent,
        uint256 maxDailyVaR,
        uint256 maxSingleAssetExposure
    ) external onlyRole(AI_ENGINE_ROLE) {
        require(
            bytes(constraints[constraintId].constraintId).length > 0,
            "PolicyManager: constraint does not exist"
        );
        
        PolicyConstraint storage constraint = constraints[constraintId];
        constraint.minUSDPeggedPercent = minUSDPeggedPercent;
        constraint.maxUnbackedCryptoPercent = maxUnbackedCryptoPercent;
        constraint.maxDailyVaR = maxDailyVaR;
        constraint.maxSingleAssetExposure = maxSingleAssetExposure;
        constraint.lastUpdated = block.timestamp;
        
        emit ConstraintUpdated(constraintId);
    }
    
    /**
     * @notice Deactivate a policy constraint
     * @param constraintId Identifier of the constraint to deactivate
     */
    function deactivateConstraint(string memory constraintId)
        external
        onlyRole(POLICY_ADMIN_ROLE)
    {
        require(
            bytes(constraints[constraintId].constraintId).length > 0,
            "PolicyManager: constraint does not exist"
        );
        
        constraints[constraintId].isActive = false;
        emit ConstraintDeactivated(constraintId);
    }
    
    /**
     * @notice Check if a deposit is allowed under current policies
     * @param depositor Address of the depositor
     * @param amount Amount to deposit
     * @return true if deposit is allowed
     */
    function canDeposit(address depositor, uint256 amount)
        external
        view
        returns (bool)
    {
        // TODO: Add KYB/identity checks via Rayls LayeredID integration
        // For now, allow all deposits
        return true;
    }
    
    /**
     * @notice Check if rebalancing is allowed
     * @return true if rebalancing can proceed
     */
    function canRebalance() external view returns (bool) {
        // Check all active constraints
        for (uint256 i = 0; i < constraintIds.length; i++) {
            PolicyConstraint memory constraint = constraints[constraintIds[i]];
            if (!constraint.isActive) continue;
            
            // Validate current state against constraints
            if (!_validateConstraint(constraint)) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * @notice Validate rebalance result against all constraints
     * @param newTotalAssets Total assets after rebalancing
     * @return true if rebalance result is valid
     */
    function validateRebalance(uint256 newTotalAssets)
        external
        view
        returns (bool)
    {
        // TODO: Update portfolio state and validate against constraints
        // For now, basic validation
        require(newTotalAssets > 0, "PolicyManager: invalid total assets");
        
        // Check all active constraints
        for (uint256 i = 0; i < constraintIds.length; i++) {
            PolicyConstraint memory constraint = constraints[constraintIds[i]];
            if (!constraint.isActive) continue;
            
            // TODO: Validate new portfolio state against constraint
            // This would require updating currentState with new allocations
        }
        
        return true;
    }
    
    /**
     * @notice Update portfolio state (called by risk engine)
     * @param totalAssets Total assets in portfolio
     * @param usdPeggedAssets Amount in USD-pegged assets
     * @param unbackedCryptoAssets Amount in unbacked crypto
     * @param dailyVaR Current daily Value-at-Risk (basis points)
     */
    function updatePortfolioState(
        uint256 totalAssets,
        uint256 usdPeggedAssets,
        uint256 unbackedCryptoAssets,
        uint256 dailyVaR
    ) external onlyRole(AI_ENGINE_ROLE) {
        currentState.totalAssets = totalAssets;
        currentState.usdPeggedAssets = usdPeggedAssets;
        currentState.unbackedCryptoAssets = unbackedCryptoAssets;
        currentState.dailyVaR = dailyVaR;
        
        emit PortfolioStateUpdated(totalAssets);
    }
    
    /**
     * @notice Update exposure to a specific asset
     * @param asset Address of the asset
     * @param exposure Amount of exposure
     */
    function updateAssetExposure(address asset, uint256 exposure)
        external
        onlyRole(AI_ENGINE_ROLE)
    {
        currentState.assetExposures[asset] = exposure;
    }
    
    /**
     * @notice Get a constraint by ID
     * @param constraintId Identifier of the constraint
     * @return constraint The constraint data
     */
    function getConstraint(string memory constraintId)
        external
        view
        returns (PolicyConstraint memory constraint)
    {
        return constraints[constraintId];
    }
    
    /**
     * @notice Get all constraint IDs
     * @return Array of all constraint identifiers
     */
    function getAllConstraintIds() external view returns (string[] memory) {
        return constraintIds;
    }
    
    /**
     * @notice Internal function to validate a constraint against current state
     * @param constraint The constraint to validate
     * @return true if constraint is satisfied
     */
    function _validateConstraint(PolicyConstraint memory constraint)
        internal
        view
        returns (bool)
    {
        if (currentState.totalAssets == 0) return true;
        
        // Check USD-pegged asset minimum
        uint256 usdPeggedPercent = (currentState.usdPeggedAssets * 10000) /
            currentState.totalAssets;
        if (usdPeggedPercent < constraint.minUSDPeggedPercent) {
            emit PolicyViolation(
                constraint.constraintId,
                "USD-pegged assets below minimum"
            );
            return false;
        }
        
        // Check unbacked crypto maximum
        uint256 unbackedCryptoPercent = (currentState.unbackedCryptoAssets *
            10000) / currentState.totalAssets;
        if (unbackedCryptoPercent > constraint.maxUnbackedCryptoPercent) {
            emit PolicyViolation(
                constraint.constraintId,
                "Unbacked crypto exceeds maximum"
            );
            return false;
        }
        
        // Check daily VaR maximum
        if (currentState.dailyVaR > constraint.maxDailyVaR) {
            emit PolicyViolation(
                constraint.constraintId,
                "Daily VaR exceeds maximum"
            );
            return false;
        }
        
        return true;
    }
}

