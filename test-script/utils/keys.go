package utils

import (
	"bufio"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/keystore"
)

func GetKeyStorePath(path string) (string, error) {
	var fullFilePath string
	err := filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			fullFilePath = path
			return filepath.SkipDir
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	return fullFilePath, nil
}

func ReadDeployedContracts(path string) map[string]common.Address {
	content, err := ioutil.ReadFile(path)
	Fatal(err)
	var contracts map[string]common.Address
	err = json.Unmarshal(content, &contracts)
	Fatal(err)
	return contracts
}

func ReadPrivateKey(path string) *ecdsa.PrivateKey {
	keyStorePath, err := GetKeyStorePath(path)
	Fatal(err)
	return GetPrivateKey(keyStorePath)
}

func GetPrivateKey(privateKeyPath string) *ecdsa.PrivateKey {
	password := "password"
	keyjson, e := ioutil.ReadFile(privateKeyPath)
	Fatal(e)
	key, _ := keystore.DecryptKey(keyjson, password)
	return key.PrivateKey
}

func ParsePrivateKey(key string) *ecdsa.PrivateKey {
	prvKey, err := crypto.HexToECDSA(key)
	Fatal(err)
	return prvKey
}

func GetPublicKey(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "Public address of the key:") {
			publicKey := strings.TrimSpace(strings.TrimPrefix(line, "Public address of the key:"))
			return publicKey, nil
		}
	}

	if err := scanner.Err(); err != nil {
		return "", err
	}

	return "", fmt.Errorf("public key not found in file")
}

type ExtAcc struct {
	Key  *ecdsa.PrivateKey
	Addr common.Address
}

func FromHexKey(hexkey string) (ExtAcc, error) {
	key, err := crypto.HexToECDSA(hexkey)
	if err != nil {
		return ExtAcc{}, err
	}
	pubKey := key.Public()
	pubKeyECDSA, ok := pubKey.(*ecdsa.PublicKey)
	if !ok {
		err = errors.New("publicKey is not of type *ecdsa.PublicKey")
		return ExtAcc{}, err
	}
	addr := crypto.PubkeyToAddress(*pubKeyECDSA)
	return ExtAcc{key, addr}, nil
}
