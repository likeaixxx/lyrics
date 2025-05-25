package app_utils

import (
	"bytes"
	"compress/gzip"
	"io"
)

var decodeKey = []byte{64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105}
var flagKey = []byte("krc1")

func decryptKugouKrc(data []byte) (string, error) {
	if !bytes.HasPrefix(data, flagKey) {
		return "", nil
	}

	decrypted := make([]byte, len(data)-len(flagKey))
	for i, b := range data[len(flagKey):] {
		decrypted[i] = b ^ decodeKey[i&0b1111]
	}

	reader := bytes.NewReader(decrypted)
	gzipReader, err := gzip.NewReader(reader)
	if err != nil {
		return "", err // handle gzip reader creation failure
	}
	defer func(gzipReader *gzip.Reader) {
		_ = gzipReader.Close()
	}(gzipReader)

	unarchivedData, err := io.ReadAll(gzipReader)
	if err != nil {
		return "", err
	}
	return string(unarchivedData), nil
}
