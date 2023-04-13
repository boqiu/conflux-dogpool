// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or 
 * any kind of contract that will be deployed behind a proxy.
 */
contract Initializable {

    bool public initialized;

    modifier onlyInitializeOnce() {
        require(!initialized, "Initializable: initialized already");
        _;
        initialized = true;
    }

    modifier onlyInitialized() {
        require(initialized, "Initializable: uninitialized");
        _;
    }

}
