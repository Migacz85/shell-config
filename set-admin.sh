root@pianosoundz:~# cat ./admin.sh
#!/bin/bash
#
# WordPress Admin Creator & Secure Share Link
# Version 2.3
#
# This script automates the creation of a new WordPress administrator user.
# It intelligently locates WordPress installations, creates the user with a
# secure random password, and generates a one-time, self-destructing link
# to share the credentials securely.
#
# Changelog v2.3:
# - MAJOR FIX: Resolved 404 errors by removing leading dots from the secure
#   directory and filename, which are often blocked by web servers.
# - MAJOR FIX: The secure directory is now created *inside* the selected
#   WordPress installation path, guaranteeing the URL path is always correct.
# - Improved URL generation to use the WordPress site URL for better accuracy.

# --- Colors for better output ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Utility Functions ---
info() { echo -e "${C_BLUE}INFO:${C_RESET} $1" >&2; }
warn() { echo -e "${C_YELLOW}WARN:${C_RESET} $1" >&2; }
error() { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; exit 1; }
success() { echo -e "${C_GREEN}SUCCESS:${C_RESET} $1" >&2; }

# --- Main Script ---
set -e # Exit immediately if a command exits with a non-zero status.

echo -e "${C_CYAN}🚀 WordPress Admin Creator + Secure Share Link${C_RESET}" >&2
echo "----------------------------------------------------" >&2

# 1. Dependency Checks
# ===================================================
info "Checking for required tools (wp-cli, openssl, curl, uuidgen)..."
command -v curl >/dev/null 2>&1 || error "curl is required but not installed. Please install it."
command -v openssl >/dev/null 2>&1 || error "openssl is required for password generation. Please install it."
command -v uuidgen >/dev/null 2>&1 || error "uuidgen is required for unique filenames. Please install it."

# 2. WP-CLI Installation
# ===================================================
install_wp_cli() {
  if ! command -v wp &> /dev/null; then
    info "wp-cli not found. Attempting to install..."
    curl -s -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    if ! php -l wp-cli.phar >/dev/null 2>&1; then
      rm wp-cli.phar
      error "Downloaded wp-cli.phar is corrupted or PHP is not available. Please try again."
    fi
    chmod +x wp-cli.phar
    if command -v sudo &>/dev/null && [ ! -w /usr/local/bin ]; then
      sudo mv wp-cli.phar /usr/local/bin/wp
    else
      mv wp-cli.phar /usr/local/bin/wp || error "Failed to move wp-cli.phar to /usr/local/bin. Check permissions or run with sudo."
    fi
    success "wp-cli installed successfully."
  else
    info "wp-cli is already installed."
  fi
}

install_wp_cli

# 3. Find WordPress Installations
# ===================================================
find_wp_installations() {
  info "Searching for WordPress installations..."
  local search_paths=("/var/www" "/srv/www" "/usr/share/nginx" "$HOME")
  local found_paths
  found_paths=$(find "${search_paths[@]}" -maxdepth 4 -type f -name "wp-settings.php" -printf "%h\n" 2>/dev/null | sort -u)
  if [[ -z "$found_paths" ]]; then
    warn "Standard search failed. Trying 'wp find-installations'..."
    found_paths=$(wp find-installations --skip-packages --quiet 2>/dev/null | awk '{print $2}')
  fi
  echo "$found_paths"
}

# 4. User Interaction & Path Selection
# ===================================================
choose_wp_path() {
  local -a all_paths
  readarray -t all_paths <<< "$1"
  local -a clean_paths=()
  for path in "${all_paths[@]}"; do
      [[ -n "$path" ]] && clean_paths+=("$path")
  done
  all_paths=("${clean_paths[@]}")
  local count=${#all_paths[@]}

  if [[ "$count" -eq 0 ]]; then
    error "No WordPress installations found. Please check your web root directories."
  fi

  if [[ "$count" -eq 1 ]]; then
    info "Found a single WordPress installation: ${all_paths[0]}"
    echo "${all_paths[0]}"
    return
  fi

  info "Multiple WordPress installations detected. Please choose one:"
  local i=1
  for path in "${all_paths[@]}"; do
    local site_url
    site_url=$(wp option get siteurl --path="$path" --allow-root --quiet 2>/dev/null || echo "N/A")
    echo -e "  [${C_GREEN}$i${C_RESET}] ${C_YELLOW}$path${C_RESET} (${C_CYAN}URL: $site_url${C_RESET})" >&2
    ((i++))
  done

  local choice
  read -p "👉 Enter the number of the installation to use: " choice

  if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
    echo "${all_paths[$((choice - 1))]}"
  else
    error "Invalid selection. Please run the script again."
  fi
}

# Execute search and selection
WP_PATHS=$(find_wp_installations)
INSTALL_PATH=$(choose_wp_path "$WP_PATHS")

if [[ -z "$INSTALL_PATH" ]]; then
    error "No installation path was selected. Exiting."
fi

cd "$INSTALL_PATH" || error "Could not change directory to '$INSTALL_PATH'."
success "Operating in WordPress directory: $(pwd)"

# 5. Get User Details
# ===================================================
read -p "🧑 Enter new admin username: " ADMIN_USER
read -p "📧 Enter new admin email: " ADMIN_EMAIL

if [[ -z "$ADMIN_USER" ]] || [[ -z "$ADMIN_EMAIL" ]]; then
  error "Username and email cannot be empty."
fi

# 6. Create WordPress User
# ===================================================
info "Creating admin user '$ADMIN_USER'..."
PASSWORD=$(openssl rand -base64 18)

if ! wp user create "$ADMIN_USER" "$ADMIN_EMAIL" --user_pass="$PASSWORD" --role=administrator --allow-root; then
  error "Failed to create WordPress user. Does a user with that username or email already exist?"
fi
success "Admin user '$ADMIN_USER' created."

# 7. Generate Secure One-Time Link
# ===================================================
info "Generating secure one-time access link..."

# **FIX:** Directory and file names no longer start with a dot.
# **FIX:** Secure directory is now created inside the selected WP installation path.
SECURE_DIR_NAME="credential-delivery"
SECURE_DIR="${INSTALL_PATH}/${SECURE_DIR_NAME}"
UUID=$(uuidgen)
PASS_FILE_NAME="${UUID}.php"
PASS_FILE_PATH="${SECURE_DIR}/${PASS_FILE_NAME}"

mkdir -p "$SECURE_DIR"
chown www-data:www-data "$SECURE_DIR"
chmod 755 "$SECURE_DIR" # Use 755 for directories to ensure web server can access it

# Create the self-destructing PHP file
cat > "$PASS_FILE_PATH" <<EOF
<?php
// Secure, one-time credential viewer.
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");

\$html = <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Secure Credential Delivery</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f0f2f5; color: #333; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .container { background: #fff; padding: 2rem 3rem; border-radius: 12px; box-shadow: 0 8px 25px rgba(0,0,0,0.1); text-align: center; max-width: 450px; border-top: 5px solid #0073aa; }
        h2 { color: #0073aa; margin-top: 0; }
        .credential { background: #e9ecef; border-radius: 6px; padding: 0.75rem; margin: 1rem 0; text-align: left; }
        .credential strong { display: block; color: #555; margin-bottom: 0.25rem; }
        .credential code { background: #d4dae0; padding: 0.2em 0.4em; border-radius: 4px; font-size: 1.1em; user-select: all; word-break: break-all; }
        .warning { color: #d9534f; font-weight: bold; margin-top: 1.5rem; }
        .footer { font-size: 0.8em; color: #888; margin-top: 2rem; }
    </style>
</head>
<body>
    <div class="container">
        <h2>🔐 WordPress Admin Credentials</h2>
        <div class="credential"><strong>Username:</strong><code>$ADMIN_USER</code></div>
        <div class="credential"><strong>Password:</strong><code>$PASSWORD</code></div>
        <p class="warning">This page has been destroyed and cannot be viewed again.</p>
        <p class="footer">This is a one-time secure delivery system.</p>
    </div>
</body>
</html>
HTML;

echo \$html;
// The @ suppresses errors if the file can't be unlinked, though it should be possible.
@unlink(__FILE__);
?>
EOF

chmod 644 "$PASS_FILE_PATH" # Use 644 for files to ensure web server can read it
chown www-data:www-data "$PASS_FILE_PATH"

# 8. Display Final Link
# ===================================================
# **FIX:** Get the site URL directly from WordPress for maximum accuracy.
SITE_URL=$(wp option get siteurl --allow-root --quiet)
if [[ -z "$SITE_URL" ]]; then
    error "Could not retrieve site URL from WordPress. Cannot generate link."
fi

# Ensure SITE_URL doesn't have a trailing slash
SITE_URL=$(echo "$SITE_URL" | sed 's:/*$::')

LINK="${SITE_URL}/${SECURE_DIR_NAME}/${PASS_FILE_NAME}"

echo "----------------------------------------------------" >&2
success "All done!"
echo "User: $ADMIN_USER"
echo "Mail: $ADMIN_EMAIL"
echo "Password: $PASSWORD"
echo -e "🔗 ${C_YELLOW}Share this one-time secure link with the user:${C_RESET}" >&2
echo -e "${C_GREEN}${LINK}${C_RESET}" >&2
warn "The link will self-destruct immediately after it is viewed."
warn "A .htaccess file will be created in '${SECURE_DIR_NAME}' to prevent directory listing."
echo "----------------------------------------------------" >&2

# 9. Add .htaccess to prevent directory listing
# ===================================================
cat > "${SECURE_DIR}/.htaccess" <<EOF
# Prevent directory listing
Options -Indexes
EOF
chmod 644 "${SECURE_DIR}/.htaccess"
chown www-data:www-data "${SECURE_DIR}/.htaccess"
