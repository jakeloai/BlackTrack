# BlackEncrypt

**BlackEncrypt** is an opsec-focused file content invisibility tool designed for Security Researchers, Bug Bounty Hunters, and Penetration Testers. It implements military-grade **AES-256-GCM** authenticated encryption to protect high-value local intelligence—such as vulnerability reports, PoC exploits, and scan artifacts—against active staging breaches, hostile honeypot counter-attacks, and unauthorized data exfiltration.

## Key Features

* **Content-Only Invisibility:** Encrypts the underlying data stream while preserving file names and structures, allowing seamless local artifact tracking.
* **Format & Layout Preservation:** Cryptographically treats files as binary streams, guaranteeing that Tabs, Indents, Newlines (`\n`), and markdown structures remain 100% intact upon decryption.
* **Cryptographic Integrity Verification (AEAD):** Powered by AES-GCM. If an adversary attempts to modify, inject code, or tamper with the encrypted payload, the built-in authentication layer detects it immediately and aborts the decryption process.
* **Zero-Trust Key Management:** Encryption keys are never cached or stored locally by the script.

---

## Installation & Requirements

BlackEncrypt requires Python 3 and the standard Python cryptography library.

1. Install the required dependency:
```bash
pip install cryptography

```


2. Clone or drop `sec_vault.py` (or your preferred execution filename) into your dedicated toolset directory.

---

## Usage Guide

### 1. Initialize an Encryption Key

Generate a secure, random 256-bit AES key encoded in Base64 string format.

```bash
python BlackEncrypt.py -g

```

> ⚠️ **Opsec Notice:** Copy the generated key and store it outside your active scanning or testing virtual environment (e.g., inside a secure host manager or physical vault). Do not save it alongside your encrypted files.

### 2. Encrypt File Contents

Encrypt single or multiple files simultaneously. This action overwrites the plain-text contents of the files with armored ciphertext.

```bash
python BlackEncrypt.py -e -k "<YOUR_KEY_STRING>" -f bug_report.md exploit.py

```

* **Result:** File names like `bug_report.md` remain unchanged to maintain tracking, but opening the files reveals completely unreadable, high-entropy ciphertext strings.

### 3. Decrypt and Restore Contents

Restore target files cleanly to their original plain-text formatting prior to platform submission or report finalization.

```bash
python BlackEncrypt.py -d -k "<YOUR_KEY_STRING>" -f bug_report.md exploit.py

```

---

## Technical Specifications

| Parameter | Specification |
| --- | --- |
| **Cipher Suite** | AES-256-GCM (Galois/Counter Mode) |
| **Key Size** | 256 bits |
| **Nonce/IV** | 12-byte cryptographically secure random bytes (`os.urandom`) generated per session |
| **Encoding** | Standard Base64 for file serialization |
| **Security Mode** | AEAD (Authenticated Encryption with Associated Data) |

---

## Defensive Integrity Alerts

Because the tool enforces **AES-GCM**, the data payload is structurally sealed. If a targeted host or automated script alters even 1 bit of the encrypted file:

```text
[-] Decryption failed for 'bug_report.md'!
    Possible causes: Invalid key or payload tampering detected.
