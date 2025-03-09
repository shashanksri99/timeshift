#!/bin/bash

set -e  # Exit script if any command fails
set -x # Run Script in verbose mode

# Backup Type: D = Daily
BACKUP_TYPE="D"
BACKUP_DIR="/media"
EMAIL="gaanaiphone@gmail.com"
DISK_USAGE_THRESHOLD=80

# Logging
LOGFILE="/var/log/timeshift/scriptLog/timeshift-advanced-$(date +%Y-%m-%d).log"
echo -e "============================\n" >> $LOGFILE
echo -e "$(date) - Running Timeshift Backup ($BACKUP_TYPE)\n" >> $LOGFILE

# Delete log files older than 60 days
if find /var/log -name "timeshift-advanced-*.log" -type f -mtime +60 | grep -q .; then
    find /var/log -name "timeshift-advanced-*.log" -type f -mtime +60 -exec rm {} \;
    echo -e "✅ Log files older than 60 days deleted.\n" >> $LOGFILE
fi

# Ensure backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "❌ Error: Backup directory $BACKUP_DIR not found!\n" >> $LOGFILE
    exit 1
fi

# Take a snapshot
echo -e "📸 Taking a snapshot...\n" >> $LOGFILE
timeshift --create --comments "$BACKUP_TYPE Backup" --tags $BACKUP_TYPE >> $LOGFILE 2>&1
echo -e "✅ Snapshot taken successfully.\n" >> $LOGFILE

# Check disk usage
CURRENT_USAGE=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$CURRENT_USAGE" -ge "$DISK_USAGE_THRESHOLD" ]; then
    echo -e "⚠️ Disk usage exceeded $DISK_USAGE_THRESHOLD%. Purging old backups, keeping the latest 5...\n" >> $LOGFILE
    timeshift --list | grep 'Snapshot' | awk 'NR>6 {print $4}' | xargs -I {} timeshift --delete --snapshot-id {} >> $LOGFILE 2>&1
fi

# Delete backups older than 30 days
if timeshift --list | grep 'Snapshot' | awk -v date="$(date -d '30 days ago' +%Y-%m-%d)" '$3 < date' | grep -q .; then
    echo -e "🗑️ Deleting backups older than 30 days...\n" >> $LOGFILE
    timeshift --list | grep 'Snapshot' | awk -v date="$(date -d '30 days ago' +%Y-%m-%d)" '$3 < date {print $4}' | xargs -I {} timeshift --delete --snapshot-id {} >> $LOGFILE 2>&1
fi

# Send Email Notification using Docker
SUBJECT="Timeshift $BACKUP_TYPE Backup Report - $(hostname)"
BODY="Timeshift $BACKUP_TYPE backup completed on $(date).\n\nDisk usage: $CURRENT_USAGE%.\n\nRecent logs:\n$(tail -n 20 $LOGFILE)"

docker run --rm email-sender "$EMAIL" "$SUBJECT" "$BODY" >> $LOGFILE 2>&1

echo -e "✅ Backup and notification completed!\n" >> $LOGFILE

set +x # exit verbose mode
set +e # exit error mode