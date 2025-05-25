package app_utils

import "github.com/liuzl/gocc"

// T2s 繁转简
func T2s(string2 string) (string, error) {
	t2s, err := gocc.New("t2s")
	if err != nil {
		return "", err
	}
	return t2s.Convert(string2)
}
