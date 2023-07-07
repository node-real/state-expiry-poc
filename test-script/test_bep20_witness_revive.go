package main

import (
	"context"
	"fmt"
	"github.com/bnb-chain/bsc-deploy/test-script/utils"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"log"
	"math/big"
	"time"
)

func main() {
	contracts := utils.ReadDeployedContracts("../test-contract/deployed_contracts.json")
	contract, ok := contracts["ABCToken"]
	if !ok {
		log.Fatal("cannot find ABCToken contract address")
	}
	senderPrvKey := utils.ParsePrivateKey("190e410a96c56dcc7cbe6ee04ce68fbcf2eb7d86c441e840235373078cf6bb0c")
	senderAddr := crypto.PubkeyToAddress(senderPrvKey.PublicKey)
	receiverAddr := common.HexToAddress("0x169eD8eD04D45b572dbCF7354f680D7557253345")

	client, err := ethclient.Dial("http://localhost:8504")
	utils.Fatal(err)

	bep20 := utils.LoadAbi("abi/ABCToken.json")
	num, _ := new(big.Int).SetString("100000000000000000000", 10)
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
	fmt.Printf("EstimateGasAndReviveState, witness: %v, gas: %v\n", len(ret.ReviveWitness), uint64(ret.Hex))
	utils.PrintWitness(ret.ReviveWitness)

	nonce, err := client.PendingNonceAt(context.Background(), senderAddr)
	utils.Fatal(err)
	gasPrice, err := client.SuggestGasPrice(context.Background())
	utils.Fatal(err)
	chainID, err := client.NetworkID(context.Background())
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
	fmt.Printf("send revive tx, hash: %v, witness: %v, gas: %v\n", signedTx.Hash(), len(ret.ReviveWitness), uint64(ret.Hex))
}
