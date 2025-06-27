#!/bin/bash
# USB Connection Test Script for reMarkable

echo "=== reMarkable USB Connection Debugger ==="
echo ""

# Find USB interface
USB_IF=$(ip link show | grep -E "enp[0-9]+s[0-9]+f[0-9]+u[0-9]+|usb[0-9]+|rndis[0-9]+" | cut -d: -f2 | tr -d ' ' | head -1)

if [ -z "$USB_IF" ]; then
    echo "❌ No USB network interface found"
    echo "Please ensure:"
    echo "  1. reMarkable is connected via USB"
    echo "  2. reMarkable is not in sleep mode"
    exit 1
fi

echo "✓ Found USB interface: $USB_IF"
echo ""

# Check interface status
echo "Interface Status:"
ip addr show "$USB_IF"
echo ""

# Try different IP configurations
echo "Testing different configurations..."
echo ""

# Test 1: Standard reMarkable USB IP
echo "Test 1: Standard config (10.11.99.2 → 10.11.99.1)"
sudo ip addr flush dev "$USB_IF" 2>/dev/null
sudo ip addr add 10.11.99.2/29 dev "$USB_IF" 2>/dev/null
sleep 1
if ping -c 1 -W 2 10.11.99.1 &>/dev/null; then
    echo "✅ SUCCESS! reMarkable found at 10.11.99.1"
    echo "You can now SSH: ssh root@10.11.99.1"
    exit 0
else
    echo "❌ No response at 10.11.99.1"
fi
echo ""

# Test 2: Try DHCP
echo "Test 2: Checking for DHCP..."
sudo ip addr flush dev "$USB_IF" 2>/dev/null
# Try to trigger DHCP manually
sudo ip link set "$USB_IF" down
sudo ip link set "$USB_IF" up
sleep 3

# Check if we got an IP
NEW_IP=$(ip addr show "$USB_IF" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ -n "$NEW_IP" ]; then
    echo "✅ Got IP via DHCP: $NEW_IP"
    # Try to find reMarkable
    SUBNET=$(echo "$NEW_IP" | cut -d. -f1-3)
    for i in 1 2 3 4 5; do
        if [ "$SUBNET.$i" != "$NEW_IP" ]; then
            if ping -c 1 -W 1 "$SUBNET.$i" &>/dev/null; then
                echo "✅ Found device at $SUBNET.$i"
                if timeout 2 ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@"$SUBNET.$i" "test -f /usr/bin/xochitl" 2>/dev/null; then
                    echo "✅ Confirmed reMarkable at $SUBNET.$i"
                    exit 0
                fi
            fi
        fi
    done
else
    echo "❌ No DHCP response"
fi
echo ""

# Test 3: Alternative subnet
echo "Test 3: Alternative config (192.168.2.2 → 192.168.2.1)"
sudo ip addr flush dev "$USB_IF" 2>/dev/null
sudo ip addr add 192.168.2.2/24 dev "$USB_IF" 2>/dev/null
sleep 1
if ping -c 1 -W 2 192.168.2.1 &>/dev/null; then
    echo "✅ SUCCESS! reMarkable found at 192.168.2.1"
    echo "You can now SSH: ssh root@192.168.2.1"
    exit 0
else
    echo "❌ No response at 192.168.2.1"
fi

echo ""
echo "=== Troubleshooting ==="
echo ""
echo "❌ Could not establish connection to reMarkable"
echo ""
echo "Please check:"
echo "1. reMarkable is connected and showing 'Connected' status"
echo "2. USB cable is working (try a different cable/port)"
echo "3. reMarkable is not in airplane mode"
echo "4. Try disconnecting and reconnecting the USB cable"
echo ""
echo "On your reMarkable:"
echo "- Swipe down from top"
echo "- Ensure you see the USB connected icon"
echo "- Try toggling airplane mode off/on"
echo ""
echo "Alternative: Use WiFi connection instead"