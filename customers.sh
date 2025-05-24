#!/bin/bash
#export client customers from woocomerce

# Automatically detect wp-config.php in current directory
WP_CONFIG_PATH="$(pwd)/wp-config.php"

# Verify wp-config.php exists
if [ ! -f "$WP_CONFIG_PATH" ]; then
  echo "❌ wp-config.php not found in current directory."
  exit 1
fi

# Extract DB credentials from wp-config.php
DB_NAME=$(grep "define('DB_NAME'" "$WP_CONFIG_PATH" | cut -d \' -f 4)
DB_USER=$(grep "define('DB_USER'" "$WP_CONFIG_PATH" | cut -d \' -f 4)
DB_PASSWORD=$(grep "define('DB_PASSWORD'" "$WP_CONFIG_PATH" | cut -d \' -f 4)
DB_HOST=$(grep "define('DB_HOST'" "$WP_CONFIG_PATH" | cut -d \' -f 4)

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_HOST" ]]; then
  echo "❌ Could not extract DB credentials from wp-config.php."
  exit 1
fi

echo "Using database: $DB_NAME"
echo "Using user: $DB_USER"
echo "Using host: $DB_HOST"

# Create output directory if it doesn't exist
OUTPUT_DIR="./wp-content/uploads/$(date +%Y)/$(date +%m)"
mkdir -p "$OUTPUT_DIR"

# Output CSV path
OUTPUT_PATH="$OUTPUT_DIR/customers.csv"

# SQL query to export WooCommerce customer data including hashed passwords
QUERY="SELECT 
  u.ID AS user_id,
  u.user_email,
  u.user_pass AS hashed_password,
  'bcrypt' AS hash_algorithm,
  um_first_name.meta_value AS first_name,
  um_last_name.meta_value AS last_name,
  um_billing_phone.meta_value AS billing_phone,
  um_billing_address_1.meta_value AS billing_address_1,
  um_billing_address_2.meta_value AS billing_address_2,
  um_billing_city.meta_value AS billing_city,
  um_billing_postcode.meta_value AS billing_postcode,
  um_billing_country.meta_value AS billing_country,
  um_billing_state.meta_value AS billing_state
FROM ${DB_NAME}.pnz_users u
LEFT JOIN ${DB_NAME}.pnz_usermeta um_first_name ON u.ID = um_first_name.user_id AND um_first_name.meta_key = 'first_name'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_last_name ON u.ID = um_last_name.user_id AND um_last_name.meta_key = 'last_name'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_phone ON u.ID = um_billing_phone.user_id AND um_billing_phone.meta_key = 'billing_phone'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_address_1 ON u.ID = um_billing_address_1.user_id AND um_billing_address_1.meta_key = 'billing_address_1'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_address_2 ON u.ID = um_billing_address_2.user_id AND um_billing_address_2.meta_key = 'billing_address_2'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_city ON u.ID = um_billing_city.user_id AND um_billing_city.meta_key = 'billing_city'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_postcode ON u.ID = um_billing_postcode.user_id AND um_billing_postcode.meta_key = 'billing_postcode'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_country ON u.ID = um_billing_country.user_id AND um_billing_country.meta_key = 'billing_country'
LEFT JOIN ${DB_NAME}.pnz_usermeta um_billing_state ON u.ID = um_billing_state.user_id AND um_billing_state.meta_key = 'billing_state'
WHERE u.ID IN (
  SELECT DISTINCT postmeta.meta_value
  FROM ${DB_NAME}.pnz_postmeta postmeta
  JOIN ${DB_NAME}.pnz_posts posts ON posts.ID = postmeta.post_id
  WHERE posts.post_type = 'shop_order'
    AND postmeta.meta_key = '_customer_user'
    AND postmeta.meta_value != '0'
);"

echo "Running query and exporting to CSV..."

# Run query and export to CSV (tab-separated, no column names)
mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" --batch --skip-column-names -e "$QUERY" > "$OUTPUT_PATH"

if [ $? -eq 0 ]; then
  echo "✅ Export completed successfully!"
  echo "File saved to: $OUTPUT_PATH"
else
  echo "❌ Export failed."
fi

