// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/INftHandler.sol";
import "./interfaces/IAbsorber.sol";
import "./interfaces/IEssencePipeline.sol";

import "./rules/StakingRulesBase.sol";

/// TODO -> Understand well the Beacon architecture
contract AbsorberFactory is AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev master admin, manages other roles and can change core config
    bytes32 public constant AF_ADMIN = keccak256("AF_ADMIN");
    /// @dev can deploy and enable/disable absorbers
    bytes32 public constant AF_DEPLOYER = keccak256("AF_DEPLOYER");
    /// @dev can upgrade proxy implementation for absorber and nftHandler
    bytes32 public constant AF_BEACON_ADMIN = keccak256("AF_BEACON_ADMIN");

    UpgradeableBeacon public nftHandlerBeacon;
    UpgradeableBeacon public absorberBeacon;

    EnumerableSet.AddressSet private absorbers;
    mapping(address => bool) public deployedAbsorbers;

    /// @dev Essence token addr
    IERC20 public essence;
    IEssencePipeline public essencePipeline;

    event AbsorberDeployed(address absorber, address nftHandler);
    event Essence(IERC20 essence);
    event EssencePipeline(IEssencePipeline essencePipeline);

    error AbsorberExists();
    error NotAbsorber();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(
        IERC20 _essence,
        IEssencePipeline _essencePipeline,
        address _admin,
        address _absorberImpl,
        address _nftHandlerImpl
    ) external initializer {
        __AccessControlEnumerable_init();

        essence = _essence;
        emit Essence(_essence);

        essencePipeline = _essencePipeline;
        emit EssencePipeline(_essencePipeline);

        _setRoleAdmin(AF_ADMIN, AF_ADMIN);
        _grantRole(AF_ADMIN, _admin);

        _setRoleAdmin(AF_DEPLOYER, AF_ADMIN);
        _grantRole(AF_DEPLOYER, _admin);

        _setRoleAdmin(AF_BEACON_ADMIN, AF_ADMIN);
        _grantRole(AF_BEACON_ADMIN, _admin);

        absorberBeacon = new UpgradeableBeacon(_absorberImpl);
        nftHandlerBeacon = new UpgradeableBeacon(_nftHandlerImpl);
    }

    function getAbsorber(uint256 _index) external view returns (address) {
        if (absorbers.length() == 0) {
            return address(0);
        } else {
            return absorbers.at(_index);
        }
    }

    function getAllAbsorbers() external view returns (address[] memory) {
        return absorbers.values();
    }

    function getAllAbsorbersLength() external view returns (uint256) {
        return absorbers.length();
    }

    function deployAbsorber(
        address _admin,
        IAbsorber.CapConfig memory _depositCapPerWallet,
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        INftHandler.NftConfig[] memory _nftConfigs
    ) external onlyRole(AF_DEPLOYER) {
        address nftHandler = address(new BeaconProxy(address(nftHandlerBeacon), bytes("")));

        for (uint256 i = 0; i < _nfts.length; i++) {
            address rules = address(_nftConfigs[i].stakingRules);
            bytes32 SR_NFT_HANDLER = StakingRulesBase(rules).SR_NFT_HANDLER();

            if (!IAccessControlUpgradeable(rules).hasRole(SR_NFT_HANDLER, nftHandler)) {
                _nftConfigs[i].stakingRules.setNftHandler(nftHandler);
            }
        }

        bytes memory absorberData = abi.encodeCall(
            IAbsorber.init,
            (_admin, INftHandler(nftHandler), _depositCapPerWallet)
        );
        address absorber = address(new BeaconProxy(address(absorberBeacon), absorberData));

        if (!absorbers.add(absorber)) revert AbsorberExists();
        deployedAbsorbers[absorber] = true;

        emit AbsorberDeployed(absorber, nftHandler);

        INftHandler(nftHandler).init(_admin, absorber, _nfts, _tokenIds, _nftConfigs);
    }

    function enableAbsorber(IAbsorber _absorber) external onlyRole(AF_DEPLOYER) {
        _absorber.callUpdateRewards();

        // only Absorbers deployed by this factory can be enabled and re-added to the list
        if (!deployedAbsorbers[address(_absorber)]) revert NotAbsorber();

        _absorber.enable();
        absorbers.add(address(_absorber));
    }

    function disableAbsorber(IAbsorber _absorber) external onlyRole(AF_DEPLOYER) {
        _absorber.callUpdateRewards();

        // only active absorber in the list can be disabled
        if (!absorbers.remove(address(_absorber))) revert NotAbsorber();

        _absorber.disable();
    }

    // ADMIN

    function setEssenceToken(IERC20 _essence) external onlyRole(AF_ADMIN) {
        essence = _essence;
        emit Essence(_essence);
    }

    function setEssencePipeline(IEssencePipeline _essencePipeline) external onlyRole(AF_ADMIN) {
        essencePipeline = _essencePipeline;
        emit EssencePipeline(_essencePipeline);
    }

    /// @dev Upgrades the absorber beacon to a new implementation.
    function upgradeAbsorberTo(address _newImplementation) external onlyRole(AF_BEACON_ADMIN) {
        absorberBeacon.upgradeTo(_newImplementation);
    }

    /// @dev Upgrades the nft handler beacon to a new implementation.
    function upgradeNftHandlerTo(address _newImplementation) external onlyRole(AF_BEACON_ADMIN) {
        nftHandlerBeacon.upgradeTo(_newImplementation);
    }
}
