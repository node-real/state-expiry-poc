package utils

import "github.com/ethereum/go-ethereum/log"

func Fatal(err error, msg ...string) {
	if err != nil {
		log.Error("got fatal", msg)
		panic(err)
	}
}
