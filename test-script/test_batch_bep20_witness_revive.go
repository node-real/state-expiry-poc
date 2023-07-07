package main

import (
	"bufio"
	"context"
	"crypto/ecdsa"
	"fmt"
	"github.com/bnb-chain/bsc-deploy/test-script/utils"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"log"
	"math/big"
	"os"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("pls input transfer log file path")
		os.Exit(1)
	}

	client, err := ethclient.Dial("http://localhost:8504")
	utils.Fatal(err)

	accs := readAccounts(os.Args[1])
	if len(accs) == 0 {
		fmt.Println("cannot find any accounts")
		os.Exit(1)
	}
	fmt.Printf("find need revive addr count: %v\n", len(accs))

	contracts := utils.ReadDeployedContracts("../test-contract/deployed_contracts.json")
	contract, ok := contracts["ABCToken"]
	if !ok {
		log.Fatal("cannot find ABCToken contract address")
	}
	senderPrvKey := utils.ParsePrivateKey("190e410a96c56dcc7cbe6ee04ce68fbcf2eb7d86c441e840235373078cf6bb0c")
	//receiverAddr := common.HexToAddress("0x169eD8eD04D45b572dbCF7354f680D7557253345")

	bep20 := utils.LoadAbi("abi/ABCToken.json")
	gasPrice, err := client.SuggestGasPrice(context.Background())
	utils.Fatal(err)
	chainID, err := client.NetworkID(context.Background())
	utils.Fatal(err)

	for _, receiver := range accs {
		receiverAddr := common.HexToAddress(receiver)
		txHash := reviveTransfer(client, contract, bep20, senderPrvKey, receiverAddr, gasPrice, chainID)
		if txHash == (common.Hash{}) {
			continue
		}

		// max wait 10s
		tries := 0
		for tries < 10 {
			ctx, _ := context.WithTimeout(context.Background(), 3*time.Second)
			_, pending, err := client.TransactionByHash(ctx, txHash)
			if err != nil {
				fmt.Println("TransactionByHash err", err)
				break
			}
			if !pending {
				break
			}
			time.Sleep(time.Second * 1)
			tries++
		}
	}
}

func reviveTransfer(client *ethclient.Client, contract common.Address, bep20 abi.ABI, senderPrvKey *ecdsa.PrivateKey, receiverAddr common.Address, gasPrice *big.Int, chainID *big.Int) common.Hash {
	senderAddr := crypto.PubkeyToAddress(senderPrvKey.PublicKey)
	num, _ := new(big.Int).SetString("1000000000000000000", 10)
	input, err := bep20.Pack("transfer", receiverAddr, num)
	utils.Fatal(err)
	fmt.Printf("prepare, sender: %v, contract: %v, receiver: %v\n", senderAddr, contract, receiverAddr)
	// EstimateGasAndReviveState
	msg := ethereum.CallMsg{
		From: senderAddr,
		To:   &contract,
		Gas:  0,
		Data: input,
	}

	ctx, _ := context.WithTimeout(context.Background(), 3*time.Second)
	ret, err := client.EstimateGasAndReviveState(ctx, msg)
	utils.Fatal(err)
	if len(ret.ReviveWitness) == 0 {
		fmt.Printf("no witness, return\n")
		return common.Hash{}
	}
	fmt.Printf("EstimateGasAndReviveState, witness: %v, gas: %v\n", len(ret.ReviveWitness), uint64(ret.Hex))
	utils.PrintWitness(ret.ReviveWitness)

	nonce, err := client.PendingNonceAt(context.Background(), senderAddr)
	utils.Fatal(err)

	// SendTransaction
	tx := types.NewTx(&types.ReviveStateTx{
		Nonce:       nonce,
		GasPrice:    gasPrice,
		Gas:         uint64(ret.Hex),
		To:          msg.To,
		Data:        msg.Data,
		WitnessList: ret.ReviveWitness,
	})
	signedTx, err := types.SignTx(tx, types.NewBEP215Signer(chainID), senderPrvKey)
	if err != nil {
		utils.Fatal(err)
	}

	ctx, _ = context.WithTimeout(context.Background(), 3*time.Second)
	err = client.SendTransaction(ctx, signedTx)
	utils.Fatal(err)
	txHash := signedTx.Hash()
	fmt.Printf("send revive tx, hash: %v, witness: %v, gas: %v\n", txHash, len(ret.ReviveWitness), uint64(ret.Hex))

	return txHash
}

func readAccounts(path string) []string {
	f, err := os.Open(path)
	utils.Fatal(err)

	accs := make([]string, 0)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		items := strings.Split(scanner.Text(), " ")
		// only handle newAccount line
		if !strings.EqualFold("newAccount", items[0]) {
			continue
		}
		if !scanner.Scan() {
			break
		}
		next := strings.Split(scanner.Text(), " ")
		// only handle txHash line
		if !strings.EqualFold("txHash", next[0]) {
			continue
		}
		accs = append(accs, items[1])
	}

	if err := scanner.Err(); err != nil {
		utils.Fatal(err)
	}
	return accs
}
