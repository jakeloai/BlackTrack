# blackapk

Lightweight Android APK Reconnaissance & Attack Surface Extraction Tool

---

## Overview

blackapk is a lightweight static analysis tool designed for rapid Android APK reconnaissance.

It focuses on fast extraction of security-relevant signals such as endpoints, secrets, and exposed attack surface indicators.

It is intended for initial triage in penetration testing and red team engagements, not full application security analysis.

---

## Design Philosophy

blackapk is built around the following principles:

* Speed over completeness
* Signal extraction over structured analysis
* Attack surface discovery over reporting
* Minimal dependencies and operational overhead

It is designed to complement, not replace, full mobile security frameworks such as MobSF.

---

## Capabilities

blackapk performs static analysis on APK files and extracts:

### Network and infrastructure indicators

* HTTP and HTTPS endpoints
* WebSocket endpoints
* Domains and subdomains
* IP addresses

### Secrets and credentials

* API keys
* Access tokens
* Bearer tokens
* OAuth credentials
* JWT patterns
* Private key material indicators
* Cloud service keys (AWS, Firebase, Stripe, GitHub)

### Contact and identity data

* Email addresses
* Administrative and support contacts
* Internal service identifiers

### Android attack surface indicators

* Exported activities, services, and receivers
* Content providers
* Debuggable applications
* Cleartext traffic configuration
* Backup-enabled applications
* Intent filters and deep links

### Backend and cloud integrations

* Firebase configurations
* AWS and S3 references
* OAuth endpoints
* Webhook integrations
* Messaging and analytics services

---

## Installation

### Clone repository

```bash
git clone <repo>
cd blacksecurity
```

### Install dependencies

```bash
chmod +x install.sh
./install.sh
```

---

## Requirements

blackapk relies on standard Linux tooling:

* ripgrep (rg)
* apktool
* jadx
* unzip
* strings
* default-jdk

Optional tools improve analysis depth but are not required.

---

## Usage

### Standard execution

```bash
blackapk -t target.apk
```

### Short aliases

```bash
ba -t target.apk
```

```bash
ba.sh -t target.apk
```

---

## Output Structure

Each execution generates a dedicated workspace:

```text
apk_recon_<timestamp>/
├── unzipped/
├── apktool/
├── jadx/
├── findings/
│   ├── urls.txt
│   ├── emails.txt
│   ├── aws_keys.txt
│   ├── firebase.txt
│   ├── jwt_like.txt
│   ├── secret_keywords.txt
│   ├── android_exported.txt
│   └── ...
├── meta/
│   ├── file_inventory.txt
│   ├── sha256.txt
│   └── filetype.txt
└── summary.txt
```

---

## Positioning Relative to MobSF

blackapk is not a replacement for MobSF.

It operates at a different layer in the analysis workflow.

| Category | blackapk                 | MobSF               |
| -------- | ------------------------ | ------------------- |
| Scope    | Reconnaissance           | Full analysis       |
| Output   | Raw indicators           | Structured report   |
| Speed    | Fast                     | Heavier             |
| Purpose  | Attack surface discovery | Security assessment |

blackapk is intended for early-stage reconnaissance before deeper analysis is performed.

---

## Use Cases

* Initial APK reconnaissance during engagements
* Attack surface mapping
* Secret discovery in mobile applications
* Pre-analysis before reverse engineering workflows
* Rapid triage of unknown applications

---

## Roadmap

Planned enhancements:

* Structured JSON output
* Attack surface scoring engine
* Endpoint graph generation
* Cloud service risk classification
* Smali-level correlation analysis
* Automated intelligence summarization

---

## Disclaimer

This tool is intended for authorized security testing, research, and educational purposes only.

Unauthorized use against systems without explicit permission is not permitted.

---

## BlackSecurity Ecosystem

blackapk is part of the BlackSecurity toolkit family, designed for offensive security reconnaissance workflows.

---
