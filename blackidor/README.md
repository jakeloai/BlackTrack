# bi (Black IDOR Grabber)

bi is a high-performance IDOR (Insecure Direct Object Reference) target discovery tool written in Go. It acts as an automated discovery engine to identify potential IDOR vulnerabilities within large-scale web applications by filtering crawler output for sensitive parameter patterns.

## Setup

1. Build the tool:
```bash
go build -o bi bi.go
chmod +x bi

```

2. Run once to generate configuration files:
```bash
./bi

```

This will automatically create `idor_keywords.txt` and `path_keywords.txt` in your current directory. You can edit these files to customize the detection logic without recompiling the tool.

## Usage Workflow

To effectively find IDOR vulnerabilities, follow this standard security research workflow:

### 1. Preparation

1. Create two separate accounts on the target application (Account A and Account B).
2. Log in with Account A in your browser.
3. Use Burp Suite or your browser's Developer Tools (F12) to capture the session cookie from a request.

### 2. Crawling (Authenticated)

Use katana to crawl the application while authenticated. By providing your session cookie, the crawler can map sensitive endpoints that are otherwise hidden from anonymous users.

```bash
katana -u https://target-site.com \
  -headless \
  -H "Cookie: session=YOUR_SESSION_COOKIE_HERE" \
  -d 5 -jc -o crawl.txt

```

### 3. Automated Discovery

Run bi against the crawler output to extract high-value targets.

```bash
./bi -i crawl.txt -o results -w 50

```

### 4. Verification

The results will be categorized in the results/ directory:

* query_based_idor.txt
* path_based_idor.txt
* graphql_endpoints.txt

To verify potential vulnerabilities, pipe these results into httpx to send them to Burp Suite for manual testing:

```bash
cat results/query_based_idor.txt | httpx -http-proxy http://127.0.0.1:8080 -silent

```

In Burp Suite, use the Autorize extension to automatically compare requests between Account A and Account B to identify authorization bypasses.

## Configuration

You can customize the detection parameters by editing the configuration files:

* `idor_keywords.txt`: Add or remove sensitive URL query parameters.
* `path_keywords.txt`: Add or remove sensitive URL path contexts.

## Developer Notes

* Flexibility: This tool is designed to be part of an automated pipeline. You can modify bi.go and execute go build at any time to apply new changes.
* System Integration: It is recommended to add the bi binary to your system PATH to allow quick access from any directory.
