// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Hub } from "./Hub.sol";
import { Shares } from "./Shares.sol";
import { ShardingTable } from "./ShardingTable.sol";
import { ShardingTableStorage } from "./storage/ShardingTableStorage.sol";
import { IdentityStorage } from "./storage/IdentityStorage.sol";
import { ParametersStorage } from "./storage/ParametersStorage.sol";
import { ServiceAgreementStorage } from "./storage/ServiceAgreementStorage.sol";
import { ProfileStorage } from "./storage/ProfileStorage.sol";
import { StakingStorage } from "./storage/StakingStorage.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {

    event StakeIncreased(
        uint72 indexed identityId,
        address indexed staker,
        uint96 newStakeAmount
    );
    event StakeWithdrawn(
        uint72 indexed identityId,
        address indexed staker,
        uint96 withdrawnStakeAmount
    );
    event RewardAdded(
        uint72 indexed identityId,
        address indexed staker,
        uint96 rewardAmount
    );

    Hub public hub;
    IdentityStorage public identityStorage;
    ParametersStorage public parametersStorage;
    ProfileStorage public profileStorage;
    StakingStorage public stakingStorage;
    IERC20 public tokenContract;
    ShardingTable public shardingTable;
    ShardingTableStorage public shardingTableStorage;
    ServiceAgreementStorage public serviceAgreementStorage;

    constructor(address hubAddress) {
        require(hubAddress != address(0));
        hub = Hub(hubAddress);

        identityStorage = IdentityStorage(hub.getContractAddress("IdentityStorage"));
        parametersStorage = ParametersStorage(hub.getContractAddress("ParametersStorage"));
        profileStorage = ProfileStorage(hub.getContractAddress("ProfileStorage"));
        stakingStorage = StakingStorage(hub.getContractAddress("StakingStorage"));
        tokenContract = IERC20(hub.getContractAddress("Token"));
        shardingTable = ShardingTable(hub.getContractAddress("ShardingTable"));
        shardingTableStorage = ShardingTableStorage(hub.getContractAddress("ShardingTableStorage"));
        serviceAgreementStorage = ServiceAgreementStorage(hub.getContractAddress("ServiceAgreementStorage"));
    }

    modifier onlyContracts(){
        _checkHub();
        _;
    }

    function addStake(uint72 identityId, uint96 tracAdded) external {
        StakingStorage ss = stakingStorage;
        ParametersStorage ps = parametersStorage;
        ShardingTable st = shardingTable;
        ShardingTableStorage sts = shardingTableStorage;

        require(
            tokenContract.allowance(msg.sender, address(this)) >= tracAdded,
            "Account does not have sufficient allowance"
        );
        require(tracAdded + ss.totalStakes(identityId) <= ps.maximumStake(), "Exceeded the maximum stake!");
        require(
            ps.delegationEnabled() || identityStorage.identityExists(identityId),
            "No identity/delegation disabled"
        );

        address sharesContractAddress = profileStorage.getSharesContractAddress(identityId);
        Shares sharesContract = Shares(sharesContractAddress);

        uint256 sharesMinted;
        if(sharesContract.totalSupply() == 0) {
            sharesMinted = uint256(tracAdded);
        } else {
            sharesMinted = (
                uint256(tracAdded) * sharesContract.totalSupply() / uint256(ss.totalStakes(identityId))
            );
        }
        sharesContract.mint(msg.sender, sharesMinted);

        tokenContract.transfer(address(ss), tracAdded);

        ss.setTotalStake(identityId, ss.totalStakes(identityId) + tracAdded);

        if (!sts.nodeExists(identityId) && ss.totalStakes(identityId) >= parametersStorage.minimumStake()) {
            st.pushBack(identityId);
        }

        emit StakeIncreased(identityId, msg.sender, tracAdded);
    }

    function withdrawStake(uint72 identityId, uint96 sharesBurned) external {
        address sharesContractAddress = profileStorage.getSharesContractAddress(identityId);
        Shares sharesContract = Shares(sharesContractAddress);

        require(sharesBurned < uint96(sharesContract.totalSupply()), "Not enough shares available");
        require(identityStorage.identityExists(identityId), "Identity doesn't exist");

        StakingStorage ss = stakingStorage;
        ShardingTable st = shardingTable;
        ShardingTableStorage sts = shardingTableStorage;

        uint256 tracWithdrawn = (
            uint256(sharesBurned) * uint256(ss.totalStakes(identityId)) / sharesContract.totalSupply()
        );
        sharesContract.burnFrom(msg.sender, sharesBurned);

        // TODO: when slashing starts, introduce delay

        tokenContract.transfer(msg.sender, tracWithdrawn);

        ss.setTotalStake(identityId, ss.totalStakes(identityId) - uint96(tracWithdrawn));

        if (sts.nodeExists(identityId) && ss.totalStakes(identityId) < parametersStorage.minimumStake()) {
            st.removeNode(identityId);
        }

        emit StakeWithdrawn(identityId, msg.sender, uint96(tracWithdrawn));
    }

    function addReward(uint72 identityId, address operational, uint96 tracAmount) external onlyContracts {
        require(tracAmount != 0, "No reward available");

        uint96 operatorFee = stakingStorage.operatorFees(identityId) * tracAmount / 100;
        uint96 reward = tracAmount - operatorFee;
        ServiceAgreementStorage sas = serviceAgreementStorage;
        StakingStorage ss = stakingStorage;

        if(reward > 0) {
            sas.transferReward(address(ss), reward);
        }

        if(operatorFee > 0) {
            sas.transferReward(operational, operatorFee);
        }

        ss.setTotalStake(identityId, ss.totalStakes(identityId) + reward);

        if (
            !shardingTableStorage.nodeExists(identityId) &&
            ss.totalStakes(identityId) >= parametersStorage.minimumStake()
        ) {
            shardingTable.pushBack(identityId);
        }

        emit RewardAdded(identityId, operational, tracAmount);
    }

    function slash(uint72 identityId) external onlyContracts {
        // TBD
    }

    function _checkHub() internal view virtual {
        require(hub.isContract(msg.sender), "Fn can only be called by the hub");
    }

}
