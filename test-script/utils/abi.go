package utils

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"os"
)

func LoadAbi(path string) abi.ABI {
	abiFile, err := os.Open(path)
	Fatal(err)
	a, err := abi.JSON(abiFile)
	Fatal(err)
	return a
}
