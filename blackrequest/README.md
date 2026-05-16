# BlackRequest (`br.py`)

An enterprise-grade, high-capacity single-target combinatorial fuzzer designed to identify infrastructure flaws, routing bypasses, and cache anomalies on highly secure environments. Developed with a zero-allocation streaming architecture, `BlackRequest` performs multi-variant HTTP mutation analysis without memory leakage or thread degradation.

---

## Technical Overview

Modern Application Delivery Controllers (ADCs), Web Application Firewalls (WAFs), CDN edge routing layers (such as Cloudflare, Fastly, Akamai), and API gateways (such as Apigee, AWS API Gateway) rely heavily on stateful evaluation of headers to determine access control, caching rules, and back-end routing.

`BlackRequest` systematically audits target endpoints by mutating request structures across three primary operational dimensions:

1. **HTTP Verbs / Methods Injection**: Cycles through standard and non-standard method types (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`, `HEAD`, `TRACE`) to expose improper endpoint mapping or method overrides.
2. **Hop-by-Hop and Boundary Header Modification**: Injects a curated wordlist mapping structural overrides, CDN routing keys, authentication bypasses, protocol smuggling configurations (`Upgrade: WebSocket`), and identity spoofing variables.
3. **Advanced Structural Anomaly Detection Engine**: Monitors backend deviations beyond primitive response code checking—utilizing dynamic DOM skeleton comparisons, dynamic token strip-hashing (`SHA-1`), input reflection analytics, and network connection metrics to spot subtle runtime alterations.

---

## Usage

### Define Target via Absolute URL

```bash
python br.py -u https://target.internal.api/v1/user/profile -c 25 -m 50

```

### Define Target via Raw HTTP Request Template

```bash
python br.py -r raw_burp_request.txt -c 15 -s 0.1 -o target_audit_vault

```

### Argument Layout

```text
Execution Parameters:
  -h, --help            Show this help message and exit
  -u URL, --url         Target endpoint URL string
  -r REQ, --request     Filepath to Burp Suite raw transaction text file
  -c CON, --concurrency Max parallel connection workers running concurrently (Default: 10)
  -s SLP, --sleep       Forced sleep delay intervals between worker operations (Default: 0.0)
  -m ERR, --max-errors  Circuit breaker threshold for continuous errors before termination (Default: 30)
  -o OUT, --output      Target storage log directory for recorded anomalies (Default: br_vault)

```
