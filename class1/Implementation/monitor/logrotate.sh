#!/bin/bash
# === Configuration ===
LOG_DIR="/var/log/"         # Directory containing the logs
MAX_BACKUPS=5               # Number of backups to keep
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# === Rotate Logs ===
cd "$LOG_DIR" || exit 1

# Step 1: Process each .log file in the directory
for LOG_FILE in *.log; do
    if [[ -f "$LOG_FILE" ]]; then
        echo "Rotating log file: $LOG_FILE"
        
        # Compress current log file
        mv "$LOG_FILE" "${LOG_FILE}.${TIMESTAMP}"
        gzip "${LOG_FILE}.${TIMESTAMP}"
        echo "Compressed: ${LOG_FILE}.${TIMESTAMP}.gz"
        
        # Step 2: Remove old backups if more than MAX_BACKUPS
        BACKUPS=($(ls -t ${LOG_FILE}.*.gz 2>/dev/null))
        COUNT=${#BACKUPS[@]}

        if (( COUNT > MAX_BACKUPS )); then
            for ((i=MAX_BACKUPS; i<COUNT; i++)); do
                echo "Deleting old backup: ${BACKUPS[$i]}"
                rm -f "${BACKUPS[$i]}"
            done
        fi
    fi
done