# API Key Stress Test

A minimalist, high-coverage credential audit and active scope verification utility designed for professional penetration testers and security engineers. This tool facilitates the identification and controlled validation of leaked API keys across various cloud infrastructure, CI/CD, and communication providers without any intrusive visual wrappers.

---

## Features

* **Multi-Service Fingerprinting:** Utilizes non-intrusive regex signatures to classify credentials before dispatching requests.
* **12 Supported Services:** Out-of-the-box support for major enterprise endpoints:
* **Cloud / Identity:** Google Cloud / Firebase (`AIzaSy`), AWS Access Key ID (`AKIA`), DigitalOcean Personal Access Tokens (`dop_v1_`).
* **AI / Automation:** OpenAI API Keys (`sk-proj-`, `sk-`).
* **CI/CD & Source Code:** GitHub PAT (`ghp_`, `github_pat_`), GitLab PAT (`glpat-`).
* **Communications & SaaS:** Slack Tokens (`xoxb-`, `xoxp-`), Twilio SIDs (`AC`), Stripe Live Keys (`sk_live_`).


* **Granular Modes:** Segregates reconnaissance (detection) from high-volume simulation (stress testing).
* **Mandatory Risk Gate:** Enforces manual operational confirmation before invoking repetitive backend query loops to protect target service stability and control billing impacts.
* **Clean Outputs:** Free of ANSI color escape sequences, emojis, or banner art, making the text easily pipeable into text processors or report loggers.

---

## Technical Architecture Overview

The tool follows a linear lifecycle from classification to load dispatch:

```
[Target Token Input] ---> [Regex Fingerprint Matcher] ---> [Service Type Bound]
                                                                   |
 [Stress Loop Terminated] <-- [Rate Limit Detector] <-- [Dynamic Request Dispatcher]

```

---

## Usage Syntax

```
Usage: ./bak.sh [OPTIONS]

Options:
  -k, --key <api_key>     Target API key or token to analyze.
  -f, --file <file>       File containing a list of credentials (one per line).
  -m, --mode <mode>       Execution mode: 'detect', 'stress', or 'auto'.
                            detect : Identify service type and stop execution.
                            stress : Run high-count request testing.
                            auto   : Run detect first, then auto-trigger stress loop.
  -c, --count <number>    Number of stress test requests per key (Default: 1).
  -h, --help              Show this help menu.

```

> **Note on Multi-Part Credentials:** For providers that require dual parameters (e.g., AWS Access Key ID + Secret Key or Twilio Account SID + Auth Token), combine them using a colon (`:`) as the separator.
> Example: `-k "AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE"`

---

## Operational Execution Examples

### 1. Passive Detection Mode (Safe Reconnaissance)

Identify the service provider class of a specific string signature and exit safely without initiating further load loops:

```bash
./bak.sh -k "AIzaSyAz1234567890Example" -m detect

```

### 2. Multi-Part Active Verification

Validate the access constraints of an AWS identity set with a defined stress repetition threshold:

```bash
./bak.sh -k "AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE" -m stress -c 10

```

### 3. Automated Sequential Processing (Auto Mode)

Perform an initial regex fingerprint identification, immediately bind the specific endpoint handler, and proceed seamlessly to the repetitive load simulation sequence:

```bash
./bak.sh -k "sk-proj-ExampleOpenAIKey12345" -m auto -c 5

```

### 4. Bulk File Auditing

Process a newline-delimited registry of leaked credentials excavated from source code history audits:

```bash
./bak.sh -f leaked_credentials.txt -m detect

```

---

## Prerequisites

The logic utilizes standard Unix system binaries alongside `jq` for structure parsing. Ensure dependencies are satisfied before execution:

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install jq curl -y

# RHEL / CentOS
sudo dnf install jq curl -y

```

Ensure execution permissions are granted to the local filesystem node:

```bash
chmod +x bak.sh

```

---

## Safety and Operational Guardrails

When executing the script in `stress` or `auto` mode, the engine evaluates input variables and enforces an explicit runtime barrier:

1. **Financial Risk Control:** Active keys tied to live billing accounts (e.g., Stripe, OpenAI, Google Cloud) incur transaction costs. High loop limits (`-c`) multiply consumption charges.
2. **Automated Back-off:** The loop routine actively checks response streams for standard `HTTP 429` (Too Many Requests) headers. If detected, the tool terminates the sequence block prematurely to minimize unintended IP address blocking or service disruptions.
3. **Interactive Consent Verification:** User interaction is blocked until `CONFIRM` is explicit typed into the terminal input buffer. Missing parameters or unconfirmed runtime warnings drop execution automatically.
