#!/bin/bash

set -e

STEP_FILE="/var/tmp/new_machine_install_progress"
LOG_FILE="/var/tmp/new_machine_install.log"

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

# Function to ask Yes/No with timeout, defaulting to "Yes"
prompt_or_auto_yes() {
    local question="$1"
    local timeout=5
    echo -n "$question [Y/n] (auto-yes in $timeout sec): "
    read -t $timeout answer
    answer=${answer:-Y}
    echo "$question -> ${answer}" >> "$LOG_FILE"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Function to check if step has already run
has_run() {
    grep -q "^$1\$" "$STEP_FILE"
}

# Function to mark step as done
mark_done() {
    echo "$1" >> "$STEP_FILE"
}

# --------------------
# STEP 1: Update /etc/hosts
# --------------------
if ! has_run "step1"; then
    if prompt_or_auto_yes "Step 1: Add hostname to /etc/hosts?"; then
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
        mark_done "step1"
    fi
fi

# --------------------
# STEP 2: Append proxy settings to /etc/environment
# --------------------
if ! has_run "step2"; then
    if prompt_or_auto_yes "Step 2: Add proxy settings to /etc/environment?"; then
        read -p "Enter proxy IP address (leave empty to skip): " PROXY_IP
        if [[ -z "$PROXY_IP" ]]; then
            echo "No proxy IP provided. Skipping Step 2."
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
        fi
        mark_done "step2"
    fi
fi

# --------------------
# STEP 3: apt update
# --------------------
if ! has_run "step3"; then
    if prompt_or_auto_yes "Step 3: Run apt update?"; then
        sudo apt update
        mark_done "step3"
    fi
fi

# --------------------
# STEP 4: apt upgrade and reboot
# --------------------
if ! has_run "step4"; then
    if prompt_or_auto_yes "Step 4: Run apt upgrade and reboot?"; then
        sudo apt upgrade -y
        mark_done "step4"
        echo "Rebooting system now to continue..."
        sudo reboot
        exit 0
    fi
fi

# --------------------
# STEP 5: Remove old Docker/container packages
# --------------------
if ! has_run "step5"; then
    if prompt_or_auto_yes "Step 5: Remove old Docker-related packages?"; then
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            sudo apt-get remove -y $pkg || true
        done
        mark_done "step5"
    fi
fi

# --------------------
# STEP 6: Add Docker GPG key and repo
# --------------------
if ! has_run "step6"; then
    if prompt_or_auto_yes "Step 6: Add Docker GPG key and repository?"; then
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
        mark_done "step6"
    fi
fi

# --------------------
# STEP 7: Install Docker
# --------------------
if ! has_run "step7"; then
    if prompt_or_auto_yes "Step 7: Install Docker Engine?"; then
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        mark_done "step7"
    fi
fi

# --------------------
# STEP 8: Add user to docker group
# --------------------
if ! has_run "step8"; then
    if prompt_or_auto_yes "Step 8: Add user '$USER' to docker group?"; then
        sudo usermod -aG docker $USER
        echo "User '$USER' added to docker group. You may need to logout and log back in for this to take effect."
        mark_done "step8"
    fi
fi

echo "✅ All steps completed successfully at $(date)."
