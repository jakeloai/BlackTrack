# BlackTrack (bt)

**Developer:** JakeLo

**Version:** 2.0 (Adaptive Intelligence Update)

**Focus:** Continuous Asset Discovery, Stealth Operations, and Automated DAST Pipeline

## Overview

**BlackTrack (bt)** is an advanced automated external reconnaissance framework designed for professional red teamers and bug bounty hunters. Version 2.0 introduces an **Adaptive Intelligence Engine** and a **Stealth Proxy Module**, allowing the tool to bypass modern WAFs and maintain high anonymity while tracking attack surface changes.

## Pipeline Architecture

BlackTrack orchestrates a sophisticated multi-stage pipeline:

1. **Stealth Proxy Module:** Automatically fetches and validates high-speed (Latency < 800ms) Elite proxies to mask the scanner's origin.
2. **Subdomain Enumeration:** Leveraging `subfinder` for multi-source, recursive discovery.
3. **HTTP Validation:** Using `httpx-toolkit` with proxy rotation to filter active web services.
4. **Adaptive Intelligence (The Sensor):** Automatically fingerprints WAFs (Cloudflare, Akamai, etc.) and adjusts scanning frequency, threads, and jitter dynamically.
5. **Delta Analysis:** Identifying new attack surfaces via `comm` logic since the last operational cycle.
6. **Deep Crawling:** Utilizing `Katana` with headless browsing and strict static-file filtering.
7. **Vulnerability Scanning:** Executing `Nuclei` in DAST mode using adaptive rate-limiting and validated proxy pools.

---

## Installation & Setup

### 1. Run the Automated Installer

The `install.sh` script handles Golang installation, dependency resolution (including `bc` for math operations), and path configuration. It must be run with `sudo`.

```bash
chmod +x install.sh
sudo ./install.sh
source ~/.bashrc

```

### 2. Configure Notifications

BlackTrack supports direct Discord integration via Webhooks or through the `notify` tool configuration.

**Manual Webhook Setup:**
Edit the `bt.sh` file and paste your URL into the `DISCORD_WEBHOOK` variable:

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"

```

---

## Usage

### Adaptive Stealth Scan (Recommended)

Run a scan with automatic proxy rotation and WAF-aware rate limiting:

```bash
bt -r root_domains.txt -s wildcard_domains.txt -rl 20 -proxy

```

### Continuous Monitoring (Cronjob Mode)

Isolate and scan only newly discovered assets since the previous run:

```bash
bt -s targets.txt -cj -proxy

```

### Force Aggressive Scan

Override delta logic to rescan the entire infrastructure without proxy usage:

```bash
bt -s targets.txt -f

```

---

## Options

| Flag | Description |
| --- | --- |
| `-r <file>` | Input root domains list (Direct crawling). |
| `-s <file>` | Input wildcard domains list (Recursive enumeration). |
| `-rl <int>` | Base rate-limit (Adaptive Engine will lower this if WAF is detected). |
| `-proxy` | **Stealth Mode:** Automatically fetches, validates, and rotates Elite proxies. |
| `-cj` | **Cronjob Mode:** Enables delta monitoring to target new assets only. |
| `-f` | **Force Scan:** Overrides delta history to perform a full re-scan. |

---

## Pro Tips by JakeLo

* **Adaptive Scaling:** When BlackTrack detects a WAF, it automatically drops to a ultra-low thread count (2 threads) with high jitter. This significantly reduces the chance of IP blacklisting.
* **Proxy Quality:** The validator checks proxies against Google; any proxy with latency higher than 800ms is discarded to ensure scan stability.
* **Anonymity Check:** The tool strictly filters for Elite proxies. If a proxy adds `X-Forwarded-For` headers (Transparent Proxy), it is automatically rejected to protect your local IP.
* **Zero Noise:** Static extensions like `.woff2`, `.svg`, and `.mp4` are filtered out during crawling to ensure the Nuclei engine focuses only on actionable endpoints.

## Output Files

* `alive_proxies.txt`: Validated list of high-speed, high-anonymity proxies.
* `all_targets_yesterday.txt`: Historical data for delta comparison.
* `katana_filtered.txt`: Refined endpoint list ready for vulnerability analysis.
* `nuclei_results.txt`: Final report of critical, high, and medium findings.

## Disclaimer

This tool is for authorized security testing only. The developer, JakeLo, is not responsible for any misuse or damage caused by this program. Users must comply with all local and international laws.
