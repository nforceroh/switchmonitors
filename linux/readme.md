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

Save the script below as `deploy_shortcuts.sh` in the root of this repository, make it executable (`chmod +x deploy_shortcuts.sh`), and run it. 

This script automatically generates all nine structural `.desktop` app files, updates your operating system's desktop directory caching index, creates the `.lkshortcut` profile configuration snippet, and forces Plasma 6 to re-read the environment instantly.

```bash
#!/usr/bin/env bash
set -e

# Ensure clean drop-in paths exist
mkdir -p "\$HOME/.local/share/applications/"
mkdir -p "\$HOME/.config/kglobalshortcuts.d/"

# 1. Define the 3x3 Monitor Control Matrix
declare -A script_matrix=(
    ["m1_dp"]="Monitor 1 DP|monitor1 DP"
    ["m1_hdmi1"]="Monitor 1 HDMI1|monitor1 HDMI1"
    ["m1_hdmi2"]="Monitor 1 HDMI2|monitor1 HDMI2"
    ["m2_dp"]="Monitor 2 DP|monitor2 DP"
    ["m2_hdmi1"]="Monitor 2 HDMI1|monitor2 HDMI1"
    ["m2_hdmi2"]="Monitor 2 HDMI2|monitor2 HDMI2"
    ["m3_dp"]="Monitor 3 DP|monitor3 DP"
    ["m3_hdmi1"]="Monitor 3 HDMI1|monitor3 HDMI1"
    ["m3_hdmi2"]="Monitor 3 HDMI2|monitor3 HDMI2"
)

echo "⚙️ Building Application Descriptors..."
for id in "\${!script_matrix[@]}"; do
    IFS='|' read -r printable_name argument_flags <<< "\({script_matrix[\)id]}"
    
    cat <<EOF > "\(HOME/.local/share/applications/switch_\){id}.desktop"
[Desktop Entry]
Type=Application
Name=\${printable_name}
Exec=bash -c "\(HOME/repositories/switchmonitors/linux/switch_inputs.sh \){argument_flags}"
Terminal=false
Icon=video-display
Categories=Utility;
StartupNotify=false
EOF
    chmod +x "\(HOME/.local/share/applications/switch_\){id}.desktop"
done

# Clear and force the host operating system database layout to index entries
update-desktop-database "\$HOME/.local/share/applications/"

echo "⌨️ Writing Custom Key Layout Schemes..."
cat << 'EOF' > "\$HOME/.config/kglobalshortcuts.d/switchmonitors.lkshortcut"
[services][switch_m1_dp.desktop]
_launch=Ctrl+Alt+1

[services][switch_m1_hdmi1.desktop]
_launch=Ctrl+Alt+2

[services][switch_m1_hdmi2.desktop]
_launch=Ctrl+Alt+3

[services][switch_m2_dp.desktop]
_launch=Ctrl+Alt+4

[services][switch_m2_hdmi1.desktop]
_launch=Ctrl+Alt+5

[services][switch_m2_hdmi2.desktop]
_launch=Ctrl+Alt+6

[services][switch_m3_dp.desktop]
_launch=Ctrl+Alt+7

[services][switch_m3_hdmi1.desktop]
_launch=Ctrl+Alt+8

[services][switch_m3_hdmi2.desktop]
_launch=Ctrl+Alt+9
EOF

echo "🔄 Flushing Global Shortcut Daemons via D-Bus..."
# Forces the active Plasma 6 compositor engine to reload shortcut caches
qdbus org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reconfigure
kquitapp6 kglobalaccel && kstart6 kglobalaccel

echo "✅ Deployment Successful! Check System Settings -> Shortcuts -> Applications."
```

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
