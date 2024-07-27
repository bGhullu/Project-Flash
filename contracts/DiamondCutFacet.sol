// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "./IDiamondCut.sol";
import {DiamondStorageLib} from "./DiamondStorageLib.sol";

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
            FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert("DiamondCutFacet: Incorrect FacetCutAction");
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        if (_init != address(0)) {
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    revert(string(error));
                } else {
                    revert("DiamondCutFacet: _init function reverted");
                }
            }
        }
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _facetAddress != address(0),
            "DiamondCutFacet: Add facet can't be address(0)"
        );
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();

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
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress == address(0),
                "DiamondCutFacet: Can't add function that already exists"
            );
            ds
                .selectorToFacetAndPosition[selector]
                .facetAddress = _facetAddress;
            ds
                .selectorToFacetAndPosition[selector]
                .functionSelectorPosition = selectorPosition;
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
                selector
            );
            selectorPosition++;
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _facetAddress != address(0),
            "DiamondCutFacet: Replace facet can't be address(0)"
        );
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();

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
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress != _facetAddress,
                "DiamondCutFacet: Can't replace function with same function"
            );
            removeFunction(oldFacetAddress, selector);
            ds
                .selectorToFacetAndPosition[selector]
                .facetAddress = _facetAddress;
            ds
                .selectorToFacetAndPosition[selector]
                .functionSelectorPosition = selectorPosition;
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
                selector
            );
            selectorPosition++;
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _facetAddress == address(0),
            "DiamondCutFacet: Remove facet address must be address(0)"
        );
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();

        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            removeFunction(oldFacetAddress, selector);
        }
    }

    function removeFunction(address _facetAddress, bytes4 selector) internal {
        DiamondStorageLib.DiamondStorage storage ds = DiamondStorageLib
            .diamondStorage();
        require(
            _facetAddress != address(0),
            "DiamondCutFacet: Can't remove function that doesn't exist"
        );
        require(
            _facetAddress ==
                ds.selectorToFacetAndPosition[selector].facetAddress,
            "DiamondCutFacet: Facet address does not match function selector"
        );
        uint256 selectorPosition = ds
            .selectorToFacetAndPosition[selector]
            .functionSelectorPosition;
        uint256 lastSelectorPosition = ds
            .facetFunctionSelectors[_facetAddress]
            .functionSelectors
            .length - 1;
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds
                .facetFunctionSelectors[_facetAddress]
                .functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[
                    selectorPosition
                ] = lastSelector;
            ds
                .selectorToFacetAndPosition[lastSelector]
                .functionSelectorPosition = uint16(selectorPosition);
        }
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[selector];

        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[
                    lastFacetAddressPosition
                ];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds
                    .facetFunctionSelectors[lastFacetAddress]
                    .facetAddressPosition = uint16(facetAddressPosition);
            }
            ds.facetAddresses.pop();
            delete ds
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition;
        }
    }

    function generateSelectors(
        address _facet
    ) internal view returns (bytes4[] memory selectors) {
        uint256 selectorCount;
        bytes memory data = abi.encodeWithSignature("getSelectors()", "");
        (bool success, bytes memory result) = _facet.staticcall(data);
        if (success) {
            assembly {
                selectorCount := mload(add(result, 0x20))
                selectors := mload(0x40)
                mstore(0x40, add(selectors, mul(add(selectorCount, 1), 0x20)))
                mstore(selectors, selectorCount)
                for {
                    let i := 0
                } lt(i, selectorCount) {
                    i := add(i, 1)
                } {
                    mstore(
                        add(selectors, add(0x20, mul(i, 0x20))),
                        mload(add(result, add(0x40, mul(i, 0x20))))
                    )
                }
            }
        } else {
            revert("DiamondCutFacet: Error fetching selectors");
        }
    }
}
