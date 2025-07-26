#!/bin/bash

# === CONFIGURATION ===
TARGET_USER="root"
KEYS_URL="https://raw.githubusercontent.com/agutie29/ssh-bootstrap/master/authorized_keys"

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

echo "[✓] SSH bootstrap complete. Public key auth enabled. Password login disabled."
