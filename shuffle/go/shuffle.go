package main

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"time"
)

// read file line-by-line to a list
func readFileLines(infilePath string) ([]string, error) {
	infile, err := os.Open(infilePath)
	if err != nil {
		return nil, err
	}
	defer infile.Close()

	var lines []string
	scanner := bufio.NewScanner(infile)
	for scanner.Scan() {
		var line string
		line = scanner.Text()
		lines = append(lines, line)
	}
	return lines, scanner.Err()
}

// mainline - program starts here
func main() {
	// read file named by command-line argument
	if len(os.Args) < 1 {
		panic("specifiy file path on command line")
		os.Exit(1)
	}
	filePath := os.Args[1]
	lines, err := readFileLines(filePath)

	// check for errors
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	if lines == nil {
		fmt.Println("read error")
		os.Exit(1)
	}

	// shuffle lines
	rand.Seed(time.Now().UnixNano()) // seed random number generator using nanoseconds since Unix epoch (1970)
	rand.Shuffle(len(lines), func(i, j int) { lines[i], lines[j] = lines[j], lines[i] })

	// output
	for _, line := range lines {
		fmt.Println(line)
	}
}
