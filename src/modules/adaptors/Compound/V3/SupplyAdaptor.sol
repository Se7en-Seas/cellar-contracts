// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { BaseAdaptor, ERC20, SafeTransferLib, Math } from "src/modules/adaptors/BaseAdaptor.sol";
import { IComet } from "src/interfaces/external/Compound/IComet.sol";

/**
 * @title Compound CToken Adaptor
 * @notice Allows Cellars to interact with Compound CToken positions.
 * @author crispymangoes
 */
contract SupplyAdaptor is BaseAdaptor {
    using SafeTransferLib for ERC20;
    using Math for uint256;

    //==================== Adaptor Data Specification ====================
    // adaptorData = abi.encode(Comet comet)
    // Where:
    // `comet` is the underling Compound V3 Comet this adaptor is working with
    //================= Configuration Data Specification =================
    // isLiquid bool
    // Indicates whether the position is liquid or not.
    //====================================================================

    //============================================ Global Functions ===========================================
    /**
     * @dev Identifier unique to this adaptor for a shared registry.
     * Normally the identifier would just be the address of this contract, but this
     * Identifier is needed during Cellar Delegate Call Operations, so getting the address
     * of the adaptor is more difficult.
     */
    function identifier() public pure override returns (bytes32) {
        return keccak256(abi.encode("Supply Adaptor V 1.0"));
    }

    //============================================ Implement Base Functions ===========================================
    /**
     * @notice Cellar already has possession of users ERC20 assets by the time this function is called,
     *         so there is nothing to do.
     */
    function deposit(uint256 assets, bytes memory adaptorData, bytes memory) public override {
        IComet comet = abi.decode(adaptorData, (IComet));

        ERC20 base = comet.baseToken();
        base.safeApprove(address(comet), assets);

        comet.supply(address(base), assets);

        _revokeExternalApproval(base, address(comet));
    }

    /**
     * @notice Cellar just needs to transfer ERC20 token to `receiver`.
     * @dev Important to verify that external receivers are allowed if receiver is not Cellar address.
     * @param assets amount of `token` to send to receiver
     * @param receiver address to send assets to
     * @param adaptorData data needed to withdraw from this position
     * @param configurationData data needed to determine if this position is liquid or not
     */
    function withdraw(
        uint256 assets,
        address receiver,
        bytes memory adaptorData,
        bytes memory configurationData
    ) public override {
        _externalReceiverCheck(receiver);

        bool isLiquid = abi.decode(configurationData, (bool));
        if (!isLiquid) revert BaseAdaptor__UserWithdrawsNotAllowed();

        IComet comet = abi.decode(adaptorData, (IComet));
        ERC20 base = comet.baseToken();

        comet.withdrawTo(receiver, address(base), assets);
    }

    /**
     * @notice Identical to `balanceOf`, unless isLiquid configuration data is false, then returns 0.
     */
    function withdrawableFrom(
        bytes memory adaptorData,
        bytes memory configurationData
    ) public view override returns (uint256) {
        bool isLiquid = abi.decode(configurationData, (bool));
        if (isLiquid) {
            IComet comet = abi.decode(adaptorData, (IComet));
            return comet.balanceOf(msg.sender);
        } else return 0;
    }

    /**
     * @notice Returns the balance of comet base token.
     */
    function balanceOf(bytes memory adaptorData) public view override returns (uint256) {
        IComet comet = abi.decode(adaptorData, (IComet));
        return comet.balanceOf(msg.sender);
    }

    /**
     * @notice Returns `comet.baseToken()`
     */
    function assetOf(bytes memory adaptorData) public view override returns (ERC20) {
        IComet comet = abi.decode(adaptorData, (IComet));
        return comet.baseToken();
    }

    /**
     * @notice This adaptor returns collateral, and not debt.
     */
    function isDebt() public pure override returns (bool) {
        return false;
    }

    //============================================ Strategist Functions ===========================================

    function supplyBase(IComet comet, uint256 assets) external {
        // TODO verify comet.
        ERC20 base = comet.baseToken();
        assets = _maxAvailable(base, assets);
        base.safeApprove(address(comet), assets);

        comet.supply(address(base), assets);

        _revokeExternalApproval(base, address(comet));
    }

    function withdrawBase(IComet comet, uint256 assets) external {
        // TODO verify comet.
        uint256 baseAssets = comet.balanceOf(address(this));

        // Cap withdraw amount to be baseAssets so that a strategist can not accidentally open a borrow using this function.
        if (assets > baseAssets) assets = baseAssets;
        ERC20 base = comet.baseToken();

        comet.withdraw(address(base), assets);
    }
}
