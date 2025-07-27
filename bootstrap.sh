#!/bin/bash

# === CONFIGURATION ===
TARGET_USER="root"
KEYS_URL="https://raw.githubusercontent.com/agutie29/ssh-bootstrap/master/authorized_keys"
BASTION_IP="192.168.9.14"
BASTION_WEBHOOK_PORT="5000"

SSH_DIR="/home/$TARGET_USER/.ssh"
[ "$TARGET_USER" = "root" ] && SSH_DIR="/root/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

echo "[+] Bootstrapping SSH for user: $TARGET_USER"

# === STEP 1: Check for SSH server ===
if ! command -v sshd >/dev/null 2>&1; then
  echo "[!] SSH server not found. Installing..."

  if command -v apt >/dev/null 2>&1; then
    apt update && apt install -y openssh-server
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y openssh-server
  elif command -v yum >/dev/null 2>&1; then
    yum install -y openssh-server
  else
    echo "[✗] Could not detect supported package manager to install openssh-server."
    exit 1
  fi
else
  echo "[✓] SSH server is already installed."
fi

# === STEP 2: Ensure SSH is running ===
echo "[+] Ensuring sshd is enabled and running..."
systemctl enable sshd 2>/dev/null || systemctl enable ssh
systemctl start sshd 2>/dev/null || systemctl start ssh

# === STEP 3: Setup .ssh and authorized_keys ===
echo "[+] Creating .ssh directory at: $SSH_DIR"
mkdir -p "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 700 "$SSH_DIR"

echo "[+] Downloading authorized_keys from GitHub..."
curl -fsSL "$KEYS_URL" >> "$AUTHORIZED_KEYS"

echo "[+] Removing duplicate keys..."
sort -u "$AUTHORIZED_KEYS" -o "$AUTHORIZED_KEYS"

chmod 600 "$AUTHORIZED_KEYS"
chown -R "$TARGET_USER:$TARGET_USER" "$SSH_DIR"

# === STEP 4: Harden SSH ===
echo "[+] Backing up sshd_config..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "[+] Hardening SSH settings..."
sed -i 's/^#*\s*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*\s*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# === STEP 5: Restart SSH ===
echo "[+] Restarting SSH service..."
systemctl restart sshd 2>/dev/null || service ssh restart

# === STEP 6: Trigger Bastion Phase 2 ===
MY_IP=$(hostname -I | awk '{print $1}')
echo "[+] Notifying bastion to continue setup for IP: $MY_IP..."

curl -X POST "http://$BASTION_IP:$BASTION_WEBHOOK_PORT/deploy" \
     -H "Content-Type: application/json" \
     -d "{\"ip\": \"$MY_IP\"}"

echo "[✓] SSH bootstrap complete. Bastion will now continue configuration."
