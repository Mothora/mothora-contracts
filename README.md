## Why are we building this?

Current P2E games are unsustainable in their current model, as they rely on a continuous upkeep of new players to sustain the value of rewards provided in-game. Not only that, but it quickly became apparent that grinding and repeating the same similar actions in hopes of receiving dwindling rewards is extremely non-appealing and the total opposite of fun. “Players” in the P2E arena became reward mercenaries instead of playing for the joy of the game. And it can be quickly agreed that this first breed of P2E games are visually underwhelming and the social component between players is disregarded, leading to low levels of immersion.

Our understanding is also that current P2E game development is almost entirely focused on the “earning money” aspect, how not to over-inflate the economy of the game and keep making it worthwhile as an investment. We do understand the argument that there is a new segment of “players” who view these games purely as financial products and income potential and that it is possible to cater to them with a fine tuned economic model. However, we believe it is not possible to overcome the economic sustainability problem without first making these games appeal to people that actually want to play them for entertainment purposes and not purely as a way to get money.

**This is why Mothora was created**: _because of the shared belief that immersive and fun AAA quality games are absent in the web3 landscape and that most gamers are missing out on rewards due to non-sustainability and entry barriers_. And this demo reflects exactly the begining of that: an immersive and enticing landscape where a few GameFi interactions can be visualized, **using Polygon as the chain of choice due to its reliability, speediness and great ecosystem of existing games, as well as support for Chainlink functions such as verifiable randomness**.

<br>

## What is Mothora?

**Mothora** is a _web3 game of persistent large-scale incentivised 3-way Faction (iFvFvF) battles in Unreal Engine 5_. In the traditional gaming sense it can be regarded as an Online Role-Playing Game (RPG) with strong Player vs Player (PvP) emphasis and a real player-owned economy. It is set in a dystopian sci-fi future, in the aftermath of civilisational decay, where three factions struggle for survival.

The game intends to push the boundaries of Play to Earn and shift the emphasis to the Play aspect, the so-called Play & Earn. The focus is on creating an actual game that players enjoy for the sake of it. In Mothora, three factions compete for map dominance, enabling a plethora of tactical grand strategy decisions and micro duelling scenarios. These factions are themselves subDAOs that can both enact governance proposals for the overall Mothora DAO, as well as proposals that can influence how the faction manages itself. With this system, intense and compelling experiences can be enabled, as players coordinate within and outside the game.

<br>

## Intended Playstyle

The world of Mothora is governed by the $ESSENCE, a natural occurrence that players of different factions must compete for to get the ultimate rewards.

The end goal of a game’s season is for each of the three Factions to make their $ESSENCE Absorber staking system the most efficient. In each play season, the factions compete for a finite amount of rewards allotted to each, with a variety of strategies and social coordination being required for players in each faction to make the most out of those rewards. By selectively incentivising these actions, it is possible to boost the social component of the game, the degree of interdependence of players, and the sense of belonging to a real evolving community.

In a nutshell, in Mothora players will succeed by:

- Thinking ahead and coordinating
- Cooperating with battle companions and guild members
- Understanding well the intricacies of the combat mechanics
- Being knowledgeable in the core economic elements

Players will then be able to spend $ESSENCE in a variety of in-game actions and services, from which a portion is burned and the rest taken as revenue and distributed back to the Mothora DAO and each of the faction subDAOs. A summary idea for such system is presented below (only a small portion implemented in the demo):

![$ESSENCE Flows](https://mirror.xyz/_next/image?url=https%3A%2F%2Fimages.mirror-media.xyz%2Fpublication-images%2F6Z64CXvoPh8gmvwXUHmRm.png&w=1920&q=90)

<br>

## What is part of this Demo

1. **Polygon Mumbai Testnet** - We elected Polygon as our network of choice for this hackathon due to its speedy transactions and available integration with Chainlink VRF.

2. **Smart contracts**

- MothoraGame.sol: Acts as the main contract with account definition and a registry of all the other contracts. Allows players to enter a faction and defect to other factions
- modules/Arena.sol: Manages the start of a battle between players and its termination, rewarding users with a random number of Artifact NFTs that can be used to increase the eficiency of the Faction $ESSENCE Absorber
- modules/Artifacts.sol: Manages the mint of new artifacts as they are given out in rewards or potentially through crafting (not implemented). Contains a hardcoded base16 CID link for the Artifacts metadata, generated with Pinata IPFS utility (https://www.pinata.cloud/). Check `/helpers`folder to browse the functions used.
- modules/Cosmetics.sol: Manages the mint of new cosmetic skins, such as character skins. Currently only one demonstration skin exists per faction. Contains a hardcoded base16 CID link for the Faction Skins metadata, generated with Pinata IPFS utility (https://www.pinata.cloud/). Check `/helpers`folder to browse the functions used.
- modules/Essence.sol: The main currency in the game. For demonstration purposes it is minted in its entirety to the deployer address and airdropped to players.
- modules/EssenceAbsorber: Users can stake both $ESSENCE and Artifacts in their absorbing system. Ultimately this is what the competition is about, to increase the Absorber efficiency for their own faction. Users can also unstake, calculate and claim rewards. The reward distribution system is push-based, performed by an admin function. We admit this to be a flaw of the system that would be upgraded into a pull-based mechanism where each user "distributes" to himself/herself the rewards.

3. **Chainlink Implementation** The game requires access to true randomness to be fair when distributing the Artifacts NFTs. The contracts in Polygon Mumbai are requesting random numbers from Chainlink.

4. **Unreal Engine environment** - Built the 3D world where the player makes its in-game actions

5. **Unreal Engine multiplayer** - Allows for multiple characters on the same server in real-time

6. **Unreal Engine <-> Web 3 Integration** - Customized the connection between the Smart contracts and the Unreal Engine Environment that allows the player to trigger blockchain transactions from within the game window and sign them using walletconnect.

7. **Pinata.cloud typescript Wrappers** - Used to pin the NFTs metadata onto IPFS and give back a base16 CID link to display the metadata.

<br>

## Smart Contract addresses and important transactions

- **Creation of subscription id 1498**: https://mumbai.polygonscan.com/tx/0x10958f581bd7387f6c7bde613b196239953beae701d1aa0dd5ea7b359873707f
- **MothoraGame.sol_Implementation**: https://mumbai.polygonscan.com/address/0xe7b371386191555b77bc6C9e4AAa325D5e1214fb
- **MothoraGame.sol_Proxy**: https://mumbai.polygonscan.com/address/0xD0a4316a9e1E197b41Cf6530A1bbAd30A6cCc6B7
- **Arena.sol**: https://mumbai.polygonscan.com/address/0x6529F395DcaB1930B3a0561f61526a01Eebb189b
- **Artifacts.sol**: https://mumbai.polygonscan.com/address/0xc48CDc6711aa068A90CcEBf5274E45255c37052A
- **Cosmetics.sol**: https://mumbai.polygonscan.com/address/0x20d7e5D10B16b3fcA8Ea2EE93bb704C8B5894Ad5
- **Essence.sol**: https://mumbai.polygonscan.com/address/0x4D3C09A1BbC80724ca412A2bc13f751E475dB245
- **EssenceAbsorber.sol**: https://mumbai.polygonscan.com/address/0x7F8b7F2c46D23AE6654f855821c22B2f74a94309

### Average test coverage - All files

| Stmts % | Branch % | Funcs % | Lines % |
| ------- | -------- | ------- | ------- |
| 82.44   | 75.41    | 76      | 82.14   |

<br>

## Challenges we ran into

The main challenge was to devise a proper pull-based staking system in time for the $ESSENCE (although we have one in research, based on other existing implementations). The current push-based reward distribution system rans into scalability issues with the transaction gas consumption and we are aware of this limitation.
The second biggest challenge was to complete a compelling enough visual map environment to show in the demo showcase. We were until the last minute doing changes and making the style better!

<br>

## Accomplishments that we're proud of

We are proud of having created a demo in Unreal Engine 5 of a PvP faction game that shows how we can link rewards, NFTs and such, all in a speedy and reliable chain such as Polygon.

<br>

## What we learned

We deepened our Unreal Engine 5 skills, particularly how to script the interactions with the demo’ smart contracts. We are definitely going to take this knowledge further and keep on building in our demo to transform it into a MVP.

<br>

## What's next for Mothora

It is our goal to build the full-fledged Mothora game.

From a roadmap perspective, there are two main areas we intend to focus in the project:

1. Build a tight knit community around Mothora. We want everyone to understand the values of the game and the choices they can make to further its development. For this purpose, we are soon releasing challenges related to our world to facilitate the creation of a relationship between players and the game. These challenges include the completion of enigmas, following our socials and helping the project by sharing the word.

2. Work on the MVP of an Arena Battle mode - A closed map where the three factions face off on a short time window battle. This task will put strong emphasis on 3D Asset Creation and enhancing the set of smart contracts used in the PoC to display more features and interactions.
