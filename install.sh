#!/bin/bash
set -euo pipefail

echo "==> Adding Meshtastic APT repo"
echo 'deb http://download.opensuse.org/repositories/network:/Meshtastic:/beta/Raspbian_12/ /' | sudo tee /etc/apt/sources.list.d/network:Meshtastic:beta.list
curl -fsSL https://download.opensuse.org/repositories/network:Meshtastic:beta/Raspbian_12/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/network_Meshtastic_beta.gpg > /dev/null

echo "==> Installing meshtasticd and avahi-daemon"
sudo apt update
sudo apt install -y meshtasticd avahi-daemon

echo "==> Enabling SPI"
sudo raspi-config nonint set_config_var dtparam=spi on /boot/firmware/config.txt

echo "==> Fetching wlan0 MAC address"
MAC=$(cat /sys/class/net/wlan0/address)

echo "==> Writing /etc/meshtasticd/config.yaml"
sudo tee /etc/meshtasticd/config.yaml > /dev/null <<EOF
Lora:
  Module: sx1262
  CS: 21
  IRQ: 16
  Busy: 20
  Reset: 18
  TXen: 13
  RXen: 12
  DIO3_TCXO_VOLTAGE: true

GPS:

I2C:
  I2CDevice: /dev/i2c-1

Logging:
  LogLevel: info # debug, info, warn, error

Webserver:
  # Port: 443 # Port for Webserver & Webservices
  # RootPath: /usr/share/meshtasticd/web # Root Dir of WebServer

General:
  MaxNodes: 200
  MACAddress: $MAC
EOF

echo "==> Creating Avahi service at /etc/avahi/services/meshtastic.service"
sudo mkdir -p /etc/avahi/services
sudo tee /etc/avahi/services/meshtastic.service > /dev/null <<EOF
<?xml version="1.0" standalone="no"?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
    <name>Meshtastic</name>
    <service protocol="ipv4">
        <type>_meshtastic._tcp</type>
        <port>4403</port>
    </service>
</service-group>
EOF

echo "==> Replacing /boot/firmware/config.txt"
sudo tee /boot/firmware/config.txt > /dev/null <<'EOF'
# For more options and information see
# http://rptl.io/configtxt
# Some settings may impact device functionality. See link above for details

# Uncomment some or all of these to enable the optional hardware interfaces
dtparam=i2c_arm=on
#dtparam=i2s=on
dtparam=spi=on
dtoverlay=spi0-0cs

dtoverlay=disable-bt
hdmi_blanking=2
hdmi_force_hotplug=0
arm_freq=600
gpu_mem=16
dtparam=act_led_trigger=none
dtparam=act_led_activelow=on
# Enable audio (loads snd_bcm2835)
dtparam=audio=off
# Automatically load overlays for detected cameras
camera_auto_detect=0
# Automatically load overlays for detected DSI displays
display_auto_detect=0
# Enable DRM VC4 V3D driver
#dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Additional overlays and parameters are documented
# /boot/firmware/overlays/README

# Automatically load initramfs files, if found
auto_initramfs=1

# Don't have the firmware create an initial video= setting in cmdline.txt.
# Use the kernel's default instead.
disable_fw_kms_setup=1

# Run in 64-bit mode
arm_64bit=1

# Disable compensation for displays with overscan
disable_overscan=1

# Run as fast as firmware / board allows
arm_boost=1

[cm4]
# Enable host mode on the 2711 built-in XHCI USB controller.
# This line should be removed if the legacy DWC2 controller is required
# (e.g. for USB device mode) or if USB support is not required.
otg_mode=1

[cm5]
dtoverlay=dwc2,dr_mode=host

[all]
EOF

echo "==> Update /boot/firmware/cmdline.txt"
sudo sed -i 's/\(.*\)\(rootwait\)/\1maxcpus=1 \2/' /boot/firmware/cmdline.txt

echo "==> Creating disable_wifi_if_unconnected.sh script"
sudo tee /usr/local/bin/disable_wifi_if_unconnected.sh > /dev/null <<'EOF'
#!/bin/bash

# Enable WiFi
rfkill unblock wifi
wpa_cli -i wlan0 reconfigure

# Wait 2-min for it to connect
sleep 120

# Check if wlan0 has an IP address
if ! ip addr show wlan0 | grep -q "inet "; then
    echo "No Wi-Fi connection found, disabling Wi-Fi to save power"
    rfkill block wifi
fi
EOF

echo "==> Making the script executable"
sudo chmod +x /usr/local/bin/disable_wifi_if_unconnected.sh

echo "==> Creating systemd service to disable Wi-Fi if unconnected"
sudo tee /etc/systemd/system/disable-wifi-if-unconnected.service > /dev/null <<EOF
[Unit]
Description=Disable Wi-Fi if not connected
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disable_wifi_if_unconnected.sh

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling and starting services"
sudo systemctl enable disable-wifi-if-unconnected.service
sudo vcgencmd display_power 0
sudo systemctl disable hciuart
sudo systemctl stop hciuart
sudo systemctl enable meshtasticd
sudo systemctl start meshtasticd

echo "==> Installation complete. You should reboot now."
