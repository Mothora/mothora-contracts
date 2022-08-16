import hre from 'hardhat';
import { expect } from 'chai';
const { ethers, deployments, getNamedAccounts } = hre;
const { deploy } = deployments;

describe.only('MockInteractions', async () => {
  let player: any;
  let gameitems: any;
  let essenceAbsorber: any;
  let token: any;
  let staker1: any,
    staker2: any,
    staker3: any,
    hacker: any,
    deployer: any,
    tester5: any,
    tester6: any,
    tester7: any,
    tester8: any,
    tester9: any;
  let staker1Signer: any,
    staker2Signer: any,
    staker3Signer: any,
    hackerSigner: any,
    deployerSigner: any,
    tester5Signer: any,
    tester6Signer: any,
    tester7Signer: any,
    tester8Signer: any,
    tester9Signer: any;

  before(async () => {
    const namedAccounts = await getNamedAccounts();
    staker1 = namedAccounts.staker1;
    staker2 = namedAccounts.staker2;
    staker3 = namedAccounts.staker3;
    hacker = namedAccounts.hacker;
    deployer = namedAccounts.deployer;
    tester5 = namedAccounts.tester5;
    tester6 = namedAccounts.tester6;
    tester7 = namedAccounts.tester7;
    tester8 = namedAccounts.tester8;
    tester9 = namedAccounts.tester9;

    staker1Signer = await ethers.provider.getSigner(staker1);
    staker2Signer = await ethers.provider.getSigner(staker2);
    staker3Signer = await ethers.provider.getSigner(staker3);
    hackerSigner = await ethers.provider.getSigner(hacker);
    deployerSigner = await ethers.provider.getSigner(deployer);
    tester5Signer = await ethers.provider.getSigner(tester5);
    tester6Signer = await ethers.provider.getSigner(tester6);
    tester7Signer = await ethers.provider.getSigner(tester7);
    tester8Signer = await ethers.provider.getSigner(tester8);
    tester9Signer = await ethers.provider.getSigner(tester9);

    await deployments.fixture(['MockPlayer'], { fallbackToGlobal: true });
    await deployments.fixture(['GameItems'], { fallbackToGlobal: true });
    await deployments.fixture(['Essence'], { fallbackToGlobal: true });
    await deployments.fixture(['EssenceAbsorber'], { fallbackToGlobal: true });

    const MockPlayer = await deployments.get('MockPlayer');
    player = new ethers.Contract(MockPlayer.address, MockPlayer.abi, deployerSigner);

    console.log({ 'Player contract deployed to': player.address });

    const GameItems = await deployments.get('GameItems');
    gameitems = new ethers.Contract(GameItems.address, GameItems.abi, deployerSigner);

    console.log({ 'GameItems contract deployed to': gameitems.address });
    await player.setGameItems(gameitems.address);

    // Deploy Essence Contract
    const Essence = await deployments.get('Essence');
    token = new ethers.Contract(Essence.address, Essence.abi, deployerSigner);

    console.log({ 'Essence contract deployed to': token.address });

    const EssenceAbsorber = await deployments.get('EssenceAbsorber');
    console.log(EssenceAbsorber.address);
    essenceAbsorber = new ethers.Contract(EssenceAbsorber.address, EssenceAbsorber.abi, deployerSigner);
    console.log({ 'EssenceAbsorber contract deployed to': essenceAbsorber.address });
  });

  describe('Player joins a faction, defects, mints Character, goes on a quest and claims its rewards', async () => {
    it('It reverts if the player selects and invalid faction', async () => {
      await expect(player.connect(deployerSigner).joinFaction(4)).to.be.revertedWith('Please select a valid faction.');
    });

    it('Player joins the Vahnu.', async () => {
      await player.connect(deployerSigner).joinFaction(1);
      expect(await player.connect(deployerSigner).getFaction(deployer)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(1);
    });

    it('It reverts if the player already has a faction', async () => {
      await expect(player.connect(deployerSigner).joinFaction(2)).to.be.revertedWith(
        'This player already has a faction.'
      );
    });

    it('Player defects to the Conglomerate', async () => {
      await player.connect(deployerSigner).defect(2);
      expect(await player.connect(deployerSigner).getFaction(deployer)).to.be.equal(2);
      expect(await player.totalFactionMembers(2)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(0);
    });

    it('It reverts if player has no faction', async () => {
      await expect(player.connect(staker1Signer).mintCharacter()).to.be.revertedWith('This Player has no faction yet.');
    });

    it('Player mints a character', async () => {
      await player.connect(deployerSigner).mintCharacter();
      expect(await gameitems.balanceOf(deployer, 2)).to.be.equal(1);
    });

    it('It reverts if tries to mint twice.', async () => {
      await expect(player.connect(deployerSigner).mintCharacter()).to.be.revertedWith(
        'The Player can only mint 1 Character of each type.'
      );
    });

    it('It reverts if player tries to mint directly on GameItems Contract.', async () => {
      await expect(gameitems.connect(deployerSigner).mintCharacter(deployer, 2)).to.be.reverted;
    });

    it('It reverts if player does not have a character of its faction.', async () => {
      await expect(player.connect(staker1Signer).goOnQuest()).to.be.revertedWith(
        'The Player does not own a character of this faction.'
      );
    });

    it('Player goes on a Quest', async () => {
      await player.connect(deployerSigner).goOnQuest();
    });

    it('It reverts if player is already on a quest', async () => {
      await expect(player.connect(deployerSigner).goOnQuest()).to.be.revertedWith('The Player is already on a quest.');
    });

    it('It if lock time has passed but Player has not claimed its rewards', async () => {
      await ethers.provider.send('evm_increaseTime', [601]); // add 601 seconds
      await expect(player.connect(deployerSigner).goOnQuest()).to.be.revertedWith(
        'The Player has not claimed its rewards.'
      );
    });

    it('It reverts if Player tries to claim rewards without doing the quest', async () => {
      const requestId = 1;
      await expect(player.connect(staker1Signer).mockClaimQuestRewards(requestId)).to.be.revertedWith(
        'The Player has to go on a quest first to claim its rewards.'
      );
    });

    it('It reverts if Player tries to claim rewards while doing the quest', async () => {
      await player.connect(staker1Signer).joinFaction(3);
      await player.connect(staker1Signer).mintCharacter();
      await player.connect(staker1Signer).goOnQuest();
      const requestId = 1;

      await expect(player.connect(staker1Signer).mockClaimQuestRewards(requestId)).to.be.revertedWith(
        'The Player is still on a quest.'
      );
    });

    it('The Player Claims the rewards', async () => {
      const requestId = 1;
      const randomWords = [300];

      await player.connect(deployerSigner).mockClaimQuestRewards(requestId);
      await player.connect(deployerSigner).MockRandomnessFulfilment(requestId, randomWords);

      expect(await gameitems.balanceOf(deployer, 0)).to.be.least(0);
    });
  });

  describe('Player tries interact directly with GameItems.sol but is successfully blocked.', async () => {
    it('It reverts on minting a character or vaultpart', async () => {
      await expect(gameitems.connect(deployerSigner).mintCharacter(deployer, 0)).to.be.revertedWith(
        'Not player contract address.'
      );
      await expect(gameitems.connect(deployerSigner).mintVaultParts(deployer, 0)).to.be.revertedWith(
        'Not player contract address.'
      );
    });

    it('It reverts on setting a token  if not the owner', async () => {
      await expect(gameitems.connect(staker1Signer).setTokenUri(0, '')).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
    });

    it('It reverts on re-setting a token uri by the owner', async () => {
      await expect(gameitems.connect(deployerSigner).setTokenUri(0, '')).to.be.revertedWith('Cannot set uri twice.');
    });
  });

  describe('Pulling Funds', async () => {
    it('It reverts pulling funds if not the owner', async () => {
      await expect(gameitems.connect(deployerSigner).setTokenUri(0, '')).to.be.revertedWith('Cannot set uri twice.');
    });

    it('Owner wallet sends tokens to Mothora Vault', async () => {
      await token.connect(deployerSigner).approve(deployer, ethers.constants.MaxUint256);
      await token.transferFrom(deployer, essenceAbsorber.address, 1000);
      expect(await token.balanceOf(essenceAbsorber.address)).to.be.equal(1000);
    });
  });

  describe('Player stake/unstakes tokens', async () => {
    it('It reverts if amount staked is <0', async () => {
      await expect(essenceAbsorber.connect(staker2Signer).stakeTokens(0)).to.be.revertedWith(
        'Amount must be more than 0.'
      );
      await expect(essenceAbsorber.connect(staker2Signer).stakeTokens(-1)).to.be.reverted;
    });

    it('It reverts if player tries to stake without having Essence Tokens', async () => {
      await token.connect(staker2Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await expect(essenceAbsorber.connect(staker2Signer).stakeTokens(1000)).to.be.revertedWith(
        'ERC20: transfer amount exceeds balance'
      );
    });

    it('Player buys Essence Tokens (simulation) and stakes them successfully', async () => {
      await token.transferFrom(deployer, staker2, 1000);
      expect(await token.connect(staker2Signer).balanceOf(staker2)).to.be.equal(1000);
      expect(await essenceAbsorber.connect(staker2Signer).playerIds(staker2)).to.be.equal(0);
      await essenceAbsorber.connect(staker2Signer).stakeTokens(1000);
      expect(await essenceAbsorber.connect(staker2Signer).stakedESSBalance(staker2)).to.be.equal(1000);
      expect(await essenceAbsorber.connect(staker2Signer).playerIds(staker2)).to.be.equal(1);
      expect(await token.connect(staker2Signer).balanceOf(staker2)).to.be.equal(0);
    });

    it('It reverts if amount staked is <=0', async () => {
      await expect(essenceAbsorber.connect(staker2Signer).unstakeTokens(0)).to.be.revertedWith(
        'Amount must be more than 0.'
      );
      await expect(essenceAbsorber.connect(staker2Signer).unstakeTokens(-1)).to.be.reverted;
    });

    it('It reverts if player tries to unstake without having Essence tokens staked', async () => {
      await expect(essenceAbsorber.connect(staker1Signer).unstakeTokens(1000)).to.be.revertedWith(
        'Staking balance cannot be 0'
      );
    });

    it('It reverts if player chooses an amount higher than its staked balance', async () => {
      await expect(essenceAbsorber.connect(staker2Signer).unstakeTokens(10000)).to.be.revertedWith(
        'Cannot unstake more than your staked balance'
      );
    });

    it('Player successfully unstakes', async () => {
      await essenceAbsorber.connect(staker2Signer).unstakeTokens(1000);
      expect(await essenceAbsorber.stakedESSBalance(staker2)).to.be.equal(0);
    });
  });

  describe('Contribute Vault Parts', async () => {
    it('It reverts if amount <0', async () => {
      await expect(essenceAbsorber.connect(deployerSigner).contributeVaultParts(0)).to.be.revertedWith(
        'Amount must be more than 0'
      );
      await expect(essenceAbsorber.connect(deployerSigner).contributeVaultParts(-1)).to.be.reverted;
    });

    it('It reverts if the amount is higher than players VP Balance', async () => {
      expect(await gameitems.connect(deployerSigner).balanceOf(deployer, 0)).to.be.least(0);
      await expect(essenceAbsorber.connect(deployerSigner).contributeVaultParts(6)).to.be.revertedWith(
        'The Player does not have enough Vault Parts'
      );
    });

    it('It successfully contributes essenceAbsorber parts', async () => {
      await gameitems.connect(deployerSigner).setApprovalForAll(essenceAbsorber.address, true);
      await essenceAbsorber.connect(deployerSigner).contributeVaultParts(1);
      expect(await essenceAbsorber.connect(deployerSigner).playerStakedPartsBalance(deployer)).to.be.equal(1);
      expect(await essenceAbsorber.connect(deployerSigner).factionPartsBalance(2)).to.be.equal(1);
    });
  });

  describe('Vault distributes the rewards', async () => {
    it('It reverts if there are no staked tokens', async () => {
      await expect(essenceAbsorber.connect(deployerSigner).distributeRewards()).to.be.revertedWith(
        'There are no tokens staked'
      );
    });

    it('It distributes the epoch rewards according to excel example and players claim', async () => {
      // Setting up the player quests and essenceAbsorber parts contribution
      await player.connect(tester5Signer).joinFaction(1);
      await player.connect(tester5Signer).mintCharacter();
      await player.connect(tester5Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester5Signer).mockClaimQuestRewards(2);
      await player.connect(tester5Signer).MockRandomnessFulfilment(2, [550]);

      await player.connect(tester5Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester5Signer).mockClaimQuestRewards(3);
      await player.connect(tester5Signer).MockRandomnessFulfilment(3, [222]);
      await player.connect(tester5Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester5Signer).mockClaimQuestRewards(4);
      await player.connect(tester5Signer).MockRandomnessFulfilment(4, [20]);
      await player.connect(tester5Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester5Signer).mockClaimQuestRewards(5);
      await player.connect(tester5Signer).MockRandomnessFulfilment(5, [632]);
      await player.connect(tester5Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester5Signer).mockClaimQuestRewards(6);
      await player.connect(tester5Signer).MockRandomnessFulfilment(6, [132]);
      await gameitems.connect(tester5Signer).setApprovalForAll(essenceAbsorber.address, true);
      await essenceAbsorber.connect(tester5Signer).contributeVaultParts(await gameitems.balanceOf(tester5, 0));

      await player.connect(tester7Signer).joinFaction(2);
      await player.connect(tester7Signer).mintCharacter();
      await player.connect(tester7Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester7Signer).mockClaimQuestRewards(7);
      await player.connect(tester7Signer).MockRandomnessFulfilment(7, [1]);
      await player.connect(tester7Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester7Signer).mockClaimQuestRewards(8);
      await player.connect(tester7Signer).MockRandomnessFulfilment(8, [444]);
      await gameitems.connect(tester7Signer).setApprovalForAll(essenceAbsorber.address, true);
      await essenceAbsorber.connect(tester7Signer).contributeVaultParts(await gameitems.balanceOf(tester7, 0));

      await player.connect(tester8Signer).joinFaction(2);
      await player.connect(tester8Signer).mintCharacter();
      await player.connect(tester8Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester8Signer).mockClaimQuestRewards(9);
      await player.connect(tester8Signer).MockRandomnessFulfilment(9, [121]);
      await player.connect(tester8Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester8Signer).mockClaimQuestRewards(10);
      await player.connect(tester8Signer).MockRandomnessFulfilment(10, [55]);
      await gameitems.connect(tester8Signer).setApprovalForAll(essenceAbsorber.address, true);
      await essenceAbsorber.connect(tester8Signer).contributeVaultParts(await gameitems.balanceOf(tester8, 0));

      await player.connect(tester9Signer).joinFaction(2);
      await player.connect(tester9Signer).mintCharacter();
      await player.connect(tester9Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester9Signer).mockClaimQuestRewards(11);
      await player.connect(tester8Signer).MockRandomnessFulfilment(11, [876]);
      await player.connect(tester9Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester9Signer).mockClaimQuestRewards(12);
      await player.connect(tester9Signer).MockRandomnessFulfilment(12, [422]);
      await player.connect(tester9Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester9Signer).mockClaimQuestRewards(13);
      await player.connect(tester9Signer).MockRandomnessFulfilment(13, [999]);
      await player.connect(tester9Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester9Signer).mockClaimQuestRewards(14);
      await player.connect(tester9Signer).MockRandomnessFulfilment(14, [135]);
      await player.connect(tester9Signer).goOnQuest();
      await ethers.provider.send('evm_increaseTime', [61]);
      await player.connect(tester9Signer).mockClaimQuestRewards(15);
      await player.connect(tester9Signer).MockRandomnessFulfilment(15, [753]);
      await gameitems.connect(tester9Signer).setApprovalForAll(essenceAbsorber.address, true);
      await essenceAbsorber.connect(tester9Signer).contributeVaultParts(await gameitems.balanceOf(tester9, 0));

      // Staking and distributing

      await token.transferFrom(deployer, tester6, ethers.BigNumber.from('10000000000000000000000'));
      await token.connect(tester6Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await essenceAbsorber.connect(tester6Signer).stakeTokens(ethers.BigNumber.from('10000000000000000000000'));

      await ethers.provider.send('evm_increaseTime', [60 * 35]);

      await token.transferFrom(deployer, tester9, ethers.BigNumber.from('10000000000000000000000'));
      await token.connect(tester9Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await essenceAbsorber.connect(tester9Signer).stakeTokens(ethers.BigNumber.from('10000000000000000000000'));

      await ethers.provider.send('evm_increaseTime', [61 * 14]);

      await token.transferFrom(deployer, tester5, ethers.BigNumber.from('1000000000000000000000'));
      await token.connect(tester5Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await essenceAbsorber.connect(tester5Signer).stakeTokens(ethers.BigNumber.from('1000000000000000000000'));

      await ethers.provider.send('evm_increaseTime', [61 * 11]);

      await token.transferFrom(deployer, tester7, ethers.BigNumber.from('50000000000000000000'));
      await token.connect(tester7Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await essenceAbsorber.connect(tester7Signer).stakeTokens(ethers.BigNumber.from('50000000000000000000'));

      await token.transferFrom(deployer, tester8, ethers.BigNumber.from('50000000000000000000'));
      await token.connect(tester8Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
      await essenceAbsorber.connect(tester8Signer).stakeTokens(ethers.BigNumber.from('50000000000000000000'));

      await essenceAbsorber.connect(deployerSigner).distributeRewards();

      // Claiming the rewards
      await essenceAbsorber.connect(tester5Signer).claimEpochRewards(false);
      await essenceAbsorber.connect(tester6Signer).claimEpochRewards(false);
      await essenceAbsorber.connect(tester7Signer).claimEpochRewards(false);
      await essenceAbsorber.connect(tester8Signer).claimEpochRewards(false);
      await essenceAbsorber.connect(tester9Signer).claimEpochRewards(false);
    });

    it('It reverts if the Owner tries to distribute more than once in the same epoch', async () => {
      await expect(essenceAbsorber.connect(deployerSigner).distributeRewards()).to.be.revertedWith(
        'The player has already claimed in this epoch'
      );
    });

    it('Owner distributes rewards again on the next epoch', async () => {
      await ethers.provider.send('evm_increaseTime', [601]); // add 601 seconds
      await essenceAbsorber.connect(deployerSigner).distributeRewards();
    });
  });
});
