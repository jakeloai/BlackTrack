import asyncio
import httpx
import argparse
import itertools
import os
import sys
import time
import hashlib
import re
import warnings

# 隱藏不安全 HTTPS 請求嘅警告
warnings.filterwarnings("ignore", message="Unverified HTTPS request")

METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD", "TRACE"]

# Maximized Wordlist: Cache Poisoning, Routing Overrides, CORS Bypasses, and Identity Spoofing
BUG_BOUNTY_HEADERS = {
    # --- IP Spoofing & Access Control Bypass ---
    "X-Forwarded-For": "127.0.0.1",
    "X-Forwarded-Host": "localhost",
    "X-Client-IP": "127.0.0.1",
    "X-Remote-IP": "127.0.0.1",
    "X-Remote-Addr": "127.0.0.1",
    "True-Client-IP": "127.0.0.1",
    "Client-IP": "127.0.0.1",
    "X-Real-IP": "127.0.0.1",
    "X-Originating-IP": "127.0.0.1",
    "CF-Connecting-IP": "127.0.0.1",
    "Fastly-Client-IP": "127.0.0.1",
    
    # --- Proxy Routing Overrides (API Gateways / NGINX / Apigee Bypasses) ---
    "X-Original-URL": "/admin",
    "X-Rewrite-URL": "/admin",
    "X-Override-URL": "/admin",
    "X-Http-Destination-Override": "/admin",
    "X-Custom-IP-Authorization": "127.0.0.1",
    
    # --- Cache Poisoning & Routing Defects ---
    "X-Forwarded-Scheme": "http",
    "X-Forwarded-Proto": "http",
    "X-Host": "127.0.0.1",
    "Forwarded": "for=127.0.0.1;proto=http;by=127.0.0.1",
    "X-Http-Method-Override": "POST",
    "X-Method-Override": "POST",
    
    # --- CORS Pre-flight & Origin Spoofing ---
    "Origin": "null",
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "Authorization, Content-Type",
    
    # --- Content-Type & Serialization Alternatives (REST / GraphQL / gRPC confusion) ---
    "Content-Type": "application/graphql",
    "Accept": "application/json, text/plain, */*",
    
    # --- Protocol Smuggling & Hop-by-Hop Target Abuse ---
    "Upgrade": "WebSocket",
    "Connection": "Upgrade",
    
    # --- Session & Target Fingerprint Control ---
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

KEYWORD_SIGNATURES = [
    re.compile(b"access denied", re.IGNORECASE),
    re.compile(b"unauthorized", re.IGNORECASE),
    re.compile(b"forbidden", re.IGNORECASE),
    re.compile(b"sql syntax", re.IGNORECASE),
    re.compile(b"internal server error", re.IGNORECASE),
    re.compile(b"exception occurred", re.IGNORECASE),
    re.compile(b"invalid token", re.IGNORECASE),
    re.compile(b"route not found", re.IGNORECASE)
]

abort_fuzzing = False
consecutive_errors = 0

base_status = None
base_hash = None
base_dom_structure = None
base_time = None
base_redirect_len = None

def parse_raw_request(file_path):
    if not os.path.exists(file_path):
        print(f"[-] Error: Request file not found at {file_path}")
        sys.exit(1)
        
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        raw_content = f.read()
    
    raw_content = raw_content.replace('\r\n', '\n')
    
    if '\n\n' in raw_content:
        headers_part, body_part = raw_content.split('\n\n', 1)
    else:
        headers_part = raw_content
        body_part = ""
        
    header_lines = headers_part.split('\n')
    first_line = header_lines[0].strip().split()
    
    if len(first_line) < 2:
        print("[-] Error: Invalid Raw HTTP format. First line must contain Method and Path.")
        sys.exit(1)
        
    method = first_line[0]
    path = first_line[1]
    
    headers = {}
    for line in header_lines[1:]:
        line = line.strip()
        if not line or ":" not in line: 
            continue
        k, v = line.split(":", 1)
        headers[k.strip()] = v.strip()
            
    host = headers.get('Host', 'localhost')
    scheme = "https"
    if ":80" in host or "localhost" in host:
        scheme = "http"
        
    from urllib.parse import urljoin
    target_url = urljoin(f"{scheme}://{host}", path)
    body = body_part.strip()
    
    return method, target_url, headers, body

def clean_and_hash(content: bytes) -> str:
    cleaned = re.sub(b'(?i)(nonce|csrf|token|session|time|ts)["\']?\\s*[:=]\\s*["\']?[a-zA-Z0-9_=-]+', b'', content)
    cleaned = re.sub(b'\\s+', b' ', cleaned).strip()
    return hashlib.sha1(cleaned).hexdigest()

def extract_dom_skeleton(content: bytes) -> bytes:
    tags = re.findall(b'<[a-zA-Z0-9]+[^>]*>', content)
    skeleton = b''.join(re.sub(b'=["\'][^"\']*["\']', b'=""', tag) for tag in tags)
    return skeleton

async def fuzz_task(client, method, url, headers, body, output_dir, delay, max_err):
    global consecutive_errors, abort_fuzzing
    global base_status, base_hash, base_dom_structure, base_time, base_redirect_len
    
    if abort_fuzzing: return

    try:
        if delay > 0:
            await asyncio.sleep(delay)
        
        start_time = time.time()
        response = await client.request(
            method=method, url=url, headers=headers,
            content=body if body else None, timeout=8.0, follow_redirects=True
        )
        execution_time = (time.time() - start_time) * 1000
        
        if response.status_code == 429 or response.status_code >= 500:
            consecutive_errors += 1
            if max_err > 0 and consecutive_errors >= max_err:
                print(f"[-] Circuit breaker triggered: {consecutive_errors} continuous server errors. Aborting.")
                abort_fuzzing = True
                return
        else:
            consecutive_errors = 0
        
        anomalies = []
        resp_content = response.content
        current_hash = clean_and_hash(resp_content)
        
        if base_hash and current_hash != base_hash:
            current_dom = extract_dom_skeleton(resp_content)
            if base_dom_structure and current_dom != base_dom_structure:
                anomalies.append("structural-dom-mismatch")
            else:
                anomalies.append("content-hash-variant")
                
        if base_status and response.status_code != base_status:
            anomalies.append(f"status-code-shift({base_status}->{response.status_code})")
            
        for val in headers.values():
            if len(val) > 4 and val.encode() in resp_content:
                anomalies.append(f"input-reflected({val[:15]})")
                
        for pattern in KEYWORD_SIGNATURES:
            if pattern.search(resp_content):
                anomalies.append(f"signature-match({pattern.pattern.decode()})")
                
        if base_time and execution_time > max(3000.0, base_time * 3):
            anomalies.append(f"timing-delay({execution_time:.0f}ms)")
            
        cache_control = response.headers.get("X-Cache", "") or response.headers.get("Cache-Control", "")
        if "hit" in cache_control.lower():
            anomalies.append("cache-hit-state")
            
        current_redirect_len = len(response.history)
        if base_redirect_len is not None and current_redirect_len != base_redirect_len:
            anomalies.append(f"redirect-chain-mutation({base_redirect_len}->{current_redirect_len})")

        if anomalies:
            print(f"[ANOMALY] Method: {method} | Indicators: {', '.join(anomalies)} | Time: {execution_time:.1f}ms")
            
            unique_id = hashlib.md5(f"{method}{url}{current_hash}".encode()).hexdigest()[:8]
            filename = f"anomaly_{method}_{response.status_code}_{unique_id}.txt"
            with open(os.path.join(output_dir, filename), 'w', encoding='utf-8') as f:
                f.write(f"URL: {url}\nMETHOD: {method}\n")
                f.write("--- HEADERS ---\n")
                for k, v in headers.items(): f.write(f"{k}: {v}\n")
                f.write(f"\n--- METRICS ---\nStatus: {response.status_code}\nHash: {current_hash}\nIndicators: {anomalies}\n")
            
    except Exception:
        consecutive_errors += 1
        if max_err > 0 and consecutive_errors >= max_err:
            abort_fuzzing = True

async def worker(queue, client, target_url, base_body, output_dir, sleep_delay, max_errors):
    global abort_fuzzing
    while not abort_fuzzing:
        try:
            item = queue.get_nowait()
        except asyncio.QueueEmpty:
            break
        
        method, current_headers = item
        await fuzz_task(
            client, method, target_url, current_headers, base_body, 
            output_dir, sleep_delay, max_errors
        )
        queue.task_done()

def main():
    global base_status, base_hash, base_dom_structure, base_time, base_redirect_len
    global abort_fuzzing
    
    print("------------------------------------------------------")
    print(" BlackRequest v1.4 | Developer: JakeLo")
    print(" High-Capacity Stream Engine & Structural Anomaly Engine")
    print("------------------------------------------------------")
    
    parser = argparse.ArgumentParser(description="BlackRequest (br.py) by JakeLo")
    target_group = parser.add_argument_group("Target Constraints")
    target_group.add_argument("-u", "--url", help="Target URL endpoint")
    target_group.add_argument("-r", "--request", help="Burp Suite Raw Request TXT template")
    
    perf_group = parser.add_argument_group("Execution Parameters")
    perf_group.add_argument("-c", "--concurrency", type=int, default=10, help="Max concurrent tasks (Default: 10)")
    perf_group.add_argument("-s", "--sleep", type=float, default=0.0, help="Delay between operations (Default: 0.0)")
    perf_group.add_argument("-m", "--max-errors", type=int, default=30, help="Circuit breaker threshold (Default: 30)")
    perf_group.add_argument("-o", "--output", default="br_vault", help="Log directory (Default: br_vault)")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.output):
        os.makedirs(args.output)
        
    target_url = ""
    base_method, base_headers, base_body = "GET", {}, ""
    
    if args.request:
        req_method, req_path, req_headers, req_body = parse_raw_request(args.request)
        base_method, base_headers, base_body = req_method, req_headers, req_body
        target_url = req_path
    elif args.url:
        target_url = args.url
    else:
        print("[-] Configuration Error: Define target via (-u) or (-r).")
        return

    # Optimized Pairwise Strategy: Single variations + Double interactions (max depth 2)
    # This prevents the 2^N expansion trap while maintaining complete test accuracy
    header_items = list(BUG_BOUNTY_HEADERS.items())
    combinations = []
    
    # 1. Single Header Injections
    for item in header_items:
        combinations.append({item[0]: item[1]})
        
    # 2. Dual-Header Interaction Testing (Access bypass combined with routing tricks)
    for comb in itertools.combinations(header_items, 2):
        combinations.append({comb[0][0]: comb[0][1], comb[1][0]: comb[1][1]})
        
    total_permutations = len(METHODS) * len(combinations)
    
    print(f"[*] Target endpoint: {target_url}")
    print(f"[*] Matrix parameters: Concurrency={args.concurrency} | Sleep={args.sleep}s | Fault Limit={args.max_errors}")
    print(f"[*] Mapped index: {total_permutations} variations generated (Pairwise Constrained).")
    
    print("[*] Calibration session active: establishing stable signatures...")
    try:
        # 已加入 verify=False 忽略校準時的 SSL 證書錯誤
        with httpx.Client(timeout=6.0, follow_redirects=True, verify=False) as sample_client:
            start_baseline = time.time()
            baseline_res = sample_client.request(
                method=base_method, url=target_url, headers=base_headers, content=base_body if base_body else None
            )
            base_time = (time.time() - start_baseline) * 1000
            base_status = baseline_res.status_code
            base_hash = clean_and_hash(baseline_res.content)
            base_dom_structure = extract_dom_skeleton(baseline_res.content)
            base_redirect_len = len(baseline_res.history)
            
        print(f"[+] Calibration completed (Status={base_status} | Structural Hash={base_hash[:10]} | Redirects={base_redirect_len})")
    except Exception as e:
        print(f"[-] Calibration failed ({e}). Running without predictive anomaly models.")

    async def execute_fuzz_matrix():
        global abort_fuzzing
        queue = asyncio.Queue(maxsize=args.concurrency * 2)
        
        # 已加入 verify=False 忽略異步發包時的 SSL 證書錯誤
        async with httpx.AsyncClient(verify=False) as client:
            workers = [
                asyncio.create_task(worker(queue, client, target_url, base_body, args.output, args.sleep, args.max_errors))
                for _ in range(args.concurrency)
            ]
            
            try:
                for method in METHODS:
                    if abort_fuzzing:
                        break
                    for h_comb in combinations:
                        if abort_fuzzing:
                            break
                        current_headers = base_headers.copy()
                        current_headers.update(h_comb)
                        await queue.put((method, current_headers))
                            
            except Exception as e:
                print(f"[-] Feeder routine encountered fault: {e}")
            finally:
                if abort_fuzzing:
                    while not queue.empty():
                        try:
                            queue.get_nowait()
                            queue.task_done()
                        except asyncio.QueueEmpty:
                            break
                
                await queue.join()
                for w in workers:
                    w.cancel()
                await asyncio.gather(*workers, return_exceptions=True)

    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    
    asyncio.run(execute_fuzz_matrix())
    print(f"[*] Execution finished. Anomalies synced to: ./{args.output}/")

if __name__ == "__main__":
    main()
