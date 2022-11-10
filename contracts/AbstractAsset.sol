// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Hub.sol";


abstract contract AbstractAsset {
    Hub public hub;

    constructor(address hubAddress) {
        require(hubAddress != address(0));
        hub = Hub(hubAddress);
    }

    function getAssertions(uint256 UAI) virtual internal view returns (bytes32 [] memory);

    function getCommitHash(uint256 UAI, uint256 offset) external view returns (bytes32 commitHash) {
        bytes32 [] memory assertions = getAssertions(UAI);
        require(assertions.length > offset, "Offset is invalid");

        return assertions[assertions.length - 1 - offset];
    }
}