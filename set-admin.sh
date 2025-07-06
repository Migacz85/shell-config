#!/bin/bash

set -e

echo "🚀 WordPress Admin Creator + Secure Share Link"

# Prompt for user info
read -p "🧑 Enter WordPress admin username: " ADMIN_USER
read -p "📧 Enter admin email: " ADMIN_EMAIL

# Ensure wp-cli is installed
install_wp_cli() {
  if ! command -v wp &> /dev/null; then
    echo "📦 Installing wp-cli..."
    curl -s -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp || sudo mv wp-cli.phar /usr/local/bin/wp
  fi
}

install_wp_cli

# 🔍 Find WP installs by scanning Apache virtual hosts
find_wp_paths() {
  apache_conf_dirs=(/etc/apache2/sites-enabled)
  declare -a wp_paths=()

  for dir in "${apache_conf_dirs[@]}"; do
    [[ -d "$dir" ]] || continue

    # Extract DocumentRoot lines without angle brackets, clean spaces/quotes
    mapfile -t docroots < <(grep -i 'DocumentRoot' "$dir"/* | awk '{print $2}' | sed 's/"//g' | tr -d '\r')

    for docroot in "${docroots[@]}"; do
      if [[ -d "$docroot" && -f "$docroot/wp-config.php" ]]; then
        wp_paths+=("$docroot")
      fi
    done
  done

  echo "${wp_paths[@]}"
}

# 🧠 Label function for displaying domain
label_path() {
  local path=$1
  domain=$(grep -i ServerName "$path/../*" 2>/dev/null | awk '{print $2}' | head -n 1)
  echo "${domain:-unknown}"
}

# 🔽 Choose install path if more than one
choose_path() {
  local paths=("$@")
  local count=${#paths[@]}

  if [[ "$count" -eq 0 ]]; then
    echo "❌ No WordPress installations found via Apache virtual hosts." >&2
    exit 1
  elif [[ "$count" -eq 1 ]]; then
    echo "✅ Found WordPress installation: ${paths[0]}" >&2
    echo "${paths[0]}"
    return
  fi

  echo "🔍 Multiple WordPress installations detected:" >&2
  for i in "${!paths[@]}"; do
    label=$(label_path "${paths[$i]}")
    echo "[$((i+1))] ${paths[$i]} ($label)" >&2
  done

  echo -n "👉 Choose installation number: " >&2
  read -r choice

  if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
    echo "${paths[$((choice-1))]}"
  else
    echo "❌ Invalid selection." >&2
    exit 1
  fi
}

# Use safe temp file to avoid output bugs with subshells
TMP_INSTALL_PATH_FILE=$(mktemp)
choose_path $(find_wp_paths) > "$TMP_INSTALL_PATH_FILE"
INSTALL_PATH=$(<"$TMP_INSTALL_PATH_FILE")
rm "$TMP_INSTALL_PATH_FILE"

cd "$INSTALL_PATH"

# Generate random password
PASSWORD=$(openssl rand -base64 16)

# Create admin user with wp-cli
wp user create "$ADMIN_USER" "$ADMIN_EMAIL" --user_pass="$PASSWORD" --role=administrator --skip-email

echo "✅ Admin user '$ADMIN_USER' created in $INSTALL_PATH"

# Create HTML password file
UUID=$(uuidgen)
TMP_PASS_FILE="/var/www/html/.one-time-pass-${UUID}.html"
cat > "$TMP_PASS_FILE" <<EOF
<!DOCTYPE html>
<html>
  <head><meta charset="UTF-8"><title>Credentials</title></head>
  <body style="font-family:sans-serif; background:#f9f9f9; padding:2em">
    <h2>🔐 WordPress Admin Created</h2>
    <p><strong>Username:</strong> $ADMIN_USER</p>
    <p><strong>Password:</strong> <code id="pass">$PASSWORD</code></p>
    <p><em>This link is one-time. Refreshing will destroy the file.</em></p>
    <script>
      fetch(window.location.href, { method: 'DELETE' });
    </script>
  </body>
</html>
EOF

# Create .htaccess to delete the file after first view using mod_rewrite
HTACCESS_FILE="/var/www/html/.htaccess"
if ! grep -q "RewriteEngine On" "$HTACCESS_FILE" 2>/dev/null; then
  echo "RewriteEngine On" >> "$HTACCESS_FILE"
fi
cat >> "$HTACCESS_FILE" <<EOF

# Auto-delete one-time pass file after viewing
RewriteCond %{REQUEST_URI} ^/\.one-time-pass-${UUID}\.html$
RewriteRule .* - [E=DELETE_ME:1]
EOF

# Apache cleanup hook
cat >> /etc/apache2/apache2.conf <<EOF

# Hook: delete one-time password files if env DELETE_ME is set
<FilesMatch "\.one-time-pass-.*\.html$">
  SetEnvIf DELETE_ME 1 DELETE_NOW
</FilesMatch>
EOF

# Background script to delete file after 1 read
cat > /usr/local/bin/delete-once.sh <<'EOS'
#!/bin/bash
sleep 2
rm -f "$1"
EOS
chmod +x /usr/local/bin/delete-once.sh

# Add delete-once call to Apache custom log
echo "CustomLog \"|/usr/local/bin/delete-once.sh $TMP_PASS_FILE\" combined env=DELETE_NOW" >> /etc/apache2/apache2.conf

# Reload Apache to apply rules
systemctl reload apache2

LINK="http://$(hostname -I | awk '{print $1}')/.one-time-pass-${UUID}.html"
echo "🔗 Share this one-time secure link: $LINK"

