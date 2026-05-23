# blackfuzz (bf)

An anomaly-based fuzzing engine designed for automated security testing and bug bounty hunting. It mutates raw HTTP requests using Radamsa and flags unexpected server behavior based on response length differentials.

## Features

* **High Performance**: Built with a Go worker pool to handle parallel request processing efficiently.
* **Smart Fuzzing**: Leverages Radamsa to generate intelligent mutations from a provided seed request.
* **Anomaly Detection Engine**: Dynamically establishes a baseline response length and flags any responses deviating by more than 200 bytes.
* **IP Block Protection**: Monitors network connection states and HTTP responses (403/429). Automatically pauses execution and alerts the user to manually switch VPN/IP nodes before resuming.

## Authors

* **JakeLo** - Lead Developer
* **Gemini** - AI Collaborator

## Prerequisites

The tool requires a Linux environment (such as Kali Linux, Debian, or Ubuntu) with the following dependencies installed:

* GCC / Make
* Git
* Go (golang-go)
* Radamsa

The provided installation script handles all dependencies automatically.

## Installation

Run the automated setup script to compile and install `blackfuzz` as a global system command (`bf`):

```bash
chmod +x install.sh
./install.sh

```

## Usage

Create a file named `request.txt` containing your raw target HTTP request, then run the tool:

```bash
bf [OPTIONS] <raw_request_file>

```

### Options

```text
  -u string
        Target URL (Required)
  -n int
        Number of fuzz requests (Default: 100)
  -o string
        Output directory (Default: "fuzz_output")

```

### Example

```bash
bf -u http://target.com/api/v1/resource -n 500 -o target_fuzz request.txt

```

## How It Works

1. **Baseline Phase**: The engine sends initial requests to measure the target's typical response length.
2. **Fuzzing Phase**: Active workers continuously pull mutated payloads from Radamsa and send them to the target.
3. **Analysis**: Responses that vary noticeably from the baseline are copied directly to the `anomalies/` folder for immediate inspection.
4. **Circumvention**: If the server rate-limits or blocks the connection, the script plays an audio alert and holds further workers until the user updates their active IP address.
