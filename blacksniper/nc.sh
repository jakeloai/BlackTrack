#!/bin/bash

usage() {
    echo "Usage: $0 -f <ip_list_file> [-p <port>]"
    echo ""
    echo "Options:"
    echo "  -f    Path to the file containing IP addresses (e.g., ips.txt)"
    echo "  -p    Port to connect to (default: 22)"
    echo "  -h    Show this help menu"
    echo ""
    echo "Example:"
    echo "  $0 -f targets.txt -p 80"
    exit 1
}

PORT=22
FILE=""

while getopts "f:p:h" opt; do
    case "$opt" in
        f) FILE=$OPTARG ;;
        p) PORT=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$FILE" ]]; then
    echo "Error: Missing -f <file> argument."
    usage
fi

if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

echo "Testing Connection & Banner Grabbing"
echo "Target File : $FILE"
echo "Target Port : $PORT"
echo "------------------------------------------"

for ip in $(cat "$FILE"); do
    echo -n "[*] $ip:$PORT -> "
    
    timeout 2 nc -vn -w 2 "$ip" "$PORT"
    
    echo "------------------------------------------"
done

echo "Task Finished."
