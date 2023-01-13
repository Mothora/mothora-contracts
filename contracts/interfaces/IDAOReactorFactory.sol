// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IRewardsPipeline.sol";
import "./IDAOReactor.sol";

interface IDAOReactorFactory {
    /******************
    /  EVENTS
    /******************/

    /**
     * @dev Emitted when a new DAOReactor is deployed
     * @param daoReactor The address of the deployed DAOReactor
     */
    event DAOReactorDeployed(address daoReactor);

    /**
     * @dev Emitted when the essence module is updated
     * @param essence The address of the new essence module
     */
    event EssenceModuleUpdated(IERC20 essence);

    /**
     * @dev Emitted when the rewards module is updated
     * @param rewardsPipeline The address of the new rewards module
     */
    event RewardsPipelineModuleUpdated(IRewardsPipeline rewardsPipeline);

    /******************
    /  ERRORS
    /******************/

    /**
     * @dev Error when the DAO reactor already exists
     */
    error DAOReactorExists();

    /**
     * @dev Error when the DAO reactor hasn't been deployed yet
     */
    error NotDAOReactor();

    /******************
    /  FUNCTIONS
    /******************/

    /**
     * @dev Returns essence ierc20 token
     */
    function essence() external view returns (IERC20);

    /**
     * @dev Returns rewards pipeline contract
     */
    function rewardsPipeline() external view returns (IRewardsPipeline);

    /**
     * @dev Returns the DAO reactor at the given index
     * @param _index The index of the DAO reactor
     */
    function getDAOReactor(uint256 _index) external view returns (address);

    /**
     * @dev Returns all DAO reactors
     */
    function getAllDAOReactors() external view returns (address[] memory);

    /**
     * @dev Returns the number of  DAO reactors
     */
    function getAllDAOReactorsLength() external view returns (uint256);

    /**
     * @dev Deploys a DAO reactor
     */
    function deployDAOReactor(address _admin) external;

    /**
     * @dev Enables a DAO reactor. Must be called after deploy DAO reactor to enable staking functionality
     * @param _daoReactor The DAO reactor to enable
     */
    function enableDAOReactor(IDAOReactor _daoReactor) external;

    /**
     * @dev Disables a DAO reactor
     * @param _daoReactor The DAO reactor to disable
     */
    function disableDAOReactor(IDAOReactor _daoReactor) external;

    /**
     * @dev Sets the essence module
     * @param _essence The address of the essence module
     */
    function setEssenceModule(IERC20 _essence) external;

    /**
     * @dev Sets the rewards module
     * @param _rewardsPipeline The address of the rewards module
     */
    function setRewardsModule(IRewardsPipeline _rewardsPipeline) external;

    /**
     * @dev Upgrades the DAO reactor implementation
     * @param _newImplementation The address of the new implementation
     */
    function upgradeDAOReactorTo(address _newImplementation) external;
}
