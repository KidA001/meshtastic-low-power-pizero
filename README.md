# Meshtastic Pi Install
Made for installing Meshtastic on a PiZero 2W and making it as low power as possible

- Headless operation (no display, HDMI Disabled, no UI overhead)
- Bluetooth Disabled
- Minimal peripherals (only SPI/I2C for sensor modules)
- Conditional Wi-Fi (Wi-Fi off unless network is available)
- Downclocked & lean (single core, slow CPU, tiny GPU memory)
- Audio disabled
- Silent & dim (no sound, LED off)

## To Install
From your Pi Command Line run:

```bash
wget -qO - https://raw.githubusercontent.com/KidA001/meshtastic-low-power-pizero/main/install.sh | sudo bash
```
