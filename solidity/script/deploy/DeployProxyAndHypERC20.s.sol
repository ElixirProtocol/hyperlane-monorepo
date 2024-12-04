// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.0;

import "forge-std/Script.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {HypERC20Collateral} from "contracts/token/HypERC20Collateral.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBase is Script {
    function setup() internal {
        // Start broadcast.
        vm.startBroadcast();

        // Read caller information.
        (, address deployer, ) = vm.readCallers();

        // Sepolia
        address deUSDAddress = 0xa6B08f1B0d894429Ed73fB68F0330318b188e2B0;
        address mailboxAddress = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;

        // Deploy implementation
        HypERC20Collateral hypERC20Collateral = new HypERC20Collateral(
            deUSDAddress,
            mailboxAddress
        );

        // Proxies
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(hypERC20Collateral),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                deployer
            )
        );

        HypERC20Collateral proxyHypERC20 = HypERC20Collateral(address(proxy));
        require(address(proxyHypERC20.wrappedToken()) == deUSDAddress);
        require(address(proxyHypERC20.mailbox()) == mailboxAddress);

        vm.stopBroadcast();
    }

    function run() external {
        setup();
    }

    // Exclude from coverage report
    function test() public virtual {}
}
