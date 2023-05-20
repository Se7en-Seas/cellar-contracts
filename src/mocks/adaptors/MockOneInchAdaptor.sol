// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import { OneInchAdaptor } from "src/modules/adaptors/OneInch/OneInchAdaptor.sol";

contract MockOneInchAdaptor is OneInchAdaptor {
    /**
     * @notice Override the ZeroX adaptors identifier so both adaptors can be added to the same registry.
     */
    function identifier() public pure override returns (bytes32) {
        return keccak256(abi.encode("Mock 1Inch Adaptor V 1.0"));
    }

    /**
     * @notice Returns address of the testing contract in Foundry.
     */
    function target() public pure override returns (address) {
        return 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    }
}