// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Stablecoin} from "../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../src/core/CollateralRegistry.sol";
import {CDPManager} from "../src/core/CDPManager.sol";
import {LiquidationEngine} from "../src/core/LiquidationEngine.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Stablecoin
        Stablecoin stablecoin = new Stablecoin(
            "CDP Stablecoin",
            "CDP",
            1000000000 * 10**18  // 1B max supply
        );
        console.log("Stablecoin deployed at:", address(stablecoin));
        
        // 2. Deploy CollateralRegistry
        CollateralRegistry registry = new CollateralRegistry();
        console.log("CollateralRegistry deployed at:", address(registry));
        
        // 3. Deploy CDPManager
        CDPManager cdpManager = new CDPManager(
            address(stablecoin),
            address(registry)
        );
        console.log("CDPManager deployed at:", address(cdpManager));
        
        // 4. Deploy LiquidationEngine
        LiquidationEngine liquidationEngine = new LiquidationEngine(
            address(cdpManager),
            address(registry)
        );
        console.log("LiquidationEngine deployed at:", address(liquidationEngine));
        
        // 5. Grant necessary roles
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        
        registry.grantRole(registry.COLLATERAL_MANAGER_ROLE(), deployer);
        
        cdpManager.grantRole(cdpManager.LIQUIDATOR_ROLE(), address(liquidationEngine));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Stablecoin:", address(stablecoin));
        console.log("CollateralRegistry:", address(registry));
        console.log("CDPManager:", address(cdpManager));
        console.log("LiquidationEngine:", address(liquidationEngine));
        console.log("\nDeployment completed successfully!");
    }
}
