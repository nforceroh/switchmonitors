# SwitchMonitors - Linux Display Input Controller

A lightweight matrix controller utility that uses `ddcutil` to change hardware monitor inputs (HDMI/DisplayPort) directly from your keyboard or macropad.

This repository includes a native configuration automation script tailored specifically for **KDE Plasma 6 (Fedora 44+) running on Wayland**.

---

## 🖥️ System Architecture Notes

Global shortcuts on Plasma 6 are managed by `kglobalaccel6`, a background service that reads and writes a single config file: `~/.config/kglobalshortcutsrc`. There is no separate drop-in directory or `.lkshortcut` format — every shortcut, whether created by hand or through System Settings, lives in that one file.

For a plain shell command bound to a hotkey (rather than a full running application), two things have to line up:

1. **A `.desktop` launcher** in `~/.local/share/applications/`, describing what to run. Crucially, it needs `X-KDE-GlobalAccel-CommandShortcut=true` — without this flag, `kglobalaccel6` can bind and *display* the shortcut correctly in System Settings, but has no mechanism to actually execute it on keypress.
2. **A matching entry in `kglobalshortcutsrc`**, under `[services][<desktopfile>]`, with a key `_launch=<shortcut>`. On this system, that value is a **single key-combo string** — not the older multi-field `shortcut,default,friendly-name` comma format some documentation still shows. Writing a comma-containing value causes KConfig to misparse it as a list and corrupt the entry (symptom: the shortcut shows correctly in System Settings, but silently does nothing when pressed, and the raw config value ends with a stray `\s`).

After writing shortcuts directly to `kglobalshortcutsrc` (as this script does), `kglobalaccel6` needs to reload that file — either via a full logout/login, or by restarting the daemon itself, which the deploy script does automatically.

---

## 🛠️ Requirements & Setup

### 1. Hardware Communication Permissions

Ensure your user account can talk directly to the monitor's I2C hardware buses without needing root privileges:

```bash
# Install the core utilities
sudo dnf install ddcutil

# Add user to the I2C group
sudo usermod -aG i2c $USER
```

> **Important:** You must log out and log back into your session for these group changes to take effect.

### 2. Identify your monitors by serial number

`ddcutil` assigns I2C bus numbers by detection order, which **can shift** after a reboot, cable replug, or input source change — a monitor that was `/dev/i2c-9` yesterday might be `/dev/i2c-10` today. To avoid shortcuts silently pointing at the wrong screen, `switch_inputs.sh` identifies each monitor by its **serial number** (or binary serial, for panels that report a blank string serial) and resolves the current bus at runtime.

Find your monitors' identities:

```bash
ddcutil detect --verbose | egrep -i "^Display|Model|I2C bus|Serial number|Binary serial"
```

Update the `MONITOR_SERIAL` map at the top of `switch_inputs.sh` with the serial (or binary serial hex) for each monitor you care about. This only needs to be done once per physical monitor — it doesn't need updating even if bus numbers shuffle later.

---

## 🚀 Installation & Automation Script

Run the script `deploy_shortcuts.sh` in the linux folder of this repository (`linux/deploy_shortcuts.sh`), make it executable (`chmod +x linux/deploy_shortcuts.sh`), and run it.

This script:
- Generates nine `.desktop` launcher files (one per monitor/input combination), each marked as a command shortcut so `kglobalaccel6` knows to execute it directly.
- Registers a global shortcut for each one directly in `~/.config/kglobalshortcutsrc`.
- Restarts `kglobalaccel6` so the new bindings take effect without requiring a full logout.

To re-apply after editing the key matrix or monitor serials, just re-run the script — it's safe to run repeatedly.

---

## ⌨️ Keymaps

Shortcuts use **`Ctrl+Alt+Shift+F1`–`F9`**, not numpad digits or top-row number keys. This is deliberate:

- **Numpad digits are Num Lock–dependent.** With Num Lock off, a numpad key sends a navigation keysym (e.g. `KP_End`) instead of a digit, silently breaking the binding. This bit us during setup — shortcuts that worked one day stopped the next with no config change, purely because Num Lock state changed.
- **Top-row digits collide easily** with terminal multiplexers, virtual console switching, and various app shortcuts.
- **F13–F24** would be the cleanest choice (virtually never claimed by any OS/app by default), but many BLE keyboard libraries — including the one used by this project's companion macropad firmware — declare a HID report descriptor capped at usage `0x65`, one below F13's usage code (`0x68`). F13+ would need a firmware/library patch to work over BLE; F1–F12 (`0x3A`–`0x45`) sit safely inside the existing range.

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+Shift+F1` | Monitor 1 → DP |
| `Ctrl+Alt+Shift+F2` | Monitor 1 → HDMI1 |
| `Ctrl+Alt+Shift+F3` | Monitor 1 → HDMI2 |
| `Ctrl+Alt+Shift+F4` | Monitor 2 → DP |
| `Ctrl+Alt+Shift+F5` | Monitor 2 → HDMI1 |
| `Ctrl+Alt+Shift+F6` | Monitor 2 → HDMI2 |
| `Ctrl+Alt+Shift+F7` | Monitor 3 → DP |
| `Ctrl+Alt+Shift+F8` | Monitor 3 → HDMI1 |
| `Ctrl+Alt+Shift+F9` | Monitor 3 → HDMI2 |

If you're driving these from a BLE macropad, make sure its firmware's key-name parser actually supports the F-key range you're using — a mapper that only recognizes one hardcoded function key (e.g. only `KEY_F8`) will silently drop unrecognized key names rather than erroring, which looks identical to a KDE-side binding problem.

---

## 🔍 Verification & Diagnostics

Work through these in order — each one isolates a different layer, from hardware up to the shortcut binding:

1. **Run the switching script directly**, bypassing everything else:
   ```bash
   ~/repositories/switchmonitors/linux/switch_inputs.sh monitor1 DP
   ```
   If this doesn't switch the monitor, the problem is in `ddcutil`/monitor identification, not shortcuts.

2. **Launch the generated `.desktop` file directly**, bypassing the keyboard shortcut layer:
   ```bash
   gio launch ~/.local/share/applications/switch_m1_dp.desktop
   ```
   If this works but the keyboard shortcut doesn't, the problem is in the `kglobalshortcutsrc` binding, not the script or `.desktop` file.

3. **Confirm the physical keypress reaches the kernel correctly** (especially relevant for BLE macropads):
   ```bash
   sudo evtest
   ```
   Pick your keyboard device, press the macro button, and confirm you see the expected modifier and F-key codes (e.g. `KEY_LEFTCTRL`, `KEY_LEFTALT`, `KEY_LEFTSHIFT`, `KEY_F1`). No F-key event at all usually means the sending device (firmware) isn't mapping that key name — not a KDE-side issue.

4. **Check the shortcut is bound cleanly with no corruption**:
   ```bash
   grep -A1 "switch_m1_dp.desktop" ~/.config/kglobalshortcutsrc
   ```
   You want to see exactly one line: `_launch=Ctrl+Alt+Shift+F1`. If you see extra comma-separated fields or a trailing `\s`, the entry is corrupted (see Architecture Notes above) — clear it and re-run `deploy_shortcuts.sh`.

5. **Check System Settings → Shortcuts → Applications** to confirm each `Monitor X` entry shows the expected hotkey with no conflicts.

6. **Watch the system log while pressing the shortcut**:
   ```bash
   journalctl -f
   ```
   Silence here alongside a correctly-displayed binding usually points at a corrupted `_launch` value (step 4) or a missing `X-KDE-GlobalAccel-CommandShortcut=true` flag in the `.desktop` file.