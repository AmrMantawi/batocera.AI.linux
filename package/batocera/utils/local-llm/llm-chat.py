#!/usr/bin/env python3
import socket
import json
import sys

SOCKET_PATH = "/tmp/local-llm.sock"

voice = "--voice" in sys.argv

print(f"Connected. Voice: {'on' if voice else 'off'}. Ctrl+C to quit.\n")
try:
    while True:
        line = input("> ")
        if not line.strip():
            continue
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        msg = {"prompt": line}
        if voice:
            msg["voice"] = True
        s.send((json.dumps(msg) + "\n").encode())
        s.settimeout(30)
        try:
            while True:
                data = s.recv(4096)
                if not data:
                    break
                print(data.decode(), end="", flush=True)
        except socket.timeout:
            pass
        s.close()
        print()
except (KeyboardInterrupt, EOFError):
    print("\nBye.")
