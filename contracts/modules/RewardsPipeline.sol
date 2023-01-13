// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDAOReactorFactory} from "../interfaces/IDAOReactorFactory.sol";
import {IDAOReactor} from "../interfaces/IDAOReactor.sol";
import {IStreamSystem} from "../interfaces/IStreamSystem.sol";

import {Constant} from "../libraries/Constant.sol";

contract Rewards is AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    struct RewardsBalance {
        uint256 unpaid;
        uint256 paid;
    }

    bytes32 public constant REWARDS_ADMIN = keccak256("REWARDS_ADMIN");

    IDAOReactorFactory public daoReactorFactory;
    IStreamSystem public streamSystem;

    uint256 public lastRewardTimestamp;

    mapping(address => RewardsBalance) public rewardsBalance;

    event RewardsPaid(address indexed stream, uint256 rewardsPaid, uint256 rewardsPaidInTotal);
    event DAOReactorFactory(IDAOReactorFactory daoReactorFactory);
    event StreamSystem(IStreamSystem streamSystem);

    modifier runIfNeeded() {
        if (block.timestamp > lastRewardTimestamp) {
            lastRewardTimestamp = block.timestamp;
            _;
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(
        address _admin,
        IStreamSystem _streamSystem,
        IDAOReactorFactory _daoReactorFactory
    ) external initializer {
        __AccessControlEnumerable_init();

        _setRoleAdmin(REWARDS_ADMIN, REWARDS_ADMIN);
        _grantRole(REWARDS_ADMIN, _admin);

        streamSystem = _streamSystem;
        emit StreamSystem(_streamSystem);

        daoReactorFactory = _daoReactorFactory;
        emit DAOReactorFactory(_daoReactorFactory);
    }

    /// @dev Returns shares of SRep for all daoReactors. To get the shares of SRep
    ///      for given daoReactor do:
    ///      `daoReactorTotalSRep[i] / totalSRep`, where `i` is index of daoReactor address in `allActiveDAOReactors`
    ///      array.
    /// @param _targetDAOReactor optional parameter, you can safely use `address(0)`. If you are looking
    ///        for specific daoReactor, provide its address as param and `targetIndex` will return index
    ///        of daoReactor in question in `allActiveDAOReactors` array.
    /// @return allActiveDAOReactors array of all daoReactors
    /// @return daoReactorTotalSRep total SRep for each daoReactor in `allActiveDAOReactors` array
    /// @return totalSRep
    /// @return targetIndex index of `_targetDAOReactor` in `allActiveDAOReactors` array
    function getDAOReactorShares(address _targetDAOReactor)
        public
        view
        returns (
            address[] memory allActiveDAOReactors,
            uint256[] memory daoReactorTotalSRep,
            uint256 totalSRep,
            uint256 targetIndex
        )
    {
        address[] memory daoReactors = daoReactorFactory.getAllDAOReactors();
        uint256 len = daoReactors.length;

        allActiveDAOReactors = new address[](len);
        daoReactorTotalSRep = new uint256[](len);

        for (uint256 i = 0; i < allActiveDAOReactors.length; i++) {
            allActiveDAOReactors[i] = daoReactors[i];

            daoReactorTotalSRep[i] = IDAOReactor(allActiveDAOReactors[i]).totalSRepToken();
            totalSRep += daoReactorTotalSRep[i];

            if (allActiveDAOReactors[i] == _targetDAOReactor) {
                targetIndex = i;
            }
        }
    }

    function getPendingRewards(address _daoReactor) public view returns (uint256) {
        uint256 pendingRewards = streamSystem.getPendingRewards(address(this));

        (
            address[] memory allActiveDAOReactors,
            uint256[] memory daoReactorTotalSRep,
            uint256 totalSRep,
            uint256 targetIndex
        ) = getDAOReactorShares(_daoReactor);

        uint256 unpaidRewards = rewardsBalance[allActiveDAOReactors[targetIndex]].unpaid;
        return unpaidRewards + (pendingRewards * daoReactorTotalSRep[targetIndex]) / totalSRep;
    }

    function distributeRewards() public runIfNeeded {
        uint256 distributedRewards = streamSystem.requestRewards();

        (
            address[] memory allActiveDAOReactors,
            uint256[] memory daoReactorTotalSRep,
            uint256 totalSRep,

        ) = getDAOReactorShares(address(0));

        for (uint256 i = 0; i < daoReactorTotalSRep.length; i++) {
            rewardsBalance[allActiveDAOReactors[i]].unpaid += (distributedRewards * daoReactorTotalSRep[i]) / totalSRep;
        }
    }

    function requestRewards() public returns (uint256 rewardsPaid) {
        distributeRewards();

        address daoReactor = msg.sender;

        rewardsPaid = rewardsBalance[daoReactor].unpaid;

        if (rewardsPaid == 0) {
            return 0;
        }

        rewardsBalance[daoReactor].unpaid = 0;
        rewardsBalance[daoReactor].paid += rewardsPaid;

        daoReactorFactory.essence().safeTransfer(daoReactor, rewardsPaid);
        emit RewardsPaid(daoReactor, rewardsPaid, rewardsBalance[daoReactor].paid);
    }

    // ADMIN
    function setDAOReactorFactory(IDAOReactorFactory _daoReactorFactory) external onlyRole(REWARDS_ADMIN) {
        daoReactorFactory = _daoReactorFactory;
        emit DAOReactorFactory(_daoReactorFactory);
    }

    function setStreamSystem(IStreamSystem _streamSystem) external onlyRole(REWARDS_ADMIN) {
        streamSystem = _streamSystem;
        emit StreamSystem(_streamSystem);
    }
}
