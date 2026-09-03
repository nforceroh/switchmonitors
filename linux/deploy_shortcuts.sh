#!/usr/bin/env bash
set -e

APP_DIR="$HOME/.local/share/applications"
SWITCH_SCRIPT="$HOME/repositories/switchmonitors/linux/switch_inputs.sh"
mkdir -p "$APP_DIR"

# Define the 3x3 Monitor Control Matrix: id -> "Printable Name|args|shortcut"
# Using Ctrl+Alt+Shift+F1-F9: real HID usage 0x3A-0x45, safely within this
# BLE keyboard library's current 0x00-0x65 report descriptor range (F13-F24
# would need a library patch - see keyboard.cpp comments on the firmware side).
declare -A script_matrix=(
    ["m1_dp"]="Monitor 1 DP|monitor1 DP|Ctrl+Alt+Shift+F1"
    ["m1_hdmi1"]="Monitor 1 HDMI1|monitor1 HDMI1|Ctrl+Alt+Shift+F2"
    ["m1_hdmi2"]="Monitor 1 HDMI2|monitor1 HDMI2|Ctrl+Alt+Shift+F3"
    ["m2_dp"]="Monitor 2 DP|monitor2 DP|Ctrl+Alt+Shift+F4"
    ["m2_hdmi1"]="Monitor 2 HDMI1|monitor2 HDMI1|Ctrl+Alt+Shift+F5"
    ["m2_hdmi2"]="Monitor 2 HDMI2|monitor2 HDMI2|Ctrl+Alt+Shift+F6"
    ["m3_dp"]="Monitor 3 DP|monitor3 DP|Ctrl+Alt+Shift+F7"
    ["m3_hdmi1"]="Monitor 3 HDMI1|monitor3 HDMI1|Ctrl+Alt+Shift+F8"
    ["m3_hdmi2"]="Monitor 3 HDMI2|monitor3 HDMI2|Ctrl+Alt+Shift+F9"
)

echo "⚙️  Building .desktop application descriptors..."
for id in "${!script_matrix[@]}"; do
    IFS='|' read -r printable_name argument_flags shortcut <<< "${script_matrix[$id]}"

    cat <<EOF > "$APP_DIR/switch_${id}.desktop"
[Desktop Entry]
Type=Application
Name=${printable_name}
Exec=bash -c "${SWITCH_SCRIPT} ${argument_flags}"
Terminal=false
Icon=video-display
Categories=Utility;
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF
    chmod +x "$APP_DIR/switch_${id}.desktop"
done

update-desktop-database "$APP_DIR"

echo "⌨️  Registering shortcuts in ~/.config/kglobalshortcutsrc..."
for id in "${!script_matrix[@]}"; do
    IFS='|' read -r printable_name _ shortcut <<< "${script_matrix[$id]}"

    # NOTE: _launch takes a single shortcut value on this system - NOT the
    # older 3-field "shortcut,default,friendly-name" comma format. Passing
    # embedded commas/spaces here gets misparsed as a KConfig list and
    # corrupts the value (confirmed by comparing against a working
    # manually-created shortcut, which stores just the bare key combo).
    kwriteconfig6 --file kglobalshortcutsrc \
        --group "services" --group "switch_${id}.desktop" \
        --key "_launch" "${shortcut}"
done

echo "🔄 Restarting kglobalaccel6..."
kquitapp6 kglobalaccel6 2>/dev/null || true
sleep 1
kstart6 kglobalaccel6 >/dev/null 2>&1 &
disown

echo "✅ Deployment complete. Check System Settings -> Shortcuts -> Applications."
echo "   If shortcuts don't show up, log out/in once to let kglobalaccel6 re-scan services."