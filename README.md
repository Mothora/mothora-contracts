## Mothora MVP Contracts

The contracts are organized from a main HUB registry contract (`MothoraGame.sol`), which also controls game account creation and DAO attribution.

Connected to the HUB are the following core modules:

- `EssenceToken.sol` - ERC20 Essence token (non transfereable)
- `Arena.sol` - Manages postmatch results and their verification

## Get started

0. Set `PRIVATE_KEY`env variabvle

1. Install submodules

```
git submodules update
```

2. Install dependencies

```
yarn
```

3. Build with Foundry

```
yarn build
```

4. Test contracts via Foundry

```
yarn test
```

## License

MIT
