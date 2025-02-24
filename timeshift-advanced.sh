#!/bin/bash

# Backup Type: D = Daily, W = Weekly, M = Monthly
BACKUP_TYPE=$1
BACKUP_DIR="/media"
EMAIL="gaanaiphone@gmail.com"
DISK_USAGE_THRESHOLD=80

# Logging
LOGFILE="/var/log/timeshift-advanced.log"
echo "============================" >> $LOGFILE
echo "$(date) - Running Timeshift Backup ($BACKUP_TYPE)" >> $LOGFILE

# Ensure backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Error: Backup directory $BACKUP_DIR not found!" >> $LOGFILE
    exit 1
fi

# Take a snapshot
timeshift --create --comments "$BACKUP_TYPE Backup" --tags $BACKUP_TYPE >> $LOGFILE 2>&1

# Check disk usage
CURRENT_USAGE=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$CURRENT_USAGE" -ge "$DISK_USAGE_THRESHOLD" ]; then
    echo "⚠️ Disk usage exceeded $DISK_USAGE_THRESHOLD%. Purging old backups..." >> $LOGFILE
    timeshift --delete --all --scripted >> $LOGFILE 2>&1
fi

# Send Email Notification using Docker
SUBJECT="Timeshift $BACKUP_TYPE Backup Report - $(hostname)"
BODY="Timeshift $BACKUP_TYPE backup completed on $(date).\n\nDisk usage: $CURRENT_USAGE%.\n\nRecent logs:\n$(tail -n 20 $LOGFILE)"

docker run --rm email-sender "$EMAIL" "$SUBJECT" "$BODY" >> $LOGFILE 2>&1

echo "✅ Backup and notification completed!" >> $LOGFILE