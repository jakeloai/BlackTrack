import os
import argparse
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def generate_key_string():
    """Generates a secure 256-bit AES key encoded in string format."""
    raw_key = AESGCM.generate_key(bit_length=256)
    return base64.b64encode(raw_key).decode('utf-8')

def encrypt_content(file_path, key_str):
    """Encrypts the file content using AES-256-GCM and overwrites the file."""
    try:
        raw_key = base64.b64decode(key_str.encode('utf-8'))
        aesgcm = AESGCM(raw_key)
        
        with open(file_path, 'rb') as f:
            original_data = f.read()
            
        if not original_data:
            print(f"[-] Warning: '{file_path}' is empty. Encryption skipped.")
            return

        # Generate a random 12-byte nonce for GCM
        nonce = os.urandom(12)
        ciphertext = aesgcm.encrypt(nonce, original_data, None)
        
        # Combine nonce and ciphertext into the final payload
        final_payload = nonce + ciphertext
        
        with open(file_path, 'wb') as f:
            f.write(base64.b64encode(final_payload))
            
        print(f"[+] Successfully encrypted content: {file_path}")
        print("[!] File content is now ciphertext. Metadata and filename are preserved.")
        
    except Exception as e:
        print(f"[-] Encryption failed: {str(e)}")

def decrypt_content(file_path, key_str):
    """Decrypts the file content and perfectly restores original formatting."""
    try:
        raw_key = base64.b64decode(key_str.encode('utf-8'))
        aesgcm = AESGCM(raw_key)
        
        with open(file_path, 'rb') as f:
            encrypted_base64 = f.read()
            
        try:
            final_payload = base64.b64decode(encrypted_base64)
        except Exception:
            print(f"[-] Error: Content in '{file_path}' is not valid ciphertext.")
            return
            
        if len(final_payload) < 12:
            print(f"[-] Error: Ciphertext payload in '{file_path}' is corrupted.")
            return
            
        nonce = final_payload[:12]
        ciphertext = final_payload[12:]
        
        # AES-GCM decryption and integrity verification
        decrypted_data = aesgcm.decrypt(nonce, ciphertext, None)
        
        with open(file_path, 'wb') as f:
            f.write(decrypted_data)
            
        print(f"[+] Successfully decrypted content: {file_path}")
        print("[+] Document format and structure completely restored.")
        
    except Exception as e:
        print(f"[-] Decryption failed for '{file_path}'!")
        print("    Possible causes: Invalid key or payload tampering detected.")
        print(f"    Details: {str(e)}")

def main():
    parser = argparse.ArgumentParser(
        description="SecResearcher Utility - File Content Invisibility Tool (AES-256-GCM)",
        epilog="Usage Examples:\n"
               "  1. Generate key:      python be.py -g\n"
               "  2. Encrypt content:   python be.py -e -k <KEY> -f report.txt script.py\n"
               "  3. Decrypt content:   python be.py -d -k <KEY> -f report.txt script.py",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('-g', '--generate-key', action='store_true', help='Generate a new secure encryption key')
    action.add_argument('-e', '--encrypt', action='store_true', help='Encrypt file content')
    action.add_argument('-d', '--decrypt', action='store_true', help='Decrypt file content')
    
    parser.add_argument('-k', '--key', type=str, help='AES-256 key string')
    parser.add_argument('-f', '--files', type=str, nargs='+', help='Target file path(s) to process')

    args = parser.parse_args()

    if args.generate_key:
        new_key = generate_key_string()
        print("\n" + "="*60)
        print("GENERATE KEY RESULT (Keep this out of the staging environment):")
        print(new_key)
        print("="*60 + "\n")
        return

    if (args.encrypt or args.decrypt) and not args.key:
        parser.error("[-] Cryptographic actions require a valid key via -k/--key.")
        
    if (args.encrypt or args.decrypt) and not args.files:
        parser.error("[-] Missing target files. Provide paths via -f/--files.")

    for file_path in args.files:
        if not os.path.exists(file_path):
            print(f"[-] Error: File path '{file_path}' does not exist. Skipping.")
            continue
            
        if args.encrypt:
            encrypt_content(file_path, args.key)
        elif args.decrypt:
            decrypt_content(file_path, args.key)

if __name__ == "__main__":
    main()
