// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

// ============ Internal Imports ============
import {TokenRouter} from "./libs/TokenRouter.sol";
import {TokenMessage} from "./libs/TokenMessage.sol";
import {MailboxClient} from "../client/MailboxClient.sol";
import {IsdeUSD} from "../deUSD/IsdeUSD.sol";

// ============ External Imports ============
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Hyperlane ERC20 Token Collateral that wraps an existing ERC20 with remote transfer functionality.
 * @author Abacus Works
 */
contract HypERC20Collateral is TokenRouter {
    using SafeERC20 for IERC20;

    IERC20 public immutable wrappedToken;
    IsdeUSD public immutable sdeUSD;

    /**
     * @notice Constructor
     * @param erc20 Address of the token to keep as collateral
     */
    constructor(address erc20, address _mailbox) TokenRouter(_mailbox) {
        require(Address.isContract(erc20), "HypERC20Collateral: invalid token");
        wrappedToken = IERC20(erc20);

        // Update based on token deployment
        sdeUSD = IsdeUSD(0x5C5b196aBE0d54485975D1Ec29617D42D9198326);
    }

    function initialize(
        address _hook,
        address _interchainSecurityModule,
        address _owner
    ) public virtual initializer {
        _MailboxClient_initialize(_hook, _interchainSecurityModule, _owner);
    }

    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return wrappedToken.balanceOf(_account);
    }

    /**
     * @dev  Stakes wrappedToken.
     */
    function stakeWrappedToken(uint256 amount) external onlyOwner {
        sdeUSD.deposit(amount, address(this));
    }

    /**
     * @dev  Unstakes wrappedToken.
     */
    function unstakeWrappedToken(uint256 amount) external onlyOwner {
        sdeUSD.cooldownAssets(amount);
        sdeUSD.unstake(msg.sender);
    }

    /**
     * @dev  Approves `amount` of `wrappedToken` to stake on staking contract.
     */
    function approveWrappedTokenToStake(uint256 amount) external onlyOwner {
        wrappedToken.approve(address(sdeUSD), amount);
    }

    /**
     * @dev Transfers `_amount` of `wrappedToken` from `msg.sender` to this contract.
     * @inheritdoc TokenRouter
     */
    function _transferFromSender(
        uint256 _amount
    ) internal virtual override returns (bytes memory) {
        wrappedToken.safeTransferFrom(msg.sender, address(this), _amount);
        sdeUSD.deposit(_amount, address(this));
        return bytes(""); // no metadata
    }

    /**
     * @dev Transfers `_amount` of `wrappedToken` from this contract to `_recipient`.
     * @inheritdoc TokenRouter
     */
    function _transferTo(
        address _recipient,
        uint256 _amount,
        bytes calldata // no metadata
    ) internal virtual override {
        uint256 sharesToWithdraw = sdeUSD.convertToShares(_amount);
        sdeUSD.cooldownShares(sharesToWithdraw);
        sdeUSD.unstake(_recipient);
    }
}
