#!/bin/sh
# Place in /usr/local/bin
LOG="/var/log/docker-cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== Docker Cleanup Started: $DATE ===" >> "$LOG"

# Remove stopped containers
echo "--- Container prune ---" >> "$LOG"
docker container prune -f >> "$LOG" 2>&1

# Remove unused images
echo "--- Image prune ---" >> "$LOG"
docker image prune -a -f >> "$LOG" 2>&1

# Remove build cache
echo "--- Builder prune ---" >> "$LOG"
docker builder prune -a -f >> "$LOG" 2>&1

# Log disk usage after
echo "--- Disk usage after ---" >> "$LOG"
df -h /var/lib/containerd >> "$LOG" 2>&1

echo "=== Docker Cleanup Finished: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
echo "" >> "$LOG"