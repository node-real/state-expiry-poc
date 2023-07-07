package utils

import (
	"errors"
	"fmt"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
)

func PrintWitness(reviveWits []types.ReviveWitness) {
	for _, wit := range reviveWits {
		data, err := wit.WitnessData()
		Fatal(err)
		stWit, ok := data.(*types.StorageTrieWitness)
		if !ok {
			Fatal(errors.New("got StorageTrieWitnessType data error"))
		}
		gas := wit.Size() * params.TxWitnessListStorageGasPerByte
		addGas, _ := wit.AdditionalIntrinsicGas()
		gas += addGas
		fmt.Printf("wit addr: %v, count: %v, gas: %v\n", stWit.Address, len(stWit.ProofList), gas)
		for i, proof := range stWit.ProofList {
			ws := make([]int, 0)
			total := 0
			for _, p := range proof.Proof {
				ws = append(ws, len(p))
				total += len(p)
			}
			fmt.Printf("wit proof: %v, depth: %v, totalSize: %v, prefix: %v, size: %v\n", i, len(proof.Proof), total, len(proof.RootKeyHex), ws)
		}
	}
}
