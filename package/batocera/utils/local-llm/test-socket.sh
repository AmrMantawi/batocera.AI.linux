#!/bin/bash

# Test script for local-llm socket functionality
echo "=== Local LLM Socket Test ==="

# Check if service is running (systemd)
echo "1. Checking service status..."
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet local-llm.service; then
        echo "   ✅ Service is running"
    else
        echo "   ❌ Service is not running"
        echo "   Starting service..."
        systemctl start local-llm.service
        sleep 3
    fi
else
    echo "   ⚠️  systemctl not available; skipping service control"
fi

# Check if socket file exists
echo "2. Checking socket file..."
if [ -S /run/local-llm.sock ]; then
    echo "   ✅ Socket file exists: /run/local-llm.sock"
    ls -la /run/local-llm.sock
else
    echo "   ❌ Socket file not found"
    echo "   Checking service logs..."
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -u local-llm.service -n 50 --no-pager | cat
    else
        echo "   journalctl not available"
    fi
    exit 1
fi

# Check if process is running
echo "3. Checking process..."
PID=""
if command -v systemctl >/dev/null 2>&1; then
    PID=$(systemctl show -p MainPID --value local-llm.service 2>/dev/null)
fi
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
    # Fallback to pgrep
    PID=$(pgrep -f "/usr/bin/local-llm --mode server" | head -n1)
fi
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "   ✅ Process running (PID: $PID)"
    ps -p "$PID" -o pid,ppid,cmd
else
    echo "   ❌ Process not running"
    if command -v journalctl >/dev/null 2>&1; then
        echo "   Logs:"; journalctl -u local-llm.service -n 50 --no-pager | cat
    fi
    exit 1
fi

# Test socket connection
echo "4. Testing socket connection..."
if command -v nc >/dev/null 2>&1; then
    echo "   Testing with netcat..."
    echo "stream" | timeout 5 nc -U /run/local-llm.sock 2>&1 | head -c 100
    echo ""
elif command -v socat >/dev/null 2>&1; then
    echo "   Testing with socat..."
    echo "stream" | timeout 5 socat - UNIX-CONNECT:/run/local-llm.sock 2>&1 | head -c 100
    echo ""
else
    echo "   ⚠️  netcat/socat not available, skipping connection test"
fi

# Test with our socket client if available
echo "5. Testing with socket client utility..."
if [ -x /usr/bin/local-llm-socket-test ]; then
    echo "   Testing with local-llm-socket-test..."
    timeout 5 /usr/bin/local-llm-socket-test "test" 2>&1 | head -c 100
    echo ""
else
    echo "   ⚠️  Socket client utility not available"
fi

echo "=== Test Complete ==="
echo ""
echo "If all checks passed, the socket should be working."
echo "Check /userdata/system/logs/local-llm.log for detailed service logs."
