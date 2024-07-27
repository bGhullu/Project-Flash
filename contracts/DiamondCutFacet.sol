// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DiamondStorageLib.sol";

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }
    event DiamondCut(FacetCut[] diamondCut, address init, bytes _calldata);

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}

contract DiamondCutFacet is IDiamondCut {
    using DiamondStorageLib for DiamondStorageLib.DiamondStorage;

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        DiamondStorageLib.enforceIsContractOwner();
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();

        for (
            uint256 facetIndex;
            facetIndex < _diamondCut.length;
            facetIndex++
        ) {
            if (_diamondCut[facetIndex].action == FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (
                _diamondCut[facetIndex].action == FacetCutAction.Replace
            ) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (
                _diamondCut[facetIndex].action == FacetCutAction.Remove
            ) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert("Incorrect FacetCutAction");
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        require(
            _facetAddress != address(0),
            "Facet address can't be zero address"
        );
        uint16 selectorPosition = uint16(
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        if (selectorPosition == 0) {
            ds
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition = uint16(ds.facetAddresses.length);
            ds.facetAddresses.push(_facetAddress);
        }
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            require(
                ds.selectorToFacetAndPosition[selector].facetAddress ==
                    address(0),
                "Function already exists"
            );
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
                selector
            );
            ds
                .selectorToFacetAndPosition[selector]
                .facetAddress = _facetAddress;
            ds
                .selectorToFacetAndPosition[selector]
                .functionSelectorPosition = selectorPosition;
            selectorPosition++;
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        require(
            _facetAddress != address(0),
            "Facet address can't be zero address"
        );
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(oldFacetAddress != address(0), "Function doesn't exist");
            require(
                oldFacetAddress != _facetAddress,
                "Function already exists in the facet"
            );
            ds
                .selectorToFacetAndPosition[selector]
                .facetAddress = _facetAddress;
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        require(
            _facetAddress == address(0),
            "Facet address must be zero address for removal"
        );
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(oldFacetAddress != address(0), "Function doesn't exist");
            require(
                oldFacetAddress != _facetAddress,
                "Function already removed"
            );
            uint256 selectorPosition = ds
                .selectorToFacetAndPosition[selector]
                .functionSelectorPosition;
            uint256 lastSelectorPosition = ds
                .facetFunctionSelectors[oldFacetAddress]
                .functionSelectors
                .length - 1;
            if (selectorPosition != lastSelectorPosition) {
                bytes4 lastSelector = ds
                    .facetFunctionSelectors[oldFacetAddress]
                    .functionSelectors[lastSelectorPosition];
                ds.facetFunctionSelectors[oldFacetAddress].functionSelectors[
                        selectorPosition
                    ] = lastSelector;
                ds
                    .selectorToFacetAndPosition[lastSelector]
                    .functionSelectorPosition = uint16(selectorPosition);
            }
            ds.facetFunctionSelectors[oldFacetAddress].functionSelectors.pop();
            delete ds.selectorToFacetAndPosition[selector];

            if (lastSelectorPosition == 0) {
                uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
                uint256 oldFacetAddressPosition = ds
                    .facetFunctionSelectors[oldFacetAddress]
                    .facetAddressPosition;
                if (oldFacetAddressPosition != lastFacetAddressPosition) {
                    address lastFacetAddress = ds.facetAddresses[
                        lastFacetAddressPosition
                    ];
                    ds.facetAddresses[
                        oldFacetAddressPosition
                    ] = lastFacetAddress;
                    ds
                        .facetFunctionSelectors[lastFacetAddress]
                        .facetAddressPosition = uint16(oldFacetAddressPosition);
                }
                ds.facetAddresses.pop();
                delete ds
                    .facetFunctionSelectors[oldFacetAddress]
                    .facetAddressPosition;
            }
        }
    }

    function initializeDiamondCut(
        address _init,
        bytes calldata _calldata
    ) internal {
        if (_init == address(0)) return;
        (bool success, ) = _init.delegatecall(_calldata);
        require(success, "Initialization function reverted");
    }
}
