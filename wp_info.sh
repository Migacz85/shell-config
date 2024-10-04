#!/bin/bash
# Check if WP-CLI is installed
if ! command -v wp &> /dev/null
then
    echo "WP-CLI is not installed. Please install WP-CLI to run this script."
    exit 1
fi

# Ensure running as root or with --allow-root
ALLOW_ROOT="--allow-root"

# 1. Display WordPress core version and update availability
echo "== WordPress Core Version =="
core_version=$(wp core version $ALLOW_ROOT)
core_update=$(wp core check-update $ALLOW_ROOT | awk 'NR>1 {print "Current Version: " $1 ", Update Available: " $2}')


echo "Current Version: $core_version"
if [ -z "$core_update" ]; then
    echo "No core updates available."
else
    echo "Update Available: $core_update"
fi

echo ""

# 2. Display the last database backup from UpdraftPlus
echo "Backups avaliable:"
wp eval '
$backups = UpdraftPlus_Backup_History::get_history();
foreach ($backups as $timestamp => $backup) {
    $date = date("Y-m-d H:i:s", $timestamp);
    if (!empty($backup["db"])) {
        echo "db: " . $date . "\n";
    }
    if (!empty($backup["uploads"]) || !empty($backup["themes"]) || !empty($backup["plugins"]) || !empty($backup["others"])) {
        echo "full backup: " . $date . "\n";
    }
}
' --allow-root

echo ""

# 3. Display Plugin Versions and Update Availability
echo "== Plugin Versions and Updates =="
wp plugin list --fields=name,version,update_version --format=table --allow-root | awk 'NR>1 && $3 != "" {print "" $1 "\t " $2 "\t" $3}'

echo " "

echo "Test sending mails:"
wp eval 'wp_mail("marcin@matrixinternet.ie", "Test Email", "This is a test email from WP-CLI.");' --allow-root