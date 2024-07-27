// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondLoupe} from "./IDiamondLoupe.sol";
import {DiamondStorageLib} from "./DiamondStorageLib.sol";

contract DiamondLoupeFacet is IDiamondLoupe {
    using DiamondStorageLib for DiamondStorageLib.DiamondStorage;

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress;
            facets_[i].functionSelectors = ds
                .facetFunctionSelectors[facetAddress]
                .functionSelectors;
        }
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return _facetFunctionSelectors The selectors associated with a facet address.
    function facetFunctionSelectors(
        address _facet
    ) external view override returns (bytes4[] memory _facetFunctionSelectors) {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        return ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return _facetAddresses The list of facet addresses.
    function facetAddresses()
        external
        view
        override
        returns (address[] memory _facetAddresses)
    {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        return ds.facetAddresses;
    }

    /// @notice Gets the facet address that supports the given selector.
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(
        bytes4 _functionSelector
    ) external view override returns (address facetAddress_) {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        facetAddress_ = ds
            .selectorToFacetAndPosition[_functionSelector]
            .facetAddress;
    }
}
