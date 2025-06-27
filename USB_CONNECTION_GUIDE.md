# reMarkable USB Connection Guide

## Quick Fix

When your reMarkable is connected via USB, use IP address: **10.11.99.1**

```bash
# Test the connection
ssh root@10.11.99.1
```

## If That Doesn't Work

### Option 1: Manual IP Configuration (Temporary)
```bash
# Add IP address to your USB interface
sudo ip addr add 10.11.99.2/29 dev enp4s0f3u1u2

# Test connection
ssh root@10.11.99.1
```

### Option 2: NetworkManager Configuration (Permanent)
```bash
# Create a connection profile for reMarkable
nmcli con add type ethernet \
  con-name remarkable \
  ifname enp4s0f3u1u2 \
  ipv4.method manual \
  ipv4.addresses 10.11.99.2/29 \
  ipv4.gateway 10.11.99.1

# Activate it
nmcli con up remarkable
```

### Option 3: Use WiFi Instead
1. Connect your reMarkable to WiFi
2. Find its IP in Settings → Help → Copyrights and licenses
3. Use that IP address in the installer

## Running the Installer with USB

Once connected, run:
```bash
./remote_install.sh
# When prompted for IP, enter: 10.11.99.1
```

## Troubleshooting

1. **Check if reMarkable is in USB mode:**
   - Should show "Connected" on the reMarkable screen
   - USB icon should be visible

2. **Verify interface is up:**
   ```bash
   ip link show enp4s0f3u1u2
   ```

3. **Check route:**
   ```bash
   ip route | grep 10.11.99
   ```

4. **Try different USB ports/cables**

## Common Issues on Steam Deck

The Steam Deck's NetworkManager might need the manual configuration (Option 2) for consistent USB networking with the reMarkable.