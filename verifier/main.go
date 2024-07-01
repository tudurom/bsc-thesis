package main

import (
	"bytes"
	"fmt"
	"github.com/minio/sha256-simd"
	"log"
	"os"
)

// fileSize returns the size in bytes of files fn1 and fn2, assumed to be
// identical.
func fileSize(fn1 string, fn2 string) (int64, error) {
	stat1, err := os.Stat(fn1)
	if err != nil {
		return -1, err
	}

	stat2, err := os.Stat(fn2)
	if err != nil {
		return -1, err
	}

	if stat1.Size() != stat2.Size() {
		return -1, fmt.Errorf("Files do not have matching sizes!")
	}

	return stat1.Size(), nil
}

// firstHalf returns the first half of the contents of the file with filename
// fn and size fullSize. It is a destructive operation!
func firstHalf(fn string, fullSize int64) ([]byte, error) {
	if err := os.Truncate(fn, fullSize/2); err != nil {
		return nil, err
	}

	return os.ReadFile(fn)
}

// secondHalf returns the second half of the contents of the file with filename
// fn and size fullSize.
func secondHalf(fn string, fullSize int64) ([]byte, error) {
	f, err := os.Open(fn)
	if err != nil {
		return nil, err
	}

	_, err = f.Seek(fullSize/2, 0)
	if err != nil {
		return nil, err
	}

	buf := new(bytes.Buffer)
	if _, err := f.WriteTo(buf); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

// mangleHash turns the bytes of a SHA256 sum into a mangled string.
// The mangled string is obtained by taking the hex string form of the hash,
// and interlacing it with its reverse.
func mangleHash(sum [32]byte) string {
	var nibbles [64]byte
	for i, b := range sum {
		nibbles[2*i] = b >> 4
		nibbles[2*i+1] = b & 0xf
	}

	const l = len(nibbles)
	ret := ""
	for i, nb := range nibbles {
		ret += fmt.Sprintf("%x%x", nb, nibbles[l-1-i])
	}

	return ret
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s [file] [file_copy]\n", os.Args[0])
		os.Exit(1)
	}

	fn1 := os.Args[1]
	fn2 := os.Args[2]

	size, err := fileSize(fn1, fn2)
	if err != nil {
		log.Fatal(err)
	}

	half1, err := firstHalf(fn1, size)
	if err != nil {
		log.Fatal(err)
	}

	half2, err := secondHalf(fn2, size)
	if err != nil {
		log.Fatal(err)
	}

	h := sha256.New()
	if _, err := h.Write(half1); err != nil {
		log.Fatal(err)
	}
	if _, err := h.Write(half2); err != nil {
		log.Fatal(err)
	}
	sum := h.Sum(nil)
	fmt.Println(mangleHash([32]byte(sum)))
}
