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
        address proxyAddress = 0xF43c2e36C2449f0DaAe975E40f48A419100f6959;
        address proxyAdminAddress = 0x17a81a4de8b89610995e61ab60c399D67236dEbc;
        address deUSDAddress = 0xa6B08f1B0d894429Ed73fB68F0330318b188e2B0;
        address sdeUSDAddress = 0x97D3e518029c622015afa7aD20036EbEF60A7A4e;
        address mailboxAddress = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
        address ogImpl = 0x1e204FDB0F3938a7F3b5Fa5019feE16425311173;

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

        upgradedProxy.approveWrappedTokenToStake(type(uint256).max);
        // upgradedProxy.stakeWrappedToken(IERC20(deUSDAddress).balanceOf(address(upgradedProxy)));
        // require(IERC20(deUSDAddress).balanceOf(address(upgradedProxy)) == 0);
        // require(IERC20(sdeUSDAddress).balanceOf(address(upgradedProxy)) > 0);
        // require(
        //     upgradedProxy.balanceOf(address(upgradedProxy)) == IERC20(sdeUSDAddress).balanceOf(address(upgradedProxy))
        // );

        vm.stopBroadcast();
    }

    function run() external {
        setup();
    }

    // Exclude from coverage report
    function test() public virtual {}
}
