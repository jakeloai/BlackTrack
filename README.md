# BlackSecurity Suite

<img width="1720" height="720" alt="BlackSecurity" src="https://github.com/user-attachments/assets/40455a97-e056-49d7-8d5c-9e612ab342d4" />  

An open-source offensive security orchestration framework designed to simulate high-fidelity adversaries. This suite moves past standard compliance verification to test real-world organization resilience against real threat vectors.

---

## Technical Architecture Overview

The system is engineered as a collection of decoupled, task-specific modules. It automates large-scale attack surface reconnaissance, data extraction verification, perimeter anomaly discovery, and identity boundary validation.

| Module | Primary Runtime | Functional Mechanics | Operational Application |
| --- | --- | --- | --- |
| **`BlackTrack`** | Bash / Go Engine | Automates multi-tiered subdomain enumeration, active asset filtering, recursive crawling, and vulnerability cataloging. | Adaptive attack surface discovery and delta surface monitoring. |
| **`BlackAPIKey`** | Bash / `jq` | Fingerprints SaaS API credential types and maps scope constraints against runtime metadata configurations. | Post-breach credential exposure auditing and privilege isolation testing. |
| **`BlackRequest`** | Python / `asyncio` | High-throughput HTTP fuzzing core optimizing pairwise combinations to detect routing, proxy, and structural drift anomalies. | Edge perimeter control profiling and WAF enforcement validation. |
| **`BlackSniper`** | Bash / `netcat` | Parallelized TCP connect scanning and banner retrieval loops across arbitrary infrastructure footprints. | External ingress point auditing and perimeter asset validation. |
| **`BlackStealth`** | PowerShell / VBS | Decoupled scripting wrapper running tasks without visible console interfaces to check host telemetry limits. | Host detection boundary testing and Endpoint/DLP telemetry auditing. |
| **`BlackDork`** | Data Matrix | Structured dork matrices mapping targeted asset leakage via global search engine patterns. | OSINT asset profiling and configuration exposure indexing. |
| **`BlackExploit`** | Reference DB | Locally indexed vulnerability mappings and verified functional proof-of-concept components. | Closed-loop patch validation and specific tactical verification. |

---

## Design Philosophy and Core Objectives

The architecture of this framework stems from over a decade of domain experience in real-world psychology, messaging infrastructure, and technical sales, translated into functional software through iterative machine intelligence engineering. Traditional enterprise security operations routinely rely on rigid checklists that focus on static compliance rather than functional capability. This suite rejects that model.

The toolset operates on a single premise: **How does a motivated threat actor look at your organization?** Threat actors do not read compliance sheets or focus on checkbox items. They look for human cognitive errors, configuration ambiguities, hidden infrastructure seams, and detection gaps. By using AI to systematically codify advanced adversary logic, this project bridges the gap between theoretical defense blueprints and active corporate security postures.

This framework is not built for compliance compliance-checkers, automated report generators, standard vulnerability scanners, or laboratory Capture-The-Flag competitors. It is engineered explicitly for experienced Red Team operators and organizations that demand realistic, high-stress resilience testing to uncover structural flaws, operational blind spots, and code defects so they can patch, harden, or build survival strategies around them.

---

## Detailed Module Engineering

### 1. BlackTrack (`bt.sh`)

An orchestration pipeline managing core Go engines (`subfinder`, `httpx`, `katana`, `nuclei`) to handle the reconnaissance phase.

* **WAF Jitter Logic:** Parses HTTP header signatures for common edge proxies. Detection switches the engine into low-frequency execution with randomized sleep intervals to simulate persistent, low-signal enumeration.
* **Delta Analysis:** Built-in `-cj` cron automation tracks infrastructure drift by isolating new ingress nodes over discrete periods.

### 2. BlackAPIKey (`blackapikey`)

An identification utility supporting syntax verification rules for cloud service operators (AWS, OpenAI, GCP, GitHub, Slack, Twilio, Stripe, DigitalOcean).

* **Scope Validation:** Runs safe read-only metadata calls (e.g., AWS STS `get-caller-identity`) to isolate active permissions tied to discovered assets.
* **Execution Gate:** Implements an interactive execution loop to avoid accidental rate-limiting or unintended usage tracking on target endpoints.

### 3. BlackRequest (`blackrequest`)

An asynchronous fuzzing tool built to map structural anomalies across application boundaries.

* **Pairwise Injections:** Tests combinations of headers (routing overrides, client IP claims, and CORS origins) using a structured matrix to find edge gateway misconfigurations while keeping runtime paths optimized.
* **DOM Skeleton Hashes:** Cleans dynamic response variations to generate tag-only HTML skeleton comparisons. This isolates visual differences that point to administrative portals or unmapped application paths.

### 4. BlackSniper (`blacksniper`)

A parallel connection validator designed to verify active external asset exposure.

* **Mechanics:** Executes non-interactive socket timeouts via traditional netcat layers to grab network banners without initiating full interactive handshakes.

### 5. BlackStealth (`blackstealth`)

An automated extraction and simulation framework designed to test defensive telemetry coverage on corporate endpoints.

* **Mechanics:** Wraps functional PowerShell discovery logic within silent Windows Script Host (.vbs) templates. This tests whether corporate endpoint detection tools flag decoupled console execution patterns when no terminal interface is presented to the user.

---

## Setup and Environmental Deployment

### Runtimes and Go Binaries Pathway

Ensure your shell path environment variable includes the path where Go installs compiled binaries, otherwise dependencies will fail to invoke.

Run the following command to update your current environment, and append it to your system profile file (`~/.bashrc` or `~/.zshrc`) for persistence:

```bash
export PATH=$PATH:$HOME/go/bin

```

### Dependencies

Target runtimes require specific core components:

```bash
sudo apt update && sudo apt install -y jq curl netcat-traditional python3 python3-pip

# Go dependencies required for BlackTrack operations
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

```

### Discord Notification Configuration

To receive automated execution alerts directly inside a Discord channel:

1. Open Discord, navigate to Server Settings -> Integrations -> Webhooks.
2. Generate a new Webhook, specify the target channel, and copy the Webhook URL.
3. Open `blacktrack/bt.sh` and locate the configuration block.
4. Input your URL string into the variable declaration:

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK_STRING_HERE"

```

### Installation

```bash
git clone https://github.com/jakeloai/BlackSecurity.git
cd BlackSecurity
pip install -r blackrequest/requirements.txt

```

---

## Critical Operational Advisory

Executing these tools without comprehensive operational security knowledge, network path obfuscation, or a deep understanding of anonymous deployment vectors will result in rapid attribution, infrastructure termination, and immediate exposure to legal prosecution. Running real-world attack vectors leaves clear, trace signatures on network logging systems, security incident monitoring software, and service provider telemetry pipelines. If you deploy these tools without understanding operational safety, operational anonymity, and the specific mechanics of infrastructure deployment, you will go to jail.

---

## Global Legal Constraints and Compliance

This repository is maintained globally for authorized infrastructure validation campaigns, simulation operations, and professional red team portfolio tracking. All execution scenarios must be limited to computing systems under the direct ownership of the operator or explicitly authorized via a formal, written Rules of Engagement (RoE) agreement.

Unauthorized usage across production assets or external infrastructure without proper management sign-off violates global cybercrime frameworks, including the Computer Misuse Act (UK), Computer Fraud and Abuse Act (US), Section 27A of the Telecommunications Ordinance (Hong Kong), and equivalent international computer misuse statutes. The developer assumes no liability for administrative misuse, structural infrastructure impact, regulatory penalties, data degradation, or criminal infractions resulting from deployment.

