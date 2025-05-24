#!/bin/bash

# Default wp-config.php path one level up
WP_CONFIG_PATH="../wp-config.php"

if [[ ! -f "$WP_CONFIG_PATH" ]]; then
  echo "❌ wp-config.php not found at $WP_CONFIG_PATH"
  exit 1
fi

extract_credential() {
  local key=$1
  grep -E "define\( *'$key'" "$WP_CONFIG_PATH" | sed -E "s/.*define\( *'$key', *'([^']+)'.*/\1/"
}

DB_NAME=$(extract_credential "DB_NAME")
DB_USER=$(extract_credential "DB_USER")
DB_PASSWORD=$(extract_credential "DB_PASSWORD")
DB_HOST=$(extract_credential "DB_HOST")

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_HOST" ]]; then
  echo "❌ Could not extract DB credentials from wp-config.php."
  exit 1
fi

TABLE_PREFIX=$(grep "table_prefix" "$WP_CONFIG_PATH" | cut -d\' -f2)

echo "✅ Extracted DB credentials:"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"
echo "DB_PASSWORD: [hidden]"
echo "DB_HOST: $DB_HOST"
echo "Table prefix extracted from wp-config.php: '$TABLE_PREFIX'"

read -rp "Press Enter to use this prefix or type a different prefix (including trailing underscore if any): " input_prefix
if [[ -n "$input_prefix" ]]; then
  TABLE_PREFIX=$input_prefix
fi

echo "Using table prefix: '$TABLE_PREFIX'"

# Save output in current folder
OUTPUT_PATH="./customers.csv"

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
FROM ${DB_NAME}.${TABLE_PREFIX}users u
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_first_name ON u.ID = um_first_name.user_id AND um_first_name.meta_key = 'first_name'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_last_name ON u.ID = um_last_name.user_id AND um_last_name.meta_key = 'last_name'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_phone ON u.ID = um_billing_phone.user_id AND um_billing_phone.meta_key = 'billing_phone'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_address_1 ON u.ID = um_billing_address_1.user_id AND um_billing_address_1.meta_key = 'billing_address_1'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_address_2 ON u.ID = um_billing_address_2.user_id AND um_billing_address_2.meta_key = 'billing_address_2'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_city ON u.ID = um_billing_city.user_id AND um_billing_city.meta_key = 'billing_city'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_postcode ON u.ID = um_billing_postcode.user_id AND um_billing_postcode.meta_key = 'billing_postcode'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_country ON u.ID = um_billing_country.user_id AND um_billing_country.meta_key = 'billing_country'
LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_state ON u.ID = um_billing_state.user_id AND um_billing_state.meta_key = 'billing_state'
WHERE u.ID IN (
  SELECT DISTINCT postmeta.meta_value
  FROM ${DB_NAME}.${TABLE_PREFIX}postmeta postmeta
  JOIN ${DB_NAME}.${TABLE_PREFIX}posts posts ON posts.ID = postmeta.post_id
  WHERE posts.post_type = 'shop_order'
    AND postmeta.meta_key = '_customer_user'
    AND postmeta.meta_value != '0'
);"

run_export() {
  echo "Running query and exporting to CSV..."
  mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" --batch --skip-column-names -e "$QUERY" > "$OUTPUT_PATH"
  return $?
}

run_export
status=$?

if [ $status -ne 0 ]; then
  echo "❌ Export failed."
  echo "The table prefix '$TABLE_PREFIX' may be incorrect."
  read -rp "Enter the correct table prefix (including trailing underscore if any), or 'q' to quit: " new_prefix
  if [[ "$new_prefix" == "q" ]]; then
    echo "Exiting."
    exit 1
  fi
  if [[ -n "$new_prefix" ]]; then
    TABLE_PREFIX=$new_prefix
    echo "Retrying with prefix: '$TABLE_PREFIX'..."
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
    FROM ${DB_NAME}.${TABLE_PREFIX}users u
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_first_name ON u.ID = um_first_name.user_id AND um_first_name.meta_key = 'first_name'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_last_name ON u.ID = um_last_name.user_id AND um_last_name.meta_key = 'last_name'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_phone ON u.ID = um_billing_phone.user_id AND um_billing_phone.meta_key = 'billing_phone'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_address_1 ON u.ID = um_billing_address_1.user_id AND um_billing_address_1.meta_key = 'billing_address_1'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_address_2 ON u.ID = um_billing_address_2.user_id AND um_billing_address_2.meta_key = 'billing_address_2'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_city ON u.ID = um_billing_city.user_id AND um_billing_city.meta_key = 'billing_city'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_postcode ON u.ID = um_billing_postcode.user_id AND um_billing_postcode.meta_key = 'billing_postcode'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_country ON u.ID = um_billing_country.user_id AND um_billing_country.meta_key = 'billing_country'
    LEFT JOIN ${DB_NAME}.${TABLE_PREFIX}usermeta um_billing_state ON u.ID = um_billing_state.user_id AND um_billing_state.meta_key = 'billing_state'
    WHERE u.ID IN (
      SELECT DISTINCT postmeta.meta_value
      FROM ${DB_NAME}.${TABLE_PREFIX}postmeta postmeta
      JOIN ${DB_NAME}.${TABLE_PREFIX}posts posts ON posts.ID = postmeta.post_id
      WHERE posts.post_type = 'shop_order'
        AND postmeta.meta_key = '_customer_user'
        AND postmeta.meta_value != '0'
    );"
    run_export
    if [ $? -eq 0 ]; then
      echo "✅ Export completed successfully!"
      echo "File saved to: $OUTPUT_PATH"
    else
      echo "❌ Export failed again. Please check manually."
      exit 1
    fi
  else
    echo "No prefix

