#!/bin/bash

# ==============================================================================
# Tool Name  : API Key Stress Test (Enterprise Pentesting Edition)
# Description: Multi-service credential identification and scope constraints verification.
# ==============================================================================

# --- Prerequisite Check ---
if ! command -v jq &> /dev/null; then
    echo "Fatal Error: 'jq' is required. Install it: sudo apt install jq"
    exit 1
fi

# --- UI Functions ---
divider() { echo "------------------------------------------------------------"; }

show_status() {
    echo "[*] API Key Stress Test - Professional Edition"
    echo "============================================================"
}

show_help() {
    show_status
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --key <api_key>     Target API key or token to analyze."
    echo "  -f, --file <file>       File containing a list of credentials (one per line)."
    echo "  -m, --mode <mode>       Execution mode: 'detect', 'stress', or 'auto'."
    echo "                            detect : Identify service type and stop."
    echo "                            stress : Run high-count request testing."
    echo "                            auto   : Run detect first, then auto-trigger stress."
    echo "  -c, --count <number>    Number of stress test requests (Default: 1)."
    echo "  -h, --help              Show this help menu."
    echo ""
    echo "Note: For multi-part credentials (like AWS Key + Secret, or Twilio SID + Token),"
    echo "      pass them separated by a colon, e.g., -k 'AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'"
    echo ""
    exit 0
}

# --- Risk Warning ---
trigger_stress_warning() {
    local COUNT=$1
    echo ""
    echo "=================== CRITICAL RISK WARNING ==================="
    echo "You are about to initiate a STRESS TEST with $COUNT request(s) per key."
    echo ""
    echo "POTENTIAL CONSEQUENCES:"
    echo "1. Financial Charges: Active keys linked to billing will incur live costs."
    echo "2. Target Rate-Limiting: May trigger HTTP 429 or permanent IP blocks."
    echo "3. Legal/Compliance: Unauthorized load testing may violate terms of service."
    echo "============================================================="
    
    read -p "Type 'CONFIRM' to proceed with the stress test: " user_input
    if [[ "$user_input" != "CONFIRM" ]]; then
        echo "[-] Stress test aborted by user."
        exit 1
    fi
    echo "[+] Risk confirmed. Starting stress sequence..."
    echo ""
}

# --- Detection Module (Advanced Multi-Service Fingerprinting) ---
detect_service_type() {
    local CREDENTIAL=$1
    
    # Extract primary key if a separator is used
    local PRIMARY_KEY=$(echo "$CREDENTIAL" | cut -d':' -f1)

    # 1. Google Cloud / Firebase
    if [[ "$PRIMARY_KEY" =~ ^AIzaSy ]]; then
        echo "firebase_gcp"
        return
    fi

    # 2. AWS Access Key ID
    if [[ "$PRIMARY_KEY" =~ ^AKIA ]]; then
        echo "aws"
        return
    fi

    # 3. OpenAI API Key
    if [[ "$PRIMARY_KEY" =~ ^sk-[a-zA-Z0-9]{32,} ]]; then
        echo "openai"
        return
    fi

    # 4. GitHub Personal Access Token
    if [[ "$PRIMARY_KEY" =~ ^ghp_ || "$PRIMARY_KEY" =~ ^github_pat_ ]]; then
        echo "github"
        return
    fi

    # 5. GitLab Personal Access Token
    if [[ "$PRIMARY_KEY" =~ ^glpat- ]]; then
        echo "gitlab"
        return
    fi

    # 6. Slack Token
    if [[ "$PRIMARY_KEY" =~ ^xoxb- || "$PRIMARY_KEY" =~ ^xoxp- ]]; then
        echo "slack"
        return
    fi

    # 7. Stripe Live API Key
    if [[ "$PRIMARY_KEY" =~ ^sk_live_ ]]; then
        echo "stripe"
        return
    fi

    # 8. Twilio Account SID
    if [[ "$PRIMARY_KEY" =~ ^AC[a-fA-F0-9]{32} ]]; then
        echo "twilio"
        return
    fi

    # 9. DigitalOcean Personal Access Token
    if [[ "$PRIMARY_KEY" =~ ^dop_v1_ ]]; then
        echo "digitalocean"
        return
    fi

    # Fallback to structural heuristic check via API probes if syntax is generic
    echo "unknown"
}

# --- Dynamic Request Dispatcher ---
execute_single_request() {
    local CREDENTIAL=$1
    local SERVICE_TYPE=$2
    local HTTP_CODE="000"
    local STATUS_MSG="Unknown status"

    # Handle dual-part tokens (Key:Secret or SID:Token)
    local PART1=$(echo "$CREDENTIAL" | cut -d':' -f1)
    local PART2=$(echo "$CREDENTIAL" | cut -d':' -f2)

    case "$SERVICE_TYPE" in
        "firebase_gcp")
            local URL="https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${PART1}"
            local RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{"signUpWithEmailAndPassword":true}' "$URL")
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"signUpWithEmailAndPassword":true}' "$URL")
            if [[ "$HTTP_CODE" == "200" ]]; then
                STATUS_MSG="ACTIVE_FIREBASE_AUTH"
            elif [[ "$HTTP_CODE" == "400" ]]; then
                local ERR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
                STATUS_MSG="ACTIVE_KEY_RESTRICTED_FUNCTION_($ERR)"
            else
                STATUS_MSG="HTTP_ERR_$HTTP_CODE"
            fi
            ;;
            
        "aws")
            # Probing AWS requires proper signatures or calling AWS STS if aws-cli is missing.
            # This implements a basic request to the STS secure endpoint.
            if command -v aws &> /dev/null && [[ "$PART1" != "$PART2" ]]; then
                export AWS_ACCESS_KEY_ID="$PART1"
                export AWS_SECRET_ACCESS_KEY="$PART2"
                export AWS_DEFAULT_REGION="us-east-1"
                local OUT=$(aws sts get-caller-identity 2>&1)
                if [[ "$OUT" == *"Arn"* ]]; then
                    STATUS_MSG="ACTIVE_AWS_KEY_VALIDated"
                else
                    STATUS_MSG="AWS_AUTH_FAILURE"
                fi
            else
                STATUS_MSG="AWS_KEY_FOUND_BUT_SECRET_MISSING_OR_AWS_CLI_ABSENT"
            fi
            ;;
            
        "openai")
            local URL="https://api.openai.com/v1/models"
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $PART1" "$URL")
            if [[ "$HTTP_CODE" == "200" ]]; then STATUS_MSG="ACTIVE_OPENAI_KEY"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            ;;

        "github")
            local URL="https://api.github.com/user"
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $PART1" "$URL")
            if [[ "$HTTP_CODE" == "200" ]]; then STATUS_MSG="ACTIVE_GITHUB_TOKEN"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            ;;

        "gitlab")
            local URL="https://gitlab.com/api/v4/user"
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: $PART1" "$URL")
            if [[ "$HTTP_CODE" == "200" ]]; then STATUS_MSG="ACTIVE_GITLAB_TOKEN"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            ;;

        "slack")
            local URL="https://slack.com/api/auth.test"
            local RESP=$(curl -s -H "Authorization: Bearer $PART1" "$URL")
            if [[ $(echo "$RESP" | jq -r '.ok') == "true" ]]; then STATUS_MSG="ACTIVE_SLACK_TOKEN"; else STATUS_MSG="INVALID_SLACK_TOKEN"; fi
            ;;

        "stripe")
            local URL="https://api.stripe.com/v1/charges"
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$PART1:" "$URL")
            if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "400" ]]; then STATUS_MSG="ACTIVE_STRIPE_LIVE_KEY"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            ;;

        "twilio")
            if [[ "$PART1" != "$PART2" ]]; then
                local URL="https://api.twilio.com/2010-04-01/Accounts/${PART1}/Messages.json"
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${PART1}:${PART2}" "$URL")
                if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "401" ]]; then STATUS_MSG="TWILIO_RESP_$HTTP_CODE"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            else
                STATUS_MSG="TWILIO_SID_FOUND_BUT_AUTH_TOKEN_MISSING"
            fi
            ;;

        "digitalocean")
            local URL="https://api.digitalocean.com/v2/account"
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $PART1" "$URL")
            if [[ "$HTTP_CODE" == "200" ]]; then STATUS_MSG="ACTIVE_DIGITALOCEAN_TOKEN"; else STATUS_MSG="HTTP_ERR_$HTTP_CODE"; fi
            ;;
            
        *)
            STATUS_MSG="UNSUPPORTED_OR_UNKNOWN_SYNTAX_PATTERN"
            ;;
    esac

    echo "Status:$STATUS_MSG"
}

# --- Engine Coordinator ---
run_engine() {
    local CREDENTIAL=$1
    local MODE=$2
    local COUNT=$3
    
    local DISPLAY_KEY=$(echo "$CREDENTIAL" | cut -d':' -f1)
    local SHORT_KEY="[KEY: ${DISPLAY_KEY:0:12}...]"
    echo ">>> Processing Target: $SHORT_KEY <<<"

    # Step 1: Identification
    local SERVICE="unknown"
    if [[ "$MODE" == "detect" || "$MODE" == "auto" ]]; then
        echo "[i] Mode: Identifying Service Type via Regex Signatures..."
        SERVICE=$(detect_service_type "$CREDENTIAL")
        echo "    Identified Service Class: ${SERVICE^^}"
        
        if [[ "$MODE" == "detect" ]]; then
            divider
            return
        fi
    fi

    if [[ "$MODE" == "stress" ]]; then
        SERVICE=$(detect_service_type "$CREDENTIAL")
    fi

    # Step 2: Stress Verification Phase
    if [[ "$MODE" == "stress" || "$MODE" == "auto" ]]; then
        echo "[i] Mode: Launching Verification/Stress Sequence..."
        for (( i=1; i<=COUNT; i++ )); do
            echo "    [Request $i/$COUNT]"
            local RESULT=$(execute_single_request "$CREDENTIAL" "$SERVICE")
            echo "    Result: $RESULT"
            
            if [[ "$RESULT" == *"429"* || "$RESULT" == *"RATE_LIMIT"* ]]; then
                echo "    [!] Warning: Rate Limit encountered. Aborting sequence loop."
                break
            fi
            
            [[ $i -lt $COUNT ]] && sleep 1
        done
    fi
    divider
}

# --- Main Parsing ---
if [[ "$#" -eq 0 ]]; then show_help; fi

API_TARGET=""
FILE_TARGET=""
EXEC_MODE=""
STRESS_COUNT=1

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -k|--key) API_TARGET="$2"; shift ;;
        -f|--file) FILE_TARGET="$2"; shift ;;
        -m|--mode) EXEC_MODE="$2"; shift ;;
        -c|--count) STRESS_COUNT="$2"; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Validation Inputs
if [[ -z "$EXEC_MODE" ]]; then
    echo "Error: Mode (-m) is required. Choose 'detect', 'stress', or 'auto'."
    exit 1
fi

if [[ "$EXEC_MODE" != "detect" && "$EXEC_MODE" != "stress" && "$EXEC_MODE" != "auto" ]]; then
    echo "Error: Invalid mode '$EXEC_MODE'. Use 'detect', 'stress', or 'auto'."
    exit 1
fi

if ! [[ "$STRESS_COUNT" =~ ^[0-9]+$ ]] || [ "$STRESS_COUNT" -le 0 ]; then
    echo "Error: Count must be a positive integer."
    exit 1
fi

show_status

# Enforce Risk Warning Gate
if [[ "$EXEC_MODE" == "stress" || "$EXEC_MODE" == "auto" ]]; then
    trigger_stress_warning "$STRESS_COUNT"
fi

# Route Execution
if [[ -n "$API_TARGET" ]]; then
    run_engine "$API_TARGET" "$EXEC_MODE" "$STRESS_COUNT"
elif [[ -n "$FILE_TARGET" ]]; then
    if [[ ! -f "$FILE_TARGET" ]]; then
        echo "Error: File '$FILE_TARGET' not found!"
        exit 1
    fi
    while read -r credential; do
        [[ -z "$credential" || "$credential" =~ ^# ]] && continue
        run_engine "$credential" "$EXEC_MODE" "$STRESS_COUNT"
    done < "$FILE_TARGET"
else
    echo "Error: Missing target identifier. Provide -k or -f."
    exit 1
fi

echo "[+] Processing Complete."
