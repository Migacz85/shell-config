#!/bin/bash
set -euo pipefail

# --- 0. Initial Checks ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- 1. Get User Information ---
read -rp "Enter SFTP username: " SFTP_USER
read -rsp "Enter password for $SFTP_USER: " SFTP_PASS
echo
read -rp "Enter the EXACT live path to manage (default: /var/www): " LIVE_DIR
LIVE_DIR=${LIVE_DIR:-/var/www}

# --- 2. Validate Live Directory ---
while [ ! -d "$LIVE_DIR" ]; do
  echo "❌ Directory '$LIVE_DIR' does not exist."
  read -rp "Please enter a valid live path: " LIVE_DIR
done

# --- Detect web server group ---
WEB_SERVER_GROUP=$(stat -c %G "$LIVE_DIR")
if ! getent group "$WEB_SERVER_GROUP" > /dev/null; then
  echo "⚠️  Group '$WEB_SERVER_GROUP' not found. Defaulting to 'www-data'."
  WEB_SERVER_GROUP="www-data"
else
  echo "✅ Detected web server group: $WEB_SERVER_GROUP"
fi

# --- 3. Ensure SSH is Installed ---
echo "▶️  Installing SSH server if needed..."
apt-get update -qq
apt-get install -y --no-install-recommends openssh-server

# --- 4. Prepare Directories and Groups ---
groupadd -f sftpusers
if ! getent group "$WEB_SERVER_GROUP" >/dev/null; then
  echo "⚠️  Web server group '$WEB_SERVER_GROUP' not found. Creating it."
  groupadd "$WEB_SERVER_GROUP"
fi

JAIL_BASE="/sftp"
JAIL_HOME="$JAIL_BASE/$SFTP_USER"
JAIL_FILES="$JAIL_HOME/files"

mkdir -p "$JAIL_FILES"
chown root:root "$JAIL_HOME"
chmod 755 "$JAIL_HOME"

# --- 5. Create or Update User ---
if id "$SFTP_USER" &>/dev/null; then
  echo "ℹ️  User $SFTP_USER exists. Updating groups and password."
  usermod -aG sftpusers,"$WEB_SERVER_GROUP" "$SFTP_USER"
else
  useradd -g sftpusers -G "$WEB_SERVER_GROUP" -s /usr/sbin/nologin -d "$JAIL_FILES" "$SFTP_USER"
fi

echo "$SFTP_USER:$SFTP_PASS" | chpasswd

# --- 6. Setup Bind Mount ---
echo "▶️  Configuring bind mount..."
if mountpoint -q "$JAIL_FILES"; then
  umount "$JAIL_FILES"
fi
mount --bind "$LIVE_DIR" "$JAIL_FILES"

FSTAB_ENTRY="$LIVE_DIR $JAIL_FILES none bind 0 0"
if ! grep -qsE "^\s*${LIVE_DIR//\//\\/}\s+${JAIL_FILES//\//\\/}\s+none\s+bind" /etc/fstab; then
  echo "$FSTAB_ENTRY" >> /etc/fstab
fi

# Ensure correct permissions
chown root:root "$JAIL_HOME"
chmod 755 "$JAIL_HOME"
chown "$SFTP_USER":"$WEB_SERVER_GROUP" "$JAIL_FILES"

# --- 7. SSH Configuration ---
SSHD_CONFIG="/etc/ssh/sshd_config"
[ -f "$SSHD_CONFIG.bak" ] || cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

echo "▶️  Configuring SSH..."
sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
sed -i -E 's/^#?Subsystem sftp.*/Subsystem sftp internal-sftp/' "$SSHD_CONFIG"

# Remove old Match blocks
sed -i '/^Match Group sftpusers/,/^\s*$/d' "$SSHD_CONFIG"

cat <<EOF >> "$SSHD_CONFIG"

Match Group sftpusers
    ChrootDirectory $JAIL_BASE/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

# --- 8. Restart SSH Safely ---
echo "▶️  Validating SSH configuration..."
if sshd -t; then
  systemctl restart sshd
  echo "✅ SSH service restarted successfully."
else
  echo "❌ SSH configuration is invalid. Aborting restart." >&2
  exit 1
fi

# --- 9. Final Output ---
PUBLIC_IP=$(hostname -I | awk '{print $1}')

echo -e "\n✅ SFTP-only setup complete!"
echo "-------------------------------------------"
echo "  Host: $PUBLIC_IP"
echo "  Port: 22"
echo "  User: $SFTP_USER"
echo "  Password: [the one you set]"
echo
echo "  Live content path: $LIVE_DIR"
echo "  SFTP path: /files (inside chroot)"
echo "-------------------------------------------"

