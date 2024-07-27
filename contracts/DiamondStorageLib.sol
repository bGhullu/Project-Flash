// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// library DiamondStorageLib {
//     bytes32 constant DIAMOND_STORAGE_POSITION =
//         keccak256("diamond.standard.diamond.storage");

//     struct FacetAddressAndPosition {
//         address facetAddress;
//         uint16 functionSelectorPosition;
//     }

//     struct FacetFunctionSelectors {
//         bytes4[] functionSelectors;
//         uint16 facetAddressPosition;
//     }

//     struct DiamondStorage {
//         mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
//         mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
//         address[] facetAddresses;
//         mapping(bytes4 => bool) supportedInterfaces;
//         address contractOwner;
//     }

//     function diamondStorage()
//         internal
//         pure
//         returns (DiamondStorage storage ds)
//     {
//         bytes32 position = DIAMOND_STORAGE_POSITION;
//         assembly {
//             ds.slot := position
//         }
//     }

//     function enforceIsContractOwner() internal view {
//         require(
//             msg.sender == diamondStorage().contractOwner,
//             "Must be contract owner"
//         );
//     }

//     function setContractOwner(address _newOwner) internal {
//         diamondStorage().contractOwner = _newOwner;
//     }

//     function diamondCut(
//         IDiamondCut.FacetCut[] memory _diamondCut,
//         address _init,
//         bytes memory _calldata
//     ) internal {
//         DiamondStorage storage ds = diamondStorage();

//         for (
//             uint256 facetIndex;
//             facetIndex < _diamondCut.length;
//             facetIndex++
//         ) {
//             IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
//             if (action == IDiamondCut.FacetCutAction.Add) {
//                 addFunctions(
//                     _diamondCut[facetIndex].facetAddress,
//                     _diamondCut[facetIndex].functionSelectors
//                 );
//             } else if (action == IDiamondCut.FacetCutAction.Replace) {
//                 replaceFunctions(
//                     _diamondCut[facetIndex].facetAddress,
//                     _diamondCut[facetIndex].functionSelectors
//                 );
//             } else if (action == IDiamondCut.FacetCutAction.Remove) {
//                 removeFunctions(
//                     _diamondCut[facetIndex].facetAddress,
//                     _diamondCut[facetIndex].functionSelectors
//                 );
//             } else {
//                 revert("DiamondCut: Incorrect FacetCutAction");
//             }
//         }

//         emit IDiamondCut.DiamondCut(_diamondCut, _init, _calldata);

//         if (_init != address(0)) {
//             (bool success, bytes memory error) = _init.delegatecall(_calldata);
//             if (!success) {
//                 if (error.length > 0) {
//                     revert(string(error));
//                 } else {
//                     revert("DiamondCut: _init function reverted");
//                 }
//             }
//         }
//     }

//     function addFunctions(
//         address _facetAddress,
//         bytes4[] memory _functionSelectors
//     ) internal {
//         require(
//             _facetAddress != address(0),
//             "DiamondCut: Add facet can't be address(0)"
//         );
//         DiamondStorage storage ds = diamondStorage();

//         uint16 selectorPosition = uint16(
//             ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
//         );
//         if (selectorPosition == 0) {
//             ds
//                 .facetFunctionSelectors[_facetAddress]
//                 .facetAddressPosition = uint16(ds.facetAddresses.length);
//             ds.facetAddresses.push(_facetAddress);
//         }
//         for (
//             uint256 selectorIndex;
//             selectorIndex < _functionSelectors.length;
//             selectorIndex++
//         ) {
//             bytes4 selector = _functionSelectors[selectorIndex];
//             address oldFacetAddress = ds
//                 .selectorToFacetAndPosition[selector]
//                 .facetAddress;
//             require(
//                 oldFacetAddress == address(0),
//                 "DiamondCut: Can't add function that already exists"
//             );
//             ds
//                 .selectorToFacetAndPosition[selector]
//                 .facetAddress = _facetAddress;
//             ds
//                 .selectorToFacetAndPosition[selector]
//                 .functionSelectorPosition = selectorPosition;
//             ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
//                 selector
//             );
//             selectorPosition++;
//         }
//     }

//     function replaceFunctions(
//         address _facetAddress,
//         bytes4[] memory _functionSelectors
//     ) internal {
//         require(
//             _facetAddress != address(0),
//             "DiamondCut: Replace facet can't be address(0)"
//         );
//         DiamondStorage storage ds = diamondStorage();

//         uint16 selectorPosition = uint16(
//             ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
//         );
//         if (selectorPosition == 0) {
//             ds
//                 .facetFunctionSelectors[_facetAddress]
//                 .facetAddressPosition = uint16(ds.facetAddresses.length);
//             ds.facetAddresses.push(_facetAddress);
//         }
//         for (
//             uint256 selectorIndex;
//             selectorIndex < _functionSelectors.length;
//             selectorIndex++
//         ) {
//             bytes4 selector = _functionSelectors[selectorIndex];
//             address oldFacetAddress = ds
//                 .selectorToFacetAndPosition[selector]
//                 .facetAddress;
//             require(
//                 oldFacetAddress != _facetAddress,
//                 "DiamondCut: Can't replace function with same function"
//             );
//             removeFunction(oldFacetAddress, selector);
//             ds
//                 .selectorToFacetAndPosition[selector]
//                 .facetAddress = _facetAddress;
//             ds
//                 .selectorToFacetAndPosition[selector]
//                 .functionSelectorPosition = selectorPosition;
//             ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
//                 selector
//             );
//             selectorPosition++;
//         }
//     }

//     function removeFunctions(
//         address _facetAddress,
//         bytes4[] memory _functionSelectors
//     ) internal {
//         require(
//             _facetAddress == address(0),
//             "DiamondCut: Remove facet address must be address(0)"
//         );
//         DiamondStorage storage ds = diamondStorage();

//         for (
//             uint256 selectorIndex;
//             selectorIndex < _functionSelectors.length;
//             selectorIndex++
//         ) {
//             bytes4 selector = _functionSelectors[selectorIndex];
//             address oldFacetAddress = ds
//                 .selectorToFacetAndPosition[selector]
//                 .facetAddress;
//             removeFunction(oldFacetAddress, selector);
//         }
//     }

//     function removeFunction(address _facetAddress, bytes4 selector) internal {
//         DiamondStorage storage ds = diamondStorage();
//         require(
//             _facetAddress != address(0),
//             "DiamondCut: Can't remove function that doesn't exist"
//         );
//         require(
//             _facetAddress ==
//                 ds.selectorToFacetAndPosition[selector].facetAddress,
//             "DiamondCut: Facet address does not match function selector"
//         );
//         uint256 selectorPosition = ds
//             .selectorToFacetAndPosition[selector]
//             .functionSelectorPosition;
//         uint256 lastSelectorPosition = ds
//             .facetFunctionSelectors[_facetAddress]
//             .functionSelectors
//             .length - 1;
//         if (selectorPosition != lastSelectorPosition) {
//             bytes4 lastSelector = ds
//                 .facetFunctionSelectors[_facetAddress]
//                 .functionSelectors[lastSelectorPosition];
//             ds.facetFunctionSelectors[_facetAddress].functionSelectors[
//                     selectorPosition
//                 ] = lastSelector;
//             ds
//                 .selectorToFacetAndPosition[lastSelector]
//                 .functionSelectorPosition = uint16(selectorPosition);
//         }
//         ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
//         delete ds.selectorToFacetAndPosition[selector];

//         if (lastSelectorPosition == 0) {
//             uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
//             uint256 facetAddressPosition = ds
//                 .facetFunctionSelectors[_facetAddress]
//                 .facetAddressPosition;
//             if (facetAddressPosition != lastFacetAddressPosition) {
//                 address lastFacetAddress = ds.facetAddresses[
//                     lastFacetAddressPosition
//                 ];
//                 ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
//                 ds
//                     .facetFunctionSelectors[lastFacetAddress]
//                     .facetAddressPosition = uint16(facetAddressPosition);
//             }
//             ds.facetAddresses.pop();
//             delete ds
//                 .facetFunctionSelectors[_facetAddress]
//                 .facetAddressPosition;
//         }
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DiamondStorageLib {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 functionSelectorPosition;
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint16 facetAddressPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        address[] facetAddresses;
        mapping(bytes4 => bool) supportedInterfaces;
        address contractOwner;
        mapping(uint256 => mapping(string => address)) chainDexAddresses; // chainId => (dexName => dexAddress)
        mapping(uint256 => mapping(string => address)) chainBridgeAddresses; // chainId => (bridgeName => bridgeAddress)
        address lendingPool; // Store lendingPool address
    }

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function enforceIsContractOwner() internal view {
        require(
            msg.sender == diamondStorage().contractOwner,
            "Must be contract owner"
        );
    }

    function setContractOwner(address _newOwner) internal {
        diamondStorage().contractOwner = _newOwner;
    }

    function setDexAddress(
        uint256 chainId,
        string memory dexName,
        address dexAddress
    ) internal {
        diamondStorage().chainDexAddresses[chainId][dexName] = dexAddress;
    }

    function setBridgeAddress(
        uint256 chainId,
        string memory bridgeName,
        address bridgeAddress
    ) internal {
        diamondStorage().chainBridgeAddresses[chainId][
            bridgeName
        ] = bridgeAddress;
    }

    function setLendingPool(address _lendingPool) internal {
        diamondStorage().lendingPool = _lendingPool;
    }

    function getDexAddress(
        uint256 chainId,
        string memory dexName
    ) internal view returns (address) {
        return diamondStorage().chainDexAddresses[chainId][dexName];
    }

    function getBridgeAddress(
        uint256 chainId,
        string memory bridgeName
    ) internal view returns (address) {
        return diamondStorage().chainBridgeAddresses[chainId][bridgeName];
    }

    function getLendingPool() internal view returns (address) {
        return diamondStorage().lendingPool;
    }
}
