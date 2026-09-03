# SwitchMonitors - Linux Display Input Controller

A lightweight matrix controller utility that uses `ddcutil` to change hardware monitor inputs (HDMI/DisplayPort) directly from your keyboard or macropad. 

This repository includes a native configuration automation script tailored specifically for **KDE Plasma 6 (Fedora 44+) running on Wayland**.

---

## 🖥️ System Architecture Notes
Under **Wayland** and **KDE Plasma 6**, traditional real-time shortcut assignment scripts (like modifying `kglobalshortcutsrc` or calling legacy `khotkeys`) are blocked by memory-caching layers and strict security policies. 

To bypass this safely, this repository uses a two-stage native automation approach:
1. **Application Layering:** Registers your monitor switching actions as unhidden shell launchers (`.desktop` application frames) so the system compositor handles them with valid execution priorities.
2. **Shortcut Drop-ins (`.lkshortcut`):** Utilizes KDE's native configuration deployment matrix directory to append global hotkeys into active RAM. Because Plasma 6 uses an active memory cache, changes are securely forced into the compositor using modern D-Bus messaging lines.

---

## 🛠️ Requirements & Setup

### 1. Hardware Communication Permissions
Ensure your user account can talk directly to the monitor's I2C hardware buses without needing root privileges:

```bash
# Install the core utilities
sudo dnf install ddcutil

# Add user to the I2C group
sudo usermod -aG i2c \$USER
```
> **Important:** You must log out and log back into your session for these group changes to take effect.

---

## 🚀 Installation & Automation Script

Run the script `deploy_shortcuts.sh` in the linux folder of this repository (`linux/deploy_shortcuts.sh`), make it executable (`chmod +x linux/deploy_shortcuts.sh`), and run it.

This script automatically generates all nine structural `.desktop` app files, updates your operating system's desktop directory caching index, creates the `.lkshortcut` profile configuration snippet, and forces Plasma 6 to re-read the environment instantly.

---

## ⌨️ Coordinate Keymaps
To bypass Numpad state configuration locks and tracking bugs inside Wayland environment sessions, the system maps to standard numeric layout rows. If mapping to a dedicated macro macropad, bind your keys to output the standard combinations below:

* **Row 1:** `Ctrl + Alt + 7/8/9` ➔ **Monitor 3 Matrix** *(DP, HDMI1, HDMI2)*
* **Row 2:** `Ctrl + Alt + 4/5/6` ➔ **Monitor 2 Matrix** *(DP, HDMI1, HDMI2)*
* **Row 3:** `Ctrl + Alt + 1/2/3` ➔ **Monitor 1 Matrix** *(DP, HDMI1, HDMI2)*

---

## 🔍 Verification & Diagnostics
If shortcuts do not trigger immediately:
1. Open **System Settings** ➔ **Keyboard** ➔ **Shortcuts** and scroll down to the **Applications** block to confirm all entries appear with their assigned hotkeys.
2. Confirm script execution manually inside a bare console instance to verify your underlying hardware communication works:
   ```bash
   ~/repositories/switchmonitors/linux/switch_inputs.sh monitor1 DP
   ```
