// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "./IDiamondCut.sol";
import {DiamondStorageLib} from "./DiamondStorageLib.sol";

contract DiamondCutFacet is IDiamondCut {
    function diamondCut(
        FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) external override {
        DiamondStorageLib.enforceIsContractOwner();
        DiamondStorageLib.diamondCut(_diamondCut, _init, _calldata);
    }
}
