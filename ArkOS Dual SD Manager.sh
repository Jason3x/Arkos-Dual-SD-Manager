#!/bin/bash

#--------------------------------#
#      ArkOS Dual SD Manager     #
#            By Jason            #
#    No autosync mod by 1sTheCat #
#--------------------------------#

# --- Root privilege check ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# --- Path configuration ---
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CURR_TTY="/dev/tty1"
SD1_PART="/dev/mmcblk0p3"
SD2_PART="/dev/mmcblk1p1"
MNT_SD1="/mnt/sd1_internal"
MNT_SD2="/mnt/sd2_external"
FINAL_ROMS="/roms"
DAEMON_PATH="/usr/local/bin/arkos_sd_daemon.sh"
SERVICE_PATH="/etc/systemd/system/arkos_sd.service"
SYNC_FLAG="/etc/arkos_sd_sync_enabled"
BACKTITLE="ArkOs Dual SD Manager - By Jason - No autosync mod by 1sTheCat"

# --- Display setup ---
printf "\\033c" > "$CURR_TTY"
printf "\\e[?25l" > "$CURR_TTY"
dialog --clear

# --- Font selection ---
if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
else
    setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

pkill -9 -f gptokeyb || true
pkill -9 -f osk.py || true

# --- Splash animation ---
printf "\\033c" > "$CURR_TTY"
for i in {1..2}; do
    printf "Starting ArkOS Dual SD...\\nPlease wait." > "$CURR_TTY"
    sleep 0.6
    printf "\\033c" > "$CURR_TTY"
    sleep 0.4
done

printf "\\033c" > "$CURR_TTY"
printf "\\n\\n" > "$CURR_TTY"
printf "      ========================================\\n" > "$CURR_TTY"
printf "             Welcome to ArkOS Dual SD     \\n" > "$CURR_TTY"
printf "      By Jason, No autosync mod by 1sTheCat \\n" > "$CURR_TTY"
printf "      ========================================\\n" > "$CURR_TTY"
sleep 2
printf "\\033c" > "$CURR_TTY"

# --- Progress function ---
smooth_progress() {
    local msg=$1
    local delay=$2
    local start_val=$3
    local end_val=$4
    for ((i=start_val; i<=end_val; i++)); do
        echo "$i"
        echo "XXX"; echo -e "$msg"; echo "XXX"
        sleep "$delay"
    done
}

# --- Service status check ---
is_active() {
    systemctl is-active --quiet arkos_sd.service
}

# --- Sync status check ---
is_sync_enabled() {
    [ -f "$SYNC_FLAG" ]
}

# --- Create background daemon ---
create_daemon() {
    cat <<EOF > "$DAEMON_PATH"
#!/bin/bash

# --- Path configuration ---
ES_CONFIG_DIR="/home/ark/.emulationstation"
ES_SETTINGS="\$ES_CONFIG_DIR/es_settings.cfg"
ES_SETTINGS_BAK="/home/ark/es_settings_factory.cfg"
THEMES_LOCAL_DIR="$MNT_SD1/themes"
THEMES_LIST_TMP="/home/ark/original_themes_list.txt"
SYNC_FLAG="$SYNC_FLAG"

# State tracking flags to prevent duplicate events
SD2_WAS_PRESENT=0
ES_RESTARTED_FOR_SD2=0

# Ensure mount points exist
mkdir -p "$MNT_SD1" "$MNT_SD2"

# Initial SD1 mount
if ! mountpoint -q "$MNT_SD1"; then
    mount "$SD1_PART" "$MNT_SD1" 2>/dev/null
fi

# If SD2 is absent at boot, update reference backup
if [ ! -b "/dev/mmcblk1p1" ]; then
    [ -f "\$ES_SETTINGS" ] && cp "\$ES_SETTINGS" "\$ES_SETTINGS_BAK"
    ls -1 "\$THEMES_LOCAL_DIR" 2>/dev/null > "\$THEMES_LIST_TMP"
    echo "SD1 reference updated" > /tmp/sync_status.log
else
    SD2_WAS_PRESENT=1
    if [ ! -f "\$ES_SETTINGS_BAK" ]; then
        cp "\$ES_SETTINGS" "\$ES_SETTINGS_BAK"
    fi
    if [ ! -f "\$THEMES_LIST_TMP" ]; then
        ls -1 "\$THEMES_LOCAL_DIR" 2>/dev/null > "\$THEMES_LIST_TMP"
    fi
    echo "Started with SD2: using existing reference" > /tmp/sync_status.log
fi

# --- Wait until a mount point is stable ---
wait_for_mount() {
    local target="\$1"
    local retries=10
    local count=0
    while ! mountpoint -q "\$target"; do
        sleep 1
        count=\$((count + 1))
        [ "\$count" -ge "\$retries" ] && return 1
    done
    return 0
}

# --- Save sync function ---
sync_saves() {
    if mountpoint -q "$MNT_SD2"; then
        local sync_args=(
            -rtu
            --include="*/"
            --include="*.srm"
            --include="*.state*"
            --include="*.sav"
            --include="*.png"
            --include="*.cfg"
            --include="*.ini"
            --include="*.json"
            --include="*.dat"
            --include="*.bin"
            --include="*.save"
            --include="*save*/**"
            --include="*Save*/**"
            --exclude="*"
        )
        # SD2 to SD1
        rsync "\${sync_args[@]}" "$MNT_SD2/" "$MNT_SD1/"
        # SD1 to SD2
        rsync "\${sync_args[@]}" "$MNT_SD1/" "$MNT_SD2/"
        echo "Sync completed: \$(date)" >> /tmp/sync_status.log
    fi
}

while true; do
    if [ -b "/dev/mmcblk1p1" ]; then
        SD2_PRESENT=1
    else
        SD2_PRESENT=0
    fi

    IS_MERGED=\$(mount | grep "mergerfs" | grep -c "$FINAL_ROMS")

    if [ "\$SD2_PRESENT" -eq 1 ]; then
        if [ "\$IS_MERGED" -eq 0 ]; then
            # Mount SD2
            mount -o umask=000,uid=1000,gid=1000 "$SD2_PART" "$MNT_SD2" 2>/dev/null

            # Check required folders before activating merge
            if [ -d "$MNT_SD2/tools" ] && [ -d "$MNT_SD2/themes" ]; then
                # MergerFS merge
                umount -l "$FINAL_ROMS" 2>/dev/null
                mergerfs -o allow_other,use_ino,dropcacheonclose=true,category.create=ff,fsname=mergerfs,defaults,nonempty "$MNT_SD2:$MNT_SD1" "$FINAL_ROMS"

                chmod +x "$FINAL_ROMS"/tools/*.sh 2>/dev/null

                if [ -d "/opt/system/Tools" ]; then
                    umount -l /opt/system/Tools 2>/dev/null
                    mount --bind "$FINAL_ROMS/tools" /opt/system/Tools 2>/dev/null
                fi

                # Wait for all mounts to stabilize before restarting ES
                wait_for_mount "$FINAL_ROMS"
                wait_for_mount "$MNT_SD2"
                sleep 3

                # Restart ES only once per SD2 insertion event
                if [ "\$ES_RESTARTED_FOR_SD2" -eq 0 ]; then
                    systemctl restart emulationstation
                    ES_RESTARTED_FOR_SD2=1
                fi

                # Sync only if flag is active
                if [ -f "\$SYNC_FLAG" ]; then
                    sync_saves &
                fi
            fi
        fi

        SD2_WAS_PRESENT=1

    else
        # SD2 was removed
        if [ "\$IS_MERGED" -eq 1 ]; then
            umount -l /opt/system/Tools 2>/dev/null
            umount -l "$FINAL_ROMS" 2>/dev/null
            umount -l "$MNT_SD2" 2>/dev/null

            # Remount SD1 only
            mount --bind "$MNT_SD1" "$FINAL_ROMS"

            if [ -d "/opt/system/Tools" ]; then
                mount --bind "$FINAL_ROMS/tools" /opt/system/Tools 2>/dev/null
            fi

            # Restore original theme settings
            if [ -f "\$ES_SETTINGS_BAK" ]; then
                cp "\$ES_SETTINGS_BAK" "\$ES_SETTINGS"
            fi

            # Clean orphaned themes from SD1
            if [ -f "\$THEMES_LIST_TMP" ]; then
                for theme_dir in "\$THEMES_LOCAL_DIR"/*/; do
                    [ -e "\$theme_dir" ] || continue
                    theme_name=\$(basename "\$theme_dir")
                    if ! grep -qx "\$theme_name" "\$THEMES_LIST_TMP"; then
                        rm -rf "\$theme_dir"
                    fi
                done
            fi

            # Wait for SD1 remount to stabilize before restarting ES
            wait_for_mount "$FINAL_ROMS"
            sleep 3
            systemctl restart emulationstation
        fi

        # Reset restart flag when SD2 is gone
        ES_RESTARTED_FOR_SD2=0
        SD2_WAS_PRESENT=0
    fi

    # Safety: boot without SD2
    if [ "\$SD2_PRESENT" -eq 0 ] && ! mountpoint -q "$FINAL_ROMS"; then
        mount --bind "$MNT_SD1" "$FINAL_ROMS"
        if [ -d "/opt/system/Tools" ] && ! mountpoint -q /opt/system/Tools; then
            mount --bind "$FINAL_ROMS/tools" /opt/system/Tools 2>/dev/null
        fi
    fi

    sleep 5
done
EOF
    chmod +x "$DAEMON_PATH"
}

# --- Install dependencies ---
Install_Manager() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        dialog --backtitle "$BACKTITLE" --title "Error" --msgbox "\\nInternet connection required." 8 50 > "$CURR_TTY"
        return
    fi

    (
        smooth_progress "Updating package lists..." 0.05 0 20
        apt update -y >/dev/null 2>&1

        smooth_progress "Installing dependencies (mergerfs, rsync)..." 0.08 21 50
        apt install mergerfs rsync -y >/dev/null 2>&1

        smooth_progress "Creating background script..." 0.03 51 70
        create_daemon

        smooth_progress "Configuring services..." 0.03 71 90
        cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=ArkOs Dual SD
After=multi-user.target

[Service]
Type=simple
ExecStart=$DAEMON_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable arkos_sd.service
        systemctl start arkos_sd.service

        smooth_progress "Finalizing..." 0.02 91 100
    ) | dialog --backtitle "$BACKTITLE" --title "Installing" --gauge "\\nApplying changes..." 8 60 0 > "$CURR_TTY"

    dialog --backtitle "$BACKTITLE" --title "Installed" --msgbox "\\nArkOs Dual SD is now installed and active.\\nSave sync: DISABLED by default.\\nUse the menu to enable it." 10 55 > "$CURR_TTY"
}

# --- Uninstall ---
Uninstall_Manager() {
    dialog --backtitle "$BACKTITLE" --title "Uninstall" --yesno "\\nUninstall ArkOs Dual SD?" 8 50 > "$CURR_TTY"
    [ $? -ne 0 ] && return

    (
        smooth_progress "Stopping service..." 0.04 0 40
        systemctl stop arkos_sd.service
        systemctl disable arkos_sd.service
        rm -f "$SERVICE_PATH" "$DAEMON_PATH" "$SYNC_FLAG"
        systemctl daemon-reload

        smooth_progress "Restoring original system..." 0.04 41 100
        umount -l "$FINAL_ROMS" 2>/dev/null
        mount "$SD1_PART" "$FINAL_ROMS" 2>/dev/null
    ) | dialog --backtitle "$BACKTITLE" --title "Uninstalling" --gauge "\\nCleaning..." 8 60 0 > "$CURR_TTY"

    dialog --backtitle "$BACKTITLE" --title "Uninstalled" --msgbox "\\nArkOs Dual SD has been removed successfully." 8 55 > "$CURR_TTY"
}

# --- Save sync toggle ---
Toggle_Sync() {
    if is_sync_enabled; then
        dialog --backtitle "$BACKTITLE" --title "Save Sync" \
            --yesno "\\nSave sync is currently ENABLED.\\n\\nDo you want to DISABLE automatic save sync?" \
            10 58 > "$CURR_TTY"
        if [ $? -eq 0 ]; then
            rm -f "$SYNC_FLAG"
            dialog --backtitle "$BACKTITLE" --title "Save Sync" \
                --infobox "\\nSave sync DISABLED.\\nMerge is still active." \
                7 50 > "$CURR_TTY"
            sleep 2
        fi
    else
        dialog --backtitle "$BACKTITLE" --title "Save Sync" \
            --yesno "\\nSave sync is currently DISABLED.\\n\\nDo you want to ENABLE automatic save sync?\\n\\n(Only .srm, .state, .sav, etc. will be synced)" \
            12 60 > "$CURR_TTY"
        if [ $? -eq 0 ]; then
            touch "$SYNC_FLAG"
            dialog --backtitle "$BACKTITLE" --title "Save Sync" \
                --infobox "\\nSave sync ENABLED.\\nSaves will be synced between SD1 and SD2." \
                7 55 > "$CURR_TTY"
            sleep 2
        fi
    fi
}

# --- Manual sync ---
Manual_Sync() {
    if ! is_active; then
        dialog --backtitle "$BACKTITLE" --title "Error" \
            --msgbox "\\nArkOS Dual SD service is not running.\\nPlease install it first." 8 55 > "$CURR_TTY"
        return
    fi

    if ! mountpoint -q "$MNT_SD2"; then
        dialog --backtitle "$BACKTITLE" --title "Error" \
            --msgbox "\\nSD2 is not mounted.\\nMake sure the second SD card is inserted." 8 55 > "$CURR_TTY"
        return
    fi

    dialog --backtitle "$BACKTITLE" --title "Manual Sync" \
        --yesno "\\nRun save sync now?\\n\\n(SD1 <-> SD2: .srm, .state, .sav, etc.)" \
        10 55 > "$CURR_TTY"
    [ $? -ne 0 ] && return

    (
        smooth_progress "Syncing saves SD2 -> SD1..." 0.05 0 45
        rsync -rtu \
            --include="*/" \
            --include="*.srm" --include="*.state*" --include="*.sav" \
            --include="*.png" --include="*.cfg" --include="*.ini" \
            --include="*.json" --include="*.dat" --include="*.bin" \
            --include="*.save" --include="*save*/**" --include="*Save*/**" \
            --exclude="*" \
            "$MNT_SD2/" "$MNT_SD1/" >/dev/null 2>&1

        smooth_progress "Syncing saves SD1 -> SD2..." 0.05 46 90
        rsync -rtu \
            --include="*/" \
            --include="*.srm" --include="*.state*" --include="*.sav" \
            --include="*.png" --include="*.cfg" --include="*.ini" \
            --include="*.json" --include="*.dat" --include="*.bin" \
            --include="*.save" --include="*save*/**" --include="*Save*/**" \
            --exclude="*" \
            "$MNT_SD1/" "$MNT_SD2/" >/dev/null 2>&1

        smooth_progress "Finishing..." 0.02 91 100
    ) | dialog --backtitle "$BACKTITLE" --title "Syncing Saves" --gauge "\\nPlease wait..." 8 60 0 > "$CURR_TTY"

    echo "Manual sync completed: $(date)" >> /tmp/sync_status.log
    dialog --backtitle "$BACKTITLE" --title "Done" \
        --msgbox "\\nSave sync completed successfully!" 7 50 > "$CURR_TTY"
}

Exit_Script() {
    printf "\\033c" > "$CURR_TTY"
    printf "\\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb" || true
    exit 0
}

# --- Main Menu ---
Main_Menu() {
    while true; do
        if is_active; then
            STATUS="\\Z2ACTIVE\\Zn"
        else
            STATUS="\\Z1INACTIVE\\Zn"
        fi

        if is_sync_enabled; then
            SYNC_STATUS="\\Z2ENABLED\\Zn"
            SYNC_LABEL="Disable Save Sync"
        else
            SYNC_STATUS="\\Z1DISABLED\\Zn"
            SYNC_LABEL="Enable Save Sync"
        fi

        selection=$(dialog --colors --backtitle "$BACKTITLE" --title " MAIN MENU " --cancel-label "Exit" \
        --menu "\\nService: $STATUS  |  Save Sync: $SYNC_STATUS\\n\\nSelect an option:" 18 60 7 \
        1 "Install ArkOS Dual SD Manager" \
        2 "Uninstall ArkOS Dual SD Manager" \
        3 "Restart Service" \
        4 "$SYNC_LABEL" \
        5 "Manual Save Sync (run now)" \
        6 "Exit" 2>&1 > "$CURR_TTY")

        [ $? -ne 0 ] && Exit_Script

        case $selection in
            1) Install_Manager ;;
            2) Uninstall_Manager ;;
            3) systemctl restart arkos_sd.service && dialog --infobox "\\nService restarted." 5 30 > "$CURR_TTY" && sleep 1 ;;
            4) Toggle_Sync ;;
            5) Manual_Sync ;;
            6) Exit_Script ;;
        esac
    done
}

# --- Controller button mapping ---
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
/opt/inttools/gptokeyb -1 "$(basename "$0")" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

trap Exit_Script EXIT

# --- Launch ---
Main_Menu
