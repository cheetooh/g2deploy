#!/bin/bash

set -e

STEP_FILE="/var/tmp/new_machine_install_progress"
LOG_FILE="/var/tmp/new_machine_install.log"
STEP3_PROXY_IP=""

# Handle --force flag
if [[ "$1" == "--force" ]]; then
    echo "⚠️  Force mode: clearing previous progress."
    sudo rm -f "$STEP_FILE"
    sudo rm -f "$LOG_FILE"
fi

touch "$STEP_FILE"
touch "$LOG_FILE"

# Redirect all output to log file using tee
exec > >(tee -a "$LOG_FILE") 2>&1

echo "📘 Starting setup script at $(date)"

prompt_or_auto_yes() {
    local question="$1"
    local timeout=10
    echo -n "$question [Y/n] (auto-yes in $timeout sec): "
    read -t $timeout answer
    answer=${answer:-Y}
    echo "$question -> ${answer}" >> "$LOG_FILE"
    [[ "$answer" =~ ^[Yy]$ ]]
}

has_run() {
    grep -q "^$1\$" "$STEP_FILE"
}

mark_done() {
    echo "$1" >> "$STEP_FILE"
}

# --------------------
# STEP 1: Set timezone
# --------------------
if ! has_run "step1"; then
    if prompt_or_auto_yes "Step 1: Set timezone?"; then
        read -p "Enter timezone (e.g., Asia/Kuala_Lumpur) or leave empty to use default: " TZ_INPUT
        TZ=${TZ_INPUT:-Asia/Kuala_Lumpur}
        if timedatectl list-timezones | grep -q "^$TZ$"; then
            sudo timedatectl set-timezone "$TZ"
            echo "Timezone set to $TZ."
        else
            echo "⚠️  Invalid timezone '$TZ'. Skipping timezone update."
        fi
        mark_done "step1"
    fi
fi

# --------------------
# STEP 2: Update /etc/hosts
# --------------------
if ! has_run "step2"; then
    if prompt_or_auto_yes "Step 2: Add hostname to /etc/hosts?"; then
        HOSTNAME=$(hostname)
        if ! grep -q "127.0.0.1.*\b$HOSTNAME\b" /etc/hosts; then
            TMPFILE=$(mktemp)
            awk '/^127\.0\.0\.1/ {print; print "127.0.0.1 '"$HOSTNAME"'"; next} {print}' /etc/hosts > "$TMPFILE"
            sudo cp "$TMPFILE" /etc/hosts
            rm "$TMPFILE"
            echo "Hostname '$HOSTNAME' added to /etc/hosts."
        else
            echo "Hostname '$HOSTNAME' already exists in /etc/hosts. Skipping."
        fi
        mark_done "step2"
    fi
fi

# --------------------
# STEP 3: Set system-wide proxy
# --------------------
if ! has_run "step3"; then
    if prompt_or_auto_yes "Step 3: Add proxy settings to /etc/environment?"; then
        read -p "Enter proxy IP address (leave empty to skip): " PROXY_IP
        if [[ -z "$PROXY_IP" ]]; then
            echo "No proxy IP provided. Skipping Step 3."
        else
            PROXY_LINES=(
                "http_proxy=\"http://$PROXY_IP:3128\""
                "https_proxy=\"http://$PROXY_IP:3128\""
                'no_proxy="localhost,127.0.0.1,::1"'
            )
            for line in "${PROXY_LINES[@]}"; do
                if ! grep -Fxq "$line" /etc/environment; then
                    echo "$line" | sudo tee -a /etc/environment > /dev/null
                    echo "Added: $line"
                else
                    echo "Already present: $line"
                fi
            done
            STEP3_PROXY_IP="$PROXY_IP"
        fi
        mark_done "step3"
    fi
fi

# --------------------
# STEP 4: apt update
# --------------------
if ! has_run "step4"; then
    if prompt_or_auto_yes "Step 4: Run apt update?"; then
        sudo apt update
        mark_done "step4"
    fi
fi

# --------------------
# STEP 5: Install and configure chrony NTP
# --------------------
if ! has_run "step5"; then
    if prompt_or_auto_yes "Step 5: Install and configure chrony for time sync?"; then
        sudo apt-get install -y chrony
        read -p "Enter NTP server IP (leave empty to skip configuration): " NTP_IP
        if [[ -z "$NTP_IP" ]]; then
            echo "No NTP IP provided. Skipping chrony configuration."
        else
            CHRONY_CONF="/etc/chrony/chrony.conf"
            BACKUP="$CHRONY_CONF.bak.$(date +%s)"
            sudo cp "$CHRONY_CONF" "$BACKUP"
            echo "Backup of chrony.conf saved at $BACKUP"
            sudo sed -i 's/^\s*\(pool\s\)/# \1/' "$CHRONY_CONF"
            sudo sed -i 's/^\s*\(rtcsync\)/# \1/' "$CHRONY_CONF"
            LAST_POOL_LINE=$(grep -n '^[[:space:]]*#\?[[:space:]]*pool' "$CHRONY_CONF" | tail -n 1 | cut -d: -f1)
            if [[ -n "$LAST_POOL_LINE" ]]; then
                sudo sed -i "${LAST_POOL_LINE}a server $NTP_IP iburst" "$CHRONY_CONF"
            else
                echo "server $NTP_IP iburst" | sudo tee -a "$CHRONY_CONF" > /dev/null
            fi
            sudo systemctl restart chrony
        fi
        mark_done "step5"
    fi
fi

# --------------------
# STEP 6: apt upgrade and reboot
# --------------------
if ! has_run "step6"; then
    if prompt_or_auto_yes "Step 6: Run apt upgrade and reboot?"; then
        sudo apt upgrade -y
        mark_done "step6"
        echo "Rebooting system now to continue..."
        sudo reboot
        exit 0
    fi
fi

# --------------------
# STEP 7: Remove old Docker/container packages
# --------------------
if ! has_run "step7"; then
    if prompt_or_auto_yes "Step 7: Remove old Docker-related packages?"; then
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            sudo apt-get remove -y $pkg || true
        done
        mark_done "step7"
    fi
fi

# --------------------
# STEP 8: Add Docker GPG key and repo
# --------------------
if ! has_run "step8"; then
    if prompt_or_auto_yes "Step 8: Add Docker GPG key and repository?"; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        mark_done "step8"
    fi
fi

# --------------------
# STEP 9: Install Docker
# --------------------
if ! has_run "step9"; then
    if prompt_or_auto_yes "Step 9: Install Docker Engine?"; then
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        mark_done "step9"
    fi
fi

# --------------------
# STEP 10: Configure Docker daemon proxy
# --------------------
if ! has_run "step10"; then
    if prompt_or_auto_yes "Step 10: Configure Docker daemon proxy?"; then
        read -p "Enter proxy IP for Docker daemon (leave blank to reuse from Step 3): " DOCKER_PROXY_IP
        if [[ -z "$DOCKER_PROXY_IP" ]]; then
            DOCKER_PROXY_IP="$STEP3_PROXY_IP"
            if [[ -z "$DOCKER_PROXY_IP" ]]; then
                echo "No proxy IP provided or remembered from Step 3. Skipping Docker proxy configuration."
                mark_done "step10"
                continue
            else
                echo "Using Step 3 proxy IP: $DOCKER_PROXY_IP"
            fi
        fi
        PROXY_CONF_DIR="/etc/systemd/system/docker.service.d"
        PROXY_CONF_FILE="$PROXY_CONF_DIR/http-proxy.conf"
        sudo mkdir -p "$PROXY_CONF_DIR"
        sudo tee "$PROXY_CONF_FILE" > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=http://$DOCKER_PROXY_IP:3128/"
Environment="HTTPS_PROXY=http://$DOCKER_PROXY_IP:3128/"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF
        sudo systemctl daemon-reexec
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        echo "Docker daemon proxy configured."
        mark_done "step10"
    fi
fi

# --------------------
# STEP 11: Add user to docker group
# --------------------
if ! has_run "step11"; then
    if prompt_or_auto_yes "Step 11: Add user '$USER' to docker group?"; then
        sudo usermod -aG docker $USER
        echo "User '$USER' added to docker group. You may need to logout and log back in."
        mark_done "step11"
    fi
fi

echo "✅ All steps completed successfully at $(date)."
