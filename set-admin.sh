#!/bin/bash

set -e

# ----------- CONFIG -----------

DEFAULT_TMP_DIR="/var/www/html/tmp"
HTML_EXPIRY_DAYS=7

# ----------- HELPERS -----------

generate_password() {
  tr -dc 'A-Za-z0-9!@#$%&*()-_=+' < /dev/urandom | head -c 16
}

is_wordpress_install() {
  [[ -f "$1/wp-config.php" && -f "$1/wp-load.php" ]]
}

label_path() {
  local path="$1"
  if [[ "$path" =~ staging|Staging|\.staging ]]; then
    echo "Staging"
  else
    echo "Primary"
  fi
}

extract_apache_paths() {
  local files
  files=$(find /etc/apache2/sites-enabled /etc/apache2/sites-available -type f 2>/dev/null)
  for file in $files; do
    grep -i "DocumentRoot" "$file" | awk '{print $2}' | sed 's/"//g'
  done | sort -u
}

find_wordpress_paths() {
  local candidates=()
  for path in $(extract_apache_paths); do
    if is_wordpress_install "$path"; then
      candidates+=("$path")
    fi
  done
  echo "${candidates[@]}"
}

choose_path() {
  local paths=("$@")
  local count=${#paths[@]}

  if [[ "$count" -eq 0 ]]; then
    echo "❌ No WordPress installations found via Apache virtual hosts."
    exit 1
  elif [[ "$count" -eq 1 ]]; then
    echo "✅ Found WordPress installation: ${paths[0]}"
    echo "${paths[0]}"
  else
    echo "🔍 Multiple WordPress installations detected:"
    for i in "${!paths[@]}"; do
      label=$(label_path "${paths[$i]}")
      echo "[$((i+1))] ${paths[$i]} ($label)"
    done

    echo -n "👉 Choose installation number: "
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
      echo "${paths[$((choice-1))]}"
    else
      echo "❌ Invalid selection."
      exit 1
    fi
  fi
}

install_wpcli() {
  if command -v wp &>/dev/null; then return 0; fi

  echo "🛠 Installing wp-cli..."
  curl -s -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp

  if ! command -v wp &>/dev/null; then
    echo "❌ Failed to install wp-cli."
    exit 1
  fi
}

create_wp_admin() {
  local path="$1"
  local username="$2"
  local email="$3"
  local password="$4"

  cd "$path"

  if wp user get "$username" &>/dev/null; then
    echo "👤 Updating existing user '$username'"
    wp user update "$username" --user_pass="$password"
  else
    echo "👤 Creating new admin user '$username'"
    wp user create "$username" "$email" --role=administrator --user_pass="$password"
  fi
}

generate_html() {
  local tmp_dir="$1"
  local username="$2"
  local password="$3"
  local url_root="$4"

  mkdir -p "$tmp_dir"

  local token
  token=$(head /dev/urandom | tr -dc a-z0-9 | head -c 16)
  local file="$tmp_dir/pwshare_${token}.php"
  local url="$url_root/tmp/pwshare_${token}.php"

  cat > "$file" <<EOF
<?php
@unlink(__FILE__);
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>WordPress Admin Credentials</title>
  <style>
    body { font-family: sans-serif; background: #f9f9f9; padding: 2em; }
    .box { background: white; padding: 2em; border-radius: 8px; max-width: 600px; margin: auto; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    .creds { font-family: monospace; background: #eee; padding: 1em; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="box">
    <h2>✅ WordPress Admin Access</h2>
    <p>Below are your credentials (this page deletes itself after viewing):</p>
    <div class="creds">
      Username: <strong>$username</strong><br>
      Password: <strong>$password</strong>
    </div>
    <p>🧨 This page has now self-destructed.</p>
  </div>
</body>
</html>
EOF

  chmod 600 "$file"
  echo "$url"
}

setup_cron_cleanup() {
  local dir="$1"
  local cmd="find $dir -type f -name 'pwshare_*.php' -mtime +$HTML_EXPIRY_DAYS -exec rm -f {} \;"
  (crontab -l 2>/dev/null | grep -F "$cmd") || (
    (crontab -l 2>/dev/null; echo "0 3 * * * $cmd") | crontab -
    echo "🧹 Cron job added for automatic cleanup."
  )
}

# ----------- MAIN -----------

if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Please run as root (needed to install wp-cli and access Apache configs)."
  exit 1
fi

echo "🚀 WordPress Admin Creator + Secure Share Link"

read -rp "🧑 Enter WordPress admin username: " USERNAME
read -rp "📧 Enter admin email: " EMAIL

PASSWORD=$(generate_password)

# Step 1: Find WP install path
paths=($(find_wordpress_paths))
INSTALL_PATH=$(choose_path "${paths[@]}")

# Step 2: Install wp-cli if needed
install_wpcli

# Step 3: Create/update admin
create_wp_admin "$INSTALL_PATH" "$USERNAME" "$EMAIL" "$PASSWORD"

# Step 4: Get domain for link
DOMAIN=$(grep -iR ServerName /etc/apache2/sites-enabled /etc/apache2/sites-available 2>/dev/null | grep "$INSTALL_PATH" | awk '{print $2}' | head -n1)
URL_ROOT="http://${DOMAIN:-localhost}"

# Step 5: Generate self-destructing credentials page
SHARE_URL=$(generate_html "$DEFAULT_TMP_DIR" "$USERNAME" "$PASSWORD" "$URL_ROOT")
echo -e "\n🔗 Share this secure ONE-TIME link with the client:"
echo "$SHARE_URL"

# Step 6: Setup cleanup cron job
setup_cron_cleanup "$DEFAULT_TMP_DIR"

exit 0

