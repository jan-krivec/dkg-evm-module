// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC734 } from "../interface/ERC734.sol";
import { HashingProxy } from "../HashingProxy.sol";
import { Hub } from "../Hub.sol";
import { Identity } from "../Identity.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ProfileStorage {
    event AskUpdated(uint96 indexed identityId, address indexed identityContractAddress, bytes indexed nodeId, uint96 ask);
    event StakeUpdated(uint96 indexed identityId, address indexed identityContractAddress, bytes indexed nodeId, uint96 stake);
    event RewardUpdated(uint96 indexed identityId, address indexed identityContractAddress, bytes indexed nodeId, uint96 reward);

    Hub public hub;

    struct ProfileDefinition{
        uint96 ask;
        uint96 stake;
        uint96 reward;
        uint96 stakeWithdrawalAmount;
        uint96 rewardWithdrawalAmount;
        uint96 frozenAmount;  // TODO: Slashing mechanism
        uint256 stakeWithdrawalTimestamp;
        uint256 rewardWithdrawalTimestamp;
        uint256 freezeTimestamp;  // TODO: Slashing mechanism
        bytes nodeId;
        mapping(uint8 => bytes32) nodeAddresses;
    }

    uint96 private lastIdentityId;

    // operational/management wallet => identityId
    mapping(address => uint96) public identityIds;
    // identityId => identity contract address
    mapping(uint96 => address) public identityContractAddresses;
    // nodeId => isRegistered?
    mapping(bytes => bool) public nodeIdsList;
    // identityId => Profile
    mapping(uint96 => ProfileDefinition) public profiles;

    constructor(address hubAddress) {
        require(hubAddress != address(0));
        hub = Hub(hubAddress);

        lastIdentityId = 1;
    }

    modifier onlyContracts(){
        require(hub.isContract(msg.sender),
        "Function can only be called by contracts!");
        _;
    }

    function createProfile(
        address operationalWallet,
        address managementWallet,
        bytes nodeId,
        uint96 initialAsk,
        uint96 initialStake
    )
        public
        OnlyContracts
        returns (uint96, address)
    {
        require(!identityIds[operationalWallet], "Profile already exists");
        require(!nodeIdsList[nodeId], "Node ID connected with another profile");
        require(nodeId.length != 0, "Node ID can't be empty");
        require(initialAsk > 0, "Ask can't be 0");

        Identity identity = new Identity(operationalWallet, managementWallet);
        address identityContractAddress = address(identity);

        ProfileDefinition memory profile = ProfileDefinition({
            ask: initialAsk,
            stake: initialStake,
            reward: 0,
            withdrawalAmount: 0,
            withdrawalTimestamp: 0,
            frozenAmount: 0,
            freezeTimestamp: 0,
            nodeId: nodeId
        });

        profiles[lastIdentityId] = profile;

        identityIds[operationalWallet] = lastIdentityId;
        identityContractAddresses[lastIdentityId] = identityContractAddress;
        nodeIdsList[nodeId] = true;

        lastIdentityId++;

        return (identityIds[operationalWallet], identityContractAddress);
    }

    /* ----------------GETTERS------------------ */
    function getIdentityId()
        public
        view
        returns (uint96)
    {
        return identityIds[msg.sender];
    }

    function getIdentityContractAddress()
        public
        view
        returns (address)
    {
        return identityContractAddresses[identityIds[msg.sender]];
    }

    function getAsk(uint96 identityId)
        public
        view
        returns (uint96)
    {
        return profiles[identityId].ask;
    }

    function getStake(uint96 identityId) 
        public
        view
        returns (uint96)
    {
        return profiles[identityId].stake;
    }

    function getReward(uint96 identityId)
        public
        view
        returns (uint96)
    {
        return profiles[identityId].reward;
    }

    function getStakeWithdrawalAmount(uint96 identityId) 
        public
        view
        returns (uint96)
    {
        return profiles[identityId].stakeWithdrawalAmount;
    }

    function getRewardWithdrawalAmount(uint96 identityId)
        public
        view
        returns (uint96)
    {
        return profiles[identityId].rewardWithdrawalAmount;
    }

    function getFrozenAmount(uint96 identityId) 
        public
        view
        returns (uint96)
    {
        return profiles[identityId].frozenAmount;
    }

    function getStakeWithdrawalTimestamp(uint96 identityId) 
        public
        view
        returns (uint256)
    {
        return profiles[identityId].stakeWithdrawalTimestamp;
    }

    function getRewardWithdrawalTimestamp(uint96 identityId)
        public
        view
        returns (uint256)
    {
        return profiles[identityId].rewardWithdrawalTimestamp;
    }

    function getFreezeTimestamp(uint96 identityId)
        public
        view
        returns (uint256)
    {
        return profiles[identityId].freezeTimestamp;
    }

    function getNodeId(uint96 identityId) 
        public
        view
        returns (bytes memory)
    {
        return profiles[identityId].nodeId;
    }

    function getNodeAddress(uint96 identityId, uint8 hashingAlgorithm)
        public
        view
        returns (bytes32)
    {
        return profiles[identityId].nodeAddresses[hashingAlgorithm];
    }

    /* ----------------SETTERS------------------ */
    function setAsk(uint96 identityId, uint96 ask)
        public
        onlyContracts
    {
        require(ask > 0, "Ask cannot be 0.");

        profiles[identityId].ask = ask;

        emit AskUpdated(identityId, identityContractAddresses[identityId], this.getNodeId(identityId), ask);
    }
    
    function setStake(uint96 identityId, uint96 stake)
        public
        onlyContracts
    {
        profiles[identityId].stake = stake;

        emit StakeUpdated(identityId, identityContractAddresses[identityId], this.getNodeId(identityId), stake);
    }

    function setReward(uint96 identityId, uint96 reward)
        public
        onlyContracts
    {
        profiles[identityId].reward = reward;

        emit RewardUpdated(identityId, identityContractAddresses[identityId], this.getNodeId(identityId), reward);
    }

    function setStakeWithdrawalAmount(uint96 identityId, uint96 stakeWithdrawalAmount) 
        public
        onlyContracts
    {
        profiles[identityId].stakeWithdrawalAmount = stakeWithdrawalAmount;
    }

    function setRewardWithdrawalAmount(uint96 identityId, uint96 rewardWithdrawalAmount)
        public
        onlyContracts
    {
        profiles[identityId].rewardWithdrawalAmount = rewardWithdrawalAmount;
    }

    function setFrozenAmount(uint96 identityId, uint96 frozenAmount) 
        public
        onlyContracts
    {
        profiles[identityId].frozenAmount = frozenAmount;
    }

    function setStakeWithdrawalTimestamp(uint96 identityId, uint256 stakeWithdrawalTimestamp) 
        public
        onlyContracts
    {
        profiles[identityId].stakeWithdrawalTimestamp = stakeWithdrawalTimestamp;
    }

    function setRewardWithdrawalTimestamp(uint96 identityId, uint256 rewardWithdrawalTimestamp)
        public
        onlyContracts
    {
        profiles[identityId].rewardWithdrawalTimestamp = rewardWithdrawalTimestamp;
    }

    function setFreezeTimestamp(uint96 identityId, uint256 freezeTimestamp)
        public
        onlyContracts
    {
        profiles[identityId].freezeTimestamp = freezeTimestamp;
    }

    function attachWalletToIdentity(address sender, address newWallet)
        public
        onlyContracts
    {
        require(newWallet != address(0), "Wallet address can't be empty");
        identityIds[newWallet] = identityIds[sender];
    }

    function detachWalletFromIdentity(address wallet)
        public
        onlyContracts
    {
        delete identityIds[wallet];
    }

    function setNodeId(uint96 identityId, bytes memory nodeId)
        public
        onlyContracts
    {
        require(nodeId.length != 0, "Node ID can't be empty");

        profiles[identityId].nodeId = nodeId;

        nodeIdsList[profiles[identityId].nodeId] = false;
        nodeIdsList[nodeId] = true;
    }

    function setNodeAddress(uint96 identityId, uint8 hashingAlgorithm)
        public
        onlyContract
    {
        HashingProxy hashingProxy = HashingProxy(hub.getContractAddress("HashingProxy"));
        profiles[identityId].nodeAddresses[hashingAlgorithm] = hashingProxy.callHashingFunction(
            hashingAlgorithm,
            profiles[identityId].nodeId
        );
    }

    function transferTokens(address receiver, uint96 amount)
        public
        onlyContracts
    {
        require(receiver != address(0), "Receiver address can't be empty");

        IERC20 tokenContract = IERC20(hub.getContractAddress("Token"));
        tokenContract.transfer(receiver, amount);
    }
}
