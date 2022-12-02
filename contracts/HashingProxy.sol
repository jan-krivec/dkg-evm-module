// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IHashFunction } from "./interface/IHashFunction.sol";
import { Named } from "./interface/Named.sol";
import { UnorderedIndexableContractDynamicSetLib } from "./utils/UnorderedIndexableContractDynamicSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract HashingProxy is Ownable {

    using UnorderedIndexableContractDynamicSetLib for UnorderedIndexableContractDynamicSetLib.Set;

    event NewHashFunctionContract(uint8 indexed hashFunctionId, address newContractAddress);
    event HashFunctionContractChanged(uint8 indexed hashFunctionId, address newContractAddress);

    UnorderedIndexableContractDynamicSetLib.Set hashFunctionSet;

    function setContractAddress(uint8 hashFunctionId, address hashingContractAddress) external onlyOwner {
        if (hashFunctionSet.exists(hashFunctionId)) {
            hashFunctionSet.update(hashFunctionId, hashingContractAddress);
            emit HashFunctionContractChanged(hashFunctionId, hashingContractAddress);
        } else {
            hashFunctionSet.append(hashFunctionId, hashingContractAddress);
            emit NewHashFunctionContract(hashFunctionId, hashingContractAddress);
        }
    }

    function removeContract(uint8 hashFunctionId) external onlyOwner {
        hashFunctionSet.remove(hashFunctionId);
    }

    function callHashFunction(uint8 hashFunctionId, bytes calldata data) external returns (bytes32) {
        return IHashFunction(hashFunctionSet.get(hashFunctionId).addr).hash(data);
    }

    function getHashFunctionName(uint8 hashFunctionId) external view returns (string memory) {
        return Named(hashFunctionSet.get(hashFunctionId).addr).name();
    }

    function getHashFunctionContractAddress(uint8 hashFunctionId) external view returns (address) {
        return hashFunctionSet.get(hashFunctionId).addr;
    }

    function getAllHashFunctions() external view returns (UnorderedIndexableContractDynamicSetLib.Contract[] memory) {
        return hashFunctionSet.getAll();
    }

    function isHashFunction(uint8 hashFunctionId) external view returns (bool) {
        return hashFunctionSet.exists(hashFunctionId);
    }

}
