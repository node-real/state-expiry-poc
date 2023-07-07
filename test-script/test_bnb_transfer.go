// This file is used to test BNB transfer between two validator nodes.
// It will keep sending BNB from the first validator node to the second validator node.
// until it is interrupted.

package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"github.com/bnb-chain/bsc-deploy/test-script/utils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/params"
	"math/big"
	"time"
)

var edpoint = "http://localhost:8502"
var chainId = big.NewInt(714)

func sendEther(client *ethclient.Client, key *ecdsa.PrivateKey, toAddr common.Address, value *big.Int, nonce uint64) (common.Hash, error) {
	gasLimit := uint64(3e4)
	gasPrice := big.NewInt(params.GWei * 10000)

	tx := types.NewTransaction(nonce, toAddr, value, gasLimit, gasPrice, nil)
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainId), key)
	if err != nil {
		return common.Hash{}, fmt.Errorf("sign tx failed, %v", err)
	}
	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		return common.Hash{}, fmt.Errorf("send tx failed, %v", err)
	}
	txhash := signedTx.Hash()
	return txhash, nil
}

func main() {
	senderPrvKey := utils.ParsePrivateKey("190e410a96c56dcc7cbe6ee04ce68fbcf2eb7d86c441e840235373078cf6bb0c")
	senderAddr := crypto.PubkeyToAddress(senderPrvKey.PublicKey)

	receiverAddr := common.HexToAddress("0x169eD8eD04D45b572dbCF7354f680D7557253345")
	c, _ := ethclient.Dial(edpoint)
	t := time.NewTicker(1000 * time.Millisecond)
	for {
		select {
		case <-t.C:
			nonce, err := c.PendingNonceAt(context.Background(), senderAddr)
			if err != nil {
				fmt.Println(err)
				continue
			}
			hash, err := sendEther(c, senderPrvKey, receiverAddr, big.NewInt(params.GWei*1), nonce)
			if err != nil {
				fmt.Println(err)
				continue
			}
			fmt.Printf("send tx hash %s \n", hash)
		}
	}
}
