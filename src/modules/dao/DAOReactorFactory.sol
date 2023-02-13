// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDAOReactor} from "../../interfaces/IDAOReactor.sol";
import {IDAOReactorFactory} from "../../interfaces/IDAOReactorFactory.sol";
import {IRewardsPipeline} from "../../interfaces/IRewardsPipeline.sol";

contract DAOReactorFactory is IDAOReactorFactory, Initializable, AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev master admin, manages other roles and can change core config
    bytes32 public constant DRF_ADMIN = keccak256("DRF_ADMIN");
    /// @dev can deploy and enable/disable daoReactors
    bytes32 public constant DRF_DEPLOYER = keccak256("DRF_DEPLOYER");
    /// @dev can upgrade proxy implementation for daoReactor and nftHandler
    bytes32 public constant DRF_BEACON_ADMIN = keccak256("DRF_BEACON_ADMIN");

    /// @dev Reward token addr
    IERC20 public rewardToken;
    /// @dev Essence token addr
    IERC20 public essence;
    IRewardsPipeline public rewardsPipeline;

    UpgradeableBeacon public daoReactorBeacon;

    EnumerableSet.AddressSet private daoReactors;
    mapping(address => bool) public deployedDAOReactors;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        IERC20 _rewardToken,
        IERC20 _essence,
        IRewardsPipeline _rewardsPipeline,
        address _daoReactorImpl
    ) external initializer {
        __AccessControlEnumerable_init();

        essence = _essence;
        emit EssenceModuleUpdated(_essence);

        rewardToken = _rewardToken;
        emit RewardTokenUpdated(_rewardToken);

        rewardsPipeline = _rewardsPipeline;
        emit RewardsPipelineModuleUpdated(_rewardsPipeline);

        _setRoleAdmin(DRF_ADMIN, DRF_ADMIN);
        _grantRole(DRF_ADMIN, _admin);

        _setRoleAdmin(DRF_DEPLOYER, DRF_ADMIN);
        _grantRole(DRF_DEPLOYER, _admin);

        _setRoleAdmin(DRF_BEACON_ADMIN, DRF_ADMIN);
        _grantRole(DRF_BEACON_ADMIN, _admin);

        daoReactorBeacon = new UpgradeableBeacon(_daoReactorImpl);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DRF_ADMIN) {}

    /*///////////////////////////////////////////////////////////////
                    Get DAO reactors logic
    //////////////////////////////////////////////////////////////*/

    function getDAOReactor(uint256 _index) external view override returns (address) {
        if (daoReactors.length() == 0) {
            return address(0);
        } else {
            return daoReactors.at(_index);
        }
    }

    function getAllDAOReactors() external view override returns (address[] memory) {
        return daoReactors.values();
    }

    function getAllDAOReactorsLength() external view override returns (uint256) {
        return daoReactors.length();
    }

    /*///////////////////////////////////////////////////////////////
                    Deploying DAO reactors logic
    //////////////////////////////////////////////////////////////*/
    function deployDAOReactor(address _admin) external override onlyRole(DRF_DEPLOYER) {
        bytes memory daoReactorData = abi.encodeCall(IDAOReactor.initialize, (_admin));
        address daoReactor = address(new BeaconProxy(address(daoReactorBeacon), daoReactorData));

        if (!daoReactors.add(daoReactor)) revert DAOReactorExists();
        deployedDAOReactors[daoReactor] = true;

        emit DAOReactorDeployed(daoReactor);
    }

    function enableDAOReactor(IDAOReactor _daoReactor) external override onlyRole(DRF_DEPLOYER) {
        _daoReactor.callUpdateRewards();

        // only DAOReactors deployed by this factory can be enabled and re-added to the list
        if (!deployedDAOReactors[address(_daoReactor)]) revert NotDAOReactor();

        _daoReactor.enable();
        daoReactors.add(address(_daoReactor));
    }

    function disableDAOReactor(IDAOReactor _daoReactor) external override onlyRole(DRF_DEPLOYER) {
        _daoReactor.callUpdateRewards();

        // only active daoReactor in the list can be disabled
        if (!daoReactors.remove(address(_daoReactor))) revert NotDAOReactor();

        _daoReactor.disable();
    }

    /*///////////////////////////////////////////////////////////////
                    Admin logic
    //////////////////////////////////////////////////////////////*/

    function setEssenceModule(IERC20 _essence) external override onlyRole(DRF_ADMIN) {
        essence = _essence;
        emit EssenceModuleUpdated(_essence);
    }

    function setRewardToken(IERC20 _rewardToken) external override onlyRole(DRF_ADMIN) {
        rewardToken = _rewardToken;
        emit RewardTokenUpdated(_rewardToken);
    }

    function setRewardsModule(IRewardsPipeline _rewardsPipeline) external override onlyRole(DRF_ADMIN) {
        rewardsPipeline = _rewardsPipeline;
        emit RewardsPipelineModuleUpdated(_rewardsPipeline);
    }

    /// @dev Upgrades the daoReactor beacon to a new implementation.
    function upgradeDAOReactorTo(address _newImplementation) external override onlyRole(DRF_BEACON_ADMIN) {
        daoReactorBeacon.upgradeTo(_newImplementation);
    }
}
