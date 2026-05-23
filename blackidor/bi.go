package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

// Global matrices initialized dynamically
var idorKeywords []string
var pathSensitiveKeywords []string

// Comprehensively expanded IDOR parameter keywords
var defaultIdorKeywords = []string{
	// User & Identity
	"id", "user_id", "uid", "account_id", "account", "member_id", "member", 
	"profile_id", "profile", "customer_id", "customer", "employee_id", "emp_id",
	// B2B & Multi-Tenant
	"tenant_id", "tenant", "org_id", "organization_id", "org", "client_id", "client",
	"group_id", "group", "team_id", "team", "role_id", "role", "vendor_id", "merchant_id",
	// E-commerce & Financial
	"invoice_id", "invoice", "order_id", "order", "receipt_id", "receipt",
	"transaction_id", "transaction", "payment_id", "payment", "card_id", "billing_id",
	// Documents & Assets
	"file_id", "file", "doc_id", "doc", "document_id", "document", 
	"report_id", "report", "ticket_id", "ticket", "attachment_id",
	// Technical & System
	"setting_id", "setting", "config_id", "device_id", "mac", "session_id",
	"token", "uuid", "key", "api_key", "secret", "hash",
}

// Comprehensively expanded sensitive path keywords
var defaultPathKeywords = []string{
	// User & Account context
	"user", "account", "profile", "customer", "employee", "member",
	// Administrative & Organization context
	"admin", "dashboard", "settings", "config", "tenant", "org", "organization",
	"client", "team", "group", "role", "manage", "setup",
	// Financial & Transactional context
	"invoice", "order", "payment", "billing", "transaction", "receipt", "checkout",
	// Asset & Data context
	"file", "document", "doc", "report", "ticket", "api", "download", 
	"export", "import", "upload", "logs", "backup",
}

// Optimized Regex Patterns (Compiled once globally)
var uuidPattern = regexp.MustCompile(`(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`)
var numericIDPattern = regexp.MustCompile(`/\d+(/|$)`)

type KatanaJSON struct {
	URL     string `json:"url"`
	Request struct {
		URL string `json:"url"`
	} `json:"request"`
}

// loadKeywordsFromFile reads keywords line by line or initializes with defaults if file missing
func loadKeywordsFromFile(filename string, defaults []string) []string {
	var keywords []string

	if _, err := os.Stat(filename); os.IsNotExist(err) {
		fmt.Printf("[!] File '%s' not found. Creating it with default templates...\n", filename)
		file, err := os.Create(filename)
		if err != nil {
			fmt.Printf("[-] Warning: Could not create '%s' (%v), falling back to hardcoded defaults.\n", filename, err)
			return defaults
		}
		
		writer := bufio.NewWriter(file)
		for _, kw := range defaults {
			if _, err := writer.WriteString(kw + "\n"); err != nil {
				fmt.Printf("[-] Warning: Error writing to '%s': %v\n", filename, err)
			}
			keywords = append(keywords, kw)
		}
		
		if err := writer.Flush(); err != nil {
			fmt.Printf("[-] Warning: Error flushing data to '%s': %v\n", filename, err)
		}
		file.Close()
		return keywords
	}

	file, err := os.Open(filename)
	if err != nil {
		fmt.Printf("[-] Error opening '%s' (%v), falling back to defaults.\n", filename, err)
		return defaults
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && !strings.HasPrefix(line, "#") {
			keywords = append(keywords, strings.ToLower(line))
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("[-] Warning: Error reading '%s': %v\n", filename, err)
	}

	return keywords
}

func main() {
	inputFile := flag.String("i", "", "Path to Katana output file (TXT or JSONL)")
	outputDir := flag.String("o", "idor_results", "Directory to save the parsed results")
	workers := flag.Int("w", 20, "Number of concurrent worker goroutines")
	flag.Parse()

	if *inputFile == "" {
		fmt.Println("[-] Error: Input file path is required. Usage: ./bi -i katana.txt")
		os.Exit(1)
	}

	idorKeywords = loadKeywordsFromFile("idor_keywords.txt", defaultIdorKeywords)
	pathSensitiveKeywords = loadKeywordsFromFile("path_keywords.txt", defaultPathKeywords)

	fmt.Printf("[+] Loaded %d IDOR query keywords.\n", len(idorKeywords))
	fmt.Printf("[+] Loaded %d sensitive path keywords.\n", len(pathSensitiveKeywords))

	var queryIDORs sync.Map
	var pathIDORs sync.Map
	var graphqlEndpoints sync.Map

	jobs := make(chan string, 1000)
	var wg sync.WaitGroup

	for w := 1; w <= *workers; w++ {
		wg.Add(1)
		go worker(jobs, &wg, &queryIDORs, &pathIDORs, &graphqlEndpoints)
	}

	file, err := os.Open(*inputFile)
	if err != nil {
		fmt.Printf("[-] Error opening input file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("[*] Spawning %d workers. Processing lines from %s...\n", *workers, *inputFile)

	scanner := bufio.NewScanner(file)
	// Allocate a larger buffer (max 1MB) for exceptionally long URLs or JSON objects
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		jobs <- line
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("[-] Error encountered while reading input file: %v\n", err)
	}

	file.Close()
	close(jobs)

	wg.Wait()

	saveResults(*outputDir, &queryIDORs, &pathIDORs, &graphqlEndpoints)
}

func worker(jobs <-chan string, wg *sync.WaitGroup, queryMap, pathMap, gqlMap *sync.Map) {
	defer wg.Done()

	for line := range jobs {
		var url string
		
		if strings.HasPrefix(line, "{") {
			var kJson KatanaJSON
			if err := json.Unmarshal([]byte(line), &kJson); err == nil {
				if kJson.Request.URL != "" {
					url = kJson.Request.URL
				} else if kJson.URL != "" {
					url = kJson.URL
				}
			}
		} else {
			url = line
		}

		if url == "" {
			continue
		}

		analyzeURL(url, queryMap, pathMap, gqlMap)
	}
}

func analyzeURL(url string, queryMap, pathMap, gqlMap *sync.Map) {
	urlLower := strings.ToLower(url)

	if strings.Contains(urlLower, "/graphql") || strings.Contains(urlLower, "/api/graphql") {
		gqlMap.Store(url, true)
		return
	}

	parts := strings.SplitN(url, "?", 2)
	path := parts[0]
	pathLower := strings.ToLower(path)

	// Validate query string existence and prevent out-of-bounds errors
	if len(parts) > 1 && parts[1] != "" {
		queryParams := strings.Split(parts[1], "&")
		for _, param := range queryParams {
			if param == "" {
				continue
			}
			keyVal := strings.SplitN(param, "=", 2)
			key := strings.ToLower(keyVal[0])
			
			for _, kw := range idorKeywords {
				if key == kw {
					queryMap.Store(url, true)
					break
				}
			}
		}
	}

	hasUUID := uuidPattern.MatchString(path)
	hasNumeric := numericIDPattern.MatchString(path)

	if hasUUID || hasNumeric {
		for _, kw := range pathSensitiveKeywords {
			if strings.Contains(pathLower, kw) {
				pathMap.Store(url, true)
				break
			}
		}
	}
}

func saveResults(outputDir string, queryMap, pathMap, gqlMap *sync.Map) {
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		fmt.Printf("[-] Error creating directory '%s': %v\n", outputDir, err)
		return
	}

	targets := map[string]*sync.Map{
		"query_based_idor.txt":  queryMap,
		"path_based_idor.txt":   pathMap,
		"graphql_endpoints.txt": gqlMap,
	}

	fmt.Println("\n[+] Extraction Finished. Summary:")

	for filename, syncMap := range targets {
		filePath := filepath.Join(outputDir, filename)
		file, err := os.Create(filePath)
		if err != nil {
			fmt.Printf("[-] Error creating file %s: %v\n", filename, err)
			continue
		}

		count := 0
		writer := bufio.NewWriter(file)
		
		syncMap.Range(func(key, value interface{}) bool {
			if _, err := writer.WriteString(fmt.Sprintf("%s\n", key.(string))); err != nil {
				fmt.Printf("[-] Warning: Error writing to %s: %v\n", filename, err)
				return false
			}
			count++
			return true
		})
		
		if err := writer.Flush(); err != nil {
			fmt.Printf("[-] Warning: Error flushing data to %s: %v\n", filename, err)
		}
		
		file.Close()
		fmt.Printf("    -> %s: Found %d unique endpoints.\n", filename, count)
	}
	fmt.Printf("\n[+] Clean targets successfully written to '%s/'\n", outputDir)
}
