#!/bin/bash

#--------------------------------#
#      ArkOS Dual SD Manager     #
#            By Jason            #
#--------------------------------#

# --- Vérification des privilèges root ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# --- Configuration des chemins ---
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CURR_TTY="/dev/tty1"
SD1_PART="/dev/mmcblk0p3"
SD2_PART="/dev/mmcblk1p1"
MNT_SD1="/mnt/sd1_internal"
MNT_SD2="/mnt/sd2_external"
FINAL_ROMS="/roms"
DAEMON_PATH="/usr/local/bin/arkos_sd_daemon.sh"
SERVICE_PATH="/etc/systemd/system/arkos_sd.service"
BACKTITLE="ArkOs Dual SD Manager - By Jason -"

# --- Préparation affichage ---
printf "\033c" > "$CURR_TTY"
printf "\e[?25l" > "$CURR_TTY"
dialog --clear

# --- FONT SELECTION ---
if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
else
    setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

pkill -9 -f gptokeyb || true
pkill -9 -f osk.py || true

# --- Animtion style Splash ---
printf "\033c" > "$CURR_TTY"

for i in {1..2}; do
    printf "Starting ArkOS Dual SD...\nPlease wait." > "$CURR_TTY"
    sleep 0.6
    printf "\033c" > "$CURR_TTY"
    sleep 0.4
done

# Message de bienvenue
printf "\033c" > "$CURR_TTY"
printf "\n\n" > "$CURR_TTY"
printf "      ========================================\n" > "$CURR_TTY"
printf "             Welcome to ArkOS Dual SD     \n" > "$CURR_TTY"
printf "                      By Jason                \n" > "$CURR_TTY"
printf "      ========================================\n" > "$CURR_TTY"
sleep 2

printf "\033c" > "$CURR_TTY"

# --- Fonction pour la progression ---
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

# --- Vérification du statut ---
is_active() {
    systemctl is-active --quiet arkos_sd.service
}

# --- Script de fond de tâche ---
create_daemon() {
    cat <<EOF > "$DAEMON_PATH"
#!/bin/bash

mkdir -p $MNT_SD1 $MNT_SD2
mount $SD1_PART $MNT_SD1 2>/dev/null

sync_saves() {
    if mountpoint -q $MNT_SD2; then
        # Fichiers de sauvegarde pris en charge (.srm, .state, .sav, .png, .cfg, .ini, .json, .dat, .bin, .save)
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
    
        # De SD2 vers SD1 
        rsync "\${sync_args[@]}" "$MNT_SD2/" "$MNT_SD1/"
        # De SD1 vers SD2 
        rsync "\${sync_args[@]}" "$MNT_SD1/" "$MNT_SD2/"
    fi
}

while true; do
    SD2_PRESENT=\$(lsblk | grep -c "mmcblk1p1")
    IS_MERGED=\$(mount | grep "mergerfs" | grep -c "$FINAL_ROMS")
    
    if [ "\$SD2_PRESENT" -eq 1 ]; then
        if [ "\$IS_MERGED" -eq 0 ]; then
            mount -o umask=000,uid=1000,gid=1000 $SD2_PART $MNT_SD2 2>/dev/null
    
            # Vérification des dossiers obligatoires pour activer la fusion            
            if [ -d "$MNT_SD2/tools" ] && [ -d "$MNT_SD2/themes" ]; then
                umount -l $FINAL_ROMS 2>/dev/null
                mergerfs -o allow_other,use_ino,dropcacheonclose=true,category.create=ff,fsname=mergerfs,defaults,nonempty $MNT_SD2:$MNT_SD1 $FINAL_ROMS
                systemctl restart emulationstation
            else
                # Si un dossiers est absents, on monte rien
                :
            fi
        fi

        if mountpoint -q $MNT_SD2; then
            sync_saves
        fi
    else
        # Si la SD2 est retirée    
        if [ "\$IS_MERGED" -eq 1 ]; then
            umount -l $FINAL_ROMS 2>/dev/null
            umount -l $MNT_SD2 2>/dev/null
            mount --bind $MNT_SD1 $FINAL_ROMS
            systemctl restart emulationstation
        fi
    fi
    
    if [ "\$SD2_PRESENT" -eq 0 ] && ! mount | grep -q "$FINAL_ROMS"; then
        mount --bind $MNT_SD1 $FINAL_ROMS
    fi
    
    sleep 10
done
EOF
    chmod +x "$DAEMON_PATH"
}

# --- Dépendances ---
Install_Manager() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        dialog --backtitle "$BACKTITLE" --title "Error" --msgbox "\nInternet connection required." 8 50 > "$CURR_TTY"
        return
    fi

    (
        smooth_progress "Updating package lists..." 0.05 0 20
        apt update -y >/dev/null 2>&1
        
        smooth_progress "Downloading and Installing dependencies..." 0.08 21 50
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
    ) | dialog --backtitle "$BACKTITLE" --title "Installing" --gauge "\nApplying changes..." 8 60 0 > "$CURR_TTY"

    dialog --backtitle "$BACKTITLE" --title "Installing" --msgbox "\nArkOs Dual SD is now installed and active." 8 50 > "$CURR_TTY"
}

# --- Désinstallation ---
Uninstall_Manager() {
    dialog --backtitle "$BACKTITLE" --title "Uninstalling" --yesno "\nUninstall ArkOs Dual SD?" 8 50 > "$CURR_TTY"
    [ $? -ne 0 ] && return

    (
        smooth_progress "Stopping service..." 0.04 0 40
        systemctl stop arkos_sd.service
        systemctl disable arkos_sd.service
        rm -f "$SERVICE_PATH" "$DAEMON_PATH"
        systemctl daemon-reload
        
        smooth_progress "Restoring original system..." 0.04 41 100
        umount -l "$FINAL_ROMS" 2>/dev/null
        mount "$SD1_PART" "$FINAL_ROMS" 2>/dev/null
    ) | dialog --backtitle "$BACKTITLE" --title "Uninstalling" --gauge "\nCleaning..." 8 60 0 > "$CURR_TTY"
}

Exit_Script() {
    printf "\033c" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb" || true
    exit 0
}

# --- Menu Principal ---
Main_Menu() {
    while true; do
        if is_active; then
            STATUS="\Z2ACTIVE\Zn"
        else
            STATUS="\Z1INACTIVE\Zn"
        fi

        selection=$(dialog --colors --backtitle "$BACKTITLE" --title " MAIN MENU " --cancel-label "Exit" \
        --menu "\nService Status: $STATUS\n\nSelect an option:" 16 55 5 \
        1 "Install ArkOS dual SD Manager" \
        2 "Uninstall ArkOS dual SD Manager" \
        3 "Restart Service" \
        4 "Exit" 2>&1 > "$CURR_TTY")

        [ $? -ne 0 ] && Exit_Script

        case $selection in
            1) Install_Manager ;;
            2) Uninstall_Manager ;;
            3) systemctl restart arkos_sd.service && dialog --infobox "\nService Restarted." 5 30 > "$CURR_TTY" && sleep 1 ;;
            4) Exit_Script ;;
        esac
    done
}

# --- Mapping des touches ---
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
/opt/inttools/gptokeyb -1 "$(basename "$0")" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

trap Exit_Script EXIT

# --- Lancement du script ---
Main_Menu