// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC173} from "./IERC173.sol";
import {DiamondStorageLib} from "./DiamondStorageLib.sol";

contract OwnershipFacet is IERC173 {
    using DiamondStorageLib for DiamondStorageLib.DiamondStorage;

    function transferOwnership(address _newOwner) external override {
        DiamondStorageLib.enforceIsContractOwner();
        DiamondStorageLib.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = DiamondStorageLib.diamondStorage().contractOwner;
    }
}
