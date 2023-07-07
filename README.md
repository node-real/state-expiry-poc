## State Expiry Proof-of-Concept

State Expiry is a mechanism to remove expired data from the blockchain temporarily. Expired data can no longer be accessed temporarily, unless it is revived through an operation called "state revive". By implementing State Expiry, we are able to tackle the state bloat problem, reducing the storage requirements to run a node over the long run.

This repository contains the setup guide to test the State Expiry Proof-of-Concept (PoC) implemented by the NodeReal development team. The POC is based on [BEP-206](https://github.com/setunapo/BEPs/blob/bep205_state_expiry/BEP206.md) and [BEP-215](https://github.com/bnb-chain/BEPs/pull/215).

## ⚙️ Installation

### Prerequisites

- Golang 1.19 or higher
- nodeJS 18 or higher

### Environment Setup

1. For the first time, run:

```
git submodule update --init --recursive
```

2. Clone BSC state-expiry-dev repo

```
git clone https://github.com/node-real/bsc --branch state_expiry_develop bsc-state-expiry
```

3. Compile `geth` and `bootnode`, then copy to `bin` folder

```
cd bsc-state-expiry
make geth
go build -o bootnode ./cmd/bootnode
cp build/bin/geth ../bsc-deploy-state-expiry/bin
cp bootnode ../bsc-deploy-state-expiry/bin
```

## 🤖 Testing Flow

The complete flow of testing the state expiry features may look something like:

1. Deploy nodes
2. Deploy token contract
3. Read token balance
4. Wait for contract state to be expired
5. Read token balance again (expired error is returned)
6. Send revive transaction to revive contract state
7. Read token balance
8. Stop nodes

When a contract is deployed, you should wait for 2 epochs (100 blocks) so that its state is expired. Here's the table reference:

| Epoch | Block Number (Decimal) | Block Number (Hex) |
| ----- | ---------------------- | ------------------ |
| 0     | 0                      | 0x0                |
| 1     | 50                     | 0x32               |
| 2     | 100                    | 0x64               |
| 3     | 150                    | 0x96               |

## 💻 Commands

### Deploy 3 archive nodes

```
# Deploying 3 archive nodes
# modifies the genesis such that the first account of scripts/asset/test_account.json is the initBnbHolder
bash scripts/clusterup_set_first.sh start
```

### Deploy 2 full node + 1 archive node

```
bash scripts/clusterup_pruning_test.sh start
```

### Stop cluster nodes

```
bash scripts/clusterup_set_first.sh stop
```

### Test BNB transfer

```
cd test-script
# The script keeps sending transactions until ctrl-c
go run test_bnb_transfer.go
```

### Deploy BEP20 Token Contract

```
cd bsc-deploy-state-expiry
cd test-contract/deploy-BEP20/
# install dependencies
npm install
# deploy BEP20 Token
npx hardhat run scripts/deploy.js
```

### Transfer BEP20 Token & Read Balance

```
cd test-contract/deploy-BEP20/
# This will transfer BEP20 Token from scripts/asset/test_account.json first account
# This script only transfer once
npx hardhat run scripts/transfer.js
# read sender & receiver's balance
npx hardhat run scripts/read-balance.js
```

### Useful RPC Commands

```
# query block height
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}' 127.0.0.1:8502

# query block by number
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x3", true],"id":83}' 127.0.0.1:8502

# query tx by hash
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0x12beecfb1adb7d874c4714a7871e23cf70baef612235d1276568611460927f18"],"id":83}' 127.0.0.1:8502

# query tx receipt
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x782192568c8ee3393e3f3e9b7ac46e231d3cbe0b96941b642e28220ba343209b"],"id":83}' 127.0.0.1:8502
```
