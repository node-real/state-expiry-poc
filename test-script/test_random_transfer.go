package main

import (
	"context"
	"fmt"
	"github.com/bnb-chain/bsc-deploy/test-script/utils"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"log"
	"math/big"
	"time"
)

var randomNum = 3_000

func main() {
	contracts := utils.ReadDeployedContracts("../test-contract/deployed_contracts.json")
	contract, ok := contracts["ABCToken"]
	if !ok {
		log.Fatal("cannot find ABCToken contract address")
	}
	senderPrvKey := utils.ParsePrivateKey("190e410a96c56dcc7cbe6ee04ce68fbcf2eb7d86c441e840235373078cf6bb0c")
	senderAddr := crypto.PubkeyToAddress(senderPrvKey.PublicKey)

	bep20 := utils.LoadAbi("abi/ABCToken.json")

	client, err := ethclient.Dial("http://localhost:8503")
	utils.Fatal(err)
	defer client.Close()

	gasPrice, err := client.SuggestGasPrice(context.Background())
	utils.Fatal(err)
	chainID, err := client.NetworkID(context.Background())
	utils.Fatal(err)
	nonce, err := client.PendingNonceAt(context.Background(), senderAddr)
	utils.Fatal(err)

	for i := 0; i < randomNum; i++ {
		prvKey, err := crypto.GenerateKey()
		if err != nil {
			fmt.Println("got err when GenerateKey", err)
			continue
		}
		receiverAddr := crypto.PubkeyToAddress(prvKey.PublicKey)
		fmt.Printf("newAccount %v prvKey %v\n", receiverAddr, prvKey.D.String())

		num, _ := new(big.Int).SetString("1000000000000000000", 10)
		input, err := bep20.Pack("transfer", receiverAddr, num)
		if err != nil {
			fmt.Println("got err when Pack", err)
			continue
		}

		// SendTransaction
		tx := types.NewTx(&types.LegacyTx{
			Nonce:    nonce,
			GasPrice: gasPrice,
			Gas:      uint64(200000),
			To:       &contract,
			Data:     input,
		})
		signedTx, err := types.SignTx(tx, types.NewBEP215Signer(chainID), senderPrvKey)
		if err != nil {
			fmt.Println("got err when SignTx", err)
			continue
		}

		ctx, _ := context.WithTimeout(context.Background(), 3*time.Second)
		err = client.SendTransaction(ctx, signedTx)
		if err != nil {
			fmt.Println("got err when SendTransaction", err)
			continue
		}
		fmt.Printf("txHash %v\n", signedTx.Hash())
		nonce++
		//time.Sleep(10 * time.Millisecond)
		time.Sleep(60 * time.Millisecond)
	}
}
