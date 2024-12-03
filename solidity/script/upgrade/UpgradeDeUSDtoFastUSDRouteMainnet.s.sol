// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.0;

import "forge-std/Script.sol";

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {HypERC20Collateral} from "contracts/token/HypERC20Collateral.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBase is Script {
    function setup() internal {
        // Start broadcast.
        vm.startBroadcast();

        // Read caller information.
        (, address deployer, ) = vm.readCallers();

        // Mainnet addresses
        address proxyAddress = 0x9AD81058c6C3Bf552C9014CB30E824717A0ee21b;
        address proxyAdminAddress = 0x076761865E04846E76BAA5f37eBa7AfeF0a69d40;
        address deUSDAddress = 0x15700B564Ca08D9439C58cA5053166E8317aa138;
        address mailboxAddress = 0xc005dc82818d67AF737725bD4bf75435d065D239;

        // Proxies
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
            payable(proxyAddress)
        );
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Deploy implementation
        HypERC20Collateral hypERC20Collateral = new HypERC20Collateral(
            deUSDAddress,
            mailboxAddress
        );

        // Upgrade
        proxyAdmin.upgrade(proxy, address(hypERC20Collateral));

        // Check storage
        HypERC20Collateral upgradedProxy = HypERC20Collateral(proxyAddress);
        require(address(upgradedProxy.wrappedToken()) == deUSDAddress);
        require(address(upgradedProxy.mailbox()) == mailboxAddress);
        require(upgradedProxy.owner() == deployer);

        upgradedProxy.stakeCurrentToken(
            upgradedProxy.balanceOf(address(upgradedProxy))
        );
        require(IERC20(deUSDAddress).balanceOf(address(upgradedProxy)) == 0);

        vm.stopBroadcast();
    }

    function run() external {
        setup();
    }

    // Exclude from coverage report
    function test() public virtual {}
}
