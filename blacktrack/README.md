# BlackTrack (bt)

**Developer:** JakeLo + Gemini

**Version:** 3.1 (Enterprise Bug Bounty Edition)

**Focus:** Continuous Asset Discovery, Stealth Operations, Automated DAST Pipeline, and Robust Workspace Management

## Overview

**BlackTrack (bt)** is an advanced automated external reconnaissance framework designed for professional red teamers and bug bounty hunters. Version 3.1 elevates the tool with an **Adaptive Intelligence Engine**, a **Stealth Proxy Module**, and a **Secure Workspace Manager**, allowing the tool to bypass modern WAFs, maintain high anonymity, and seamlessly handle environmental inconsistencies (like APT vs. Go installations) while tracking attack surface changes.

## Pipeline Architecture

BlackTrack orchestrates a sophisticated multi-stage pipeline:

1. **Secure Workspace Management:** Creates ephemeral temporary directories for intermediate files that automatically self-destruct upon exit, ensuring zero disk bloat.
2. **Stealth Proxy Module:** Automatically fetches and validates high-speed (Latency < 800ms) Elite proxies to mask the scanner's origin.
3. **Subdomain Enumeration:** Leveraging `subfinder` for multi-source, recursive discovery.
4. **HTTP Validation:** Utilizing a global binary detection engine to intelligently route through `httpx-toolkit` or `httpx` with proxy rotation to filter active web services.
5. **Adaptive Intelligence (The Sensor):** Automatically fingerprints WAFs (Cloudflare, Akamai, etc.) and adjusts scanning frequency, threads, and jitter dynamically.
6. **Delta Analysis:** Identifying new attack surfaces via `comm` logic since the last operational cycle.
7. **Deep Crawling:** Utilizing `Katana` with headless browsing and strict static-file filtering.
8. **Vulnerability Scanning:** Executing `Nuclei` in DAST mode using adaptive rate-limiting and validated proxy pools.

---

## Installation & Setup

### 1. Run the Automated Installer

The `install.sh` script handles Golang installation, modern dependency resolution (specifically patching `httpx-toolkit` for Kali Linux), and path configuration. It must be run with `sudo`.

```bash
chmod +x install.sh bt.sh
sudo ./install.sh
source ~/.bashrc

```

### 2. Configure Notifications

BlackTrack supports direct Discord integration via Webhooks.

**Manual Webhook Setup:**
Edit the `bt.sh` file and paste your URL into the `DISCORD_WEBHOOK` variable at the top:

```bash
DISCORD_WEBHOOK="[https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN](https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN)"

```

---

## Usage

### Adaptive Stealth Scan (Recommended)

Run a scan with automatic proxy rotation, modern randomized User-Agents, and WAF-aware rate limiting:

```bash
./bt.sh -r root_domains.txt -s wildcard_domains.txt -rl 20 -proxy

```

### Continuous Monitoring (Cronjob Mode)

Isolate and scan only newly discovered assets since the previous run:

```bash
./bt.sh -s targets.txt -cj -proxy

```

### Force Aggressive Scan

Override delta logic to rescan the entire infrastructure without proxy usage:

```bash
./bt.sh -s targets.txt -f

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

* **Adaptive Scaling:** When BlackTrack detects a WAF, it automatically drops to an ultra-low thread count (2 threads) with high jitter. This significantly reduces the chance of IP blacklisting.
* **Environment Agnostic:** Don't worry about whether you installed `httpx` via Go or `httpx-toolkit` via Kali APT. Version 3.1 automatically detects your binary structure and uses the correct one to prevent `command not found` errors.
* **Zero Disk Bloat:** All intermediate files (`katana_filtered.txt`, `alive_proxies.txt`, etc.) are now routed to a secure temporary directory (`/tmp/blacktrack_XXXXXX`) that completely deletes itself when the script finishes or is aborted.
* **Zero Noise:** Static extensions like `.woff2`, `.svg`, and `.mp4` are filtered out during crawling to ensure the Nuclei engine focuses only on actionable endpoints.

## Output Files

All persistent output is now safely stored in the `bt_workspace/` directory in your current working path:

* `bt_workspace/all_targets_yesterday.txt`: Historical data preserved for future cronjob/delta comparisons.
* `bt_workspace/nuclei_results_YYYYMMDD_HHMMSS.txt`: Final timestamped report of critical, high, and medium findings.

*(Note: Raw logs, proxy lists, and intermediate crawling data are automatically purged upon exit).*

## Disclaimer

This tool is for authorized security testing only. The developer, JakeLo, is not responsible for any misuse or damage caused by this program. Users must comply with all local and international laws.

```
