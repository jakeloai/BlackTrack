#!/bin/bash
# install.sh - Complete setup script for blackfuzz (bf)
set -e

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing required tools and Go environment..."
sudo apt-get install -y gcc make git wget golang-go

echo "[*] Cloning Radamsa repository..."
if [ -d "radamsa" ]; then
    rm -rf radamsa
fi
git clone https://gitlab.com/akihe/radamsa.git

echo "[*] Compiling and installing Radamsa..."
cd radamsa
make
sudo make install
cd ..
rm -rf radamsa

echo "[*] Verifying Radamsa installation..."
if ! command -v radamsa &> /dev/null; then
    echo "[-] Radamsa installation failed."
    exit 1
fi
echo "HAL 9000" | radamsa

echo "[*] Creating main.go source file..."
cat << 'EOF' > main.go
package main

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

var (
	baselineLen int
	mutex       sync.Mutex
	workerCount = 5
)

func usage() {
	fmt.Fprintf(os.Stderr, "blackfuzz (bf) - Anomaly-based Fuzzing Engine\n\n")
	fmt.Fprintf(os.Stderr, "Usage: bf [OPTIONS] <raw_request_file>\n\n")
	fmt.Fprintf(os.Stderr, "Options:\n")
	flag.PrintDefaults()
	fmt.Fprintf(os.Stderr, "\nExample:\n")
	fmt.Fprintf(os.Stderr, "  bf -u http://target.com/api -n 200 -o output_dir request.txt\n")
}

func main() {
	flag.Usage = usage
	url := flag.String("u", "", "Target URL (Required)")
	n := flag.Int("n", 100, "Number of fuzz requests")
	out := flag.String("o", "fuzz_output", "Output directory")
	flag.Parse()

	reqFile := flag.Arg(0)
	if *url == "" || reqFile == "" {
		usage()
		os.Exit(1)
	}

	runID := time.Now().Format("20060102_150405")
	baseDir := filepath.Join(*out, runID)
	anomalyDir := filepath.Join(baseDir, "anomalies")
	err := os.MkdirAll(anomalyDir, 0755)
	if err != nil {
		fmt.Printf("[-] Failed to create output directories: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("[*] blackfuzz engine started\n")
	fmt.Printf("[*] Target: %s\n", *url)
	fmt.Printf("[*] Output directory: %s\n\n", baseDir)

	jobs := make(chan int, *n)
	var wg sync.WaitGroup

	for w := 1; w <= workerCount; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				fuzz(i, *url, reqFile, baseDir, anomalyDir)
			}
		}()
	}

	for i := 0; i < *n; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	
	fmt.Println("\n[+] Fuzzing completed.")
}

func fuzz(id int, url, reqFile, baseDir, anomalyDir string) {
	cmd := exec.Command("radamsa", reqFile)
	fuzzed, err := cmd.Output()
	if err != nil {
		return
	}

	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest("POST", url, bytes.NewReader(fuzzed))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/octet-stream")

	resp, err := client.Do(req)

	if err != nil || (resp != nil && (resp.StatusCode == 403 || resp.StatusCode == 429)) {
		fmt.Print("\a") 
		fmt.Println("\n[!] WARNING: IP Blocked or Connection Error Detected!")
		fmt.Print("[*] Please change your VPN/IP manually. Press Enter to resume...")
		bufio.NewReader(os.Stdin).ReadString('\n')
		fmt.Println("[+] IP switch confirmed. Resuming operations...")
		return 
	}

	if resp == nil {
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	mutex.Lock()
	if baselineLen == 0 {
		baselineLen = len(body)
	} else {
		diff := math.Abs(float64(len(body) - baselineLen))
		if diff > 200 {
			anomalyPath := filepath.Join(anomalyDir, fmt.Sprintf("anomaly_%d.txt", id))
			os.WriteFile(anomalyPath, body, 0644)
			fmt.Printf("[!] Anomaly Found! ID: %d, Diff: %.0f bytes (Status: %d)\n", id, diff, resp.StatusCode)
		}
	}
	mutex.Unlock()

	resPath := filepath.Join(baseDir, fmt.Sprintf("res_%d.txt", id))
	os.WriteFile(resPath, body, 0644)
}
EOF

echo "[*] Initialize Go module..."
if [ ! -f "go.mod" ]; then
    go mod init blackfuzz
fi

echo "[*] Compiling blackfuzz binary..."
go build -o bf main.go

echo "[*] Moving binary to /usr/local/bin/bf..."
sudo mv bf /usr/local/bin/bf

echo "[*] Cleaning up temporary source files..."
rm -f main.go go.mod

echo "[+] Installation successful! You can now use 'bf' globally."
