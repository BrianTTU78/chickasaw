#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status, or an unset variable is used.
set -euo pipefail

# ==============================================================================
# CONFIGURATION & TOGGLES
# ==============================================================================
# Set DRY_RUN to "true" to preview actions. Change to "false" to execute live deletions.
DRY_RUN="false"

# Retention configurations
WORKSPACE_RETENTION_DAYS=30
FEATURE_IMAGE_RETENTION_DAYS=5

# Logging destinations
LOG_FILE="/var/log/docker_maintenance.log"

# Counter variables to track metrics for the Dynatrace syslog summary
count_workspaces_deleted=0
count_main_images_deleted=0
count_feature_images_deleted=0

# ==============================================================================
# LOGGING REDIRECTION INTERLOCK
# ==============================================================================
# If this script is run interactively (terminal), we print to the screen.
# If it runs via cron/background, it duplicates and logs everything to the logfile.
if [ ! -t 0 ] && [ -w "$LOG_FILE" ]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

echo "=============================================================================="
echo " TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"
echo "                   DOCKER & ON-PREM PIPELINE MAINTENANCE                      "
echo "=============================================================================="
if [ "$DRY_RUN" = "true" ]; then
    echo " MODE: [DRY-RUN] Previewing actions only. No data will be modified."
else
    echo " MODE: [EXECUTE] Destructive cleanup is active."
fi
echo "=============================================================================="

# Retrieve active images to ensure running containers are never touched
ACTIVE_IMAGES=$(docker ps -a --format '{{.Image}}' | sort -u | paste -sd '|' -)

# ==============================================================================
# STEP 2: STALE WORKSPACE CLEANUP (30 DAYS)
# ==============================================================================
echo -e "\n[Step 2/5] Scanning for pipeline workspaces older than ${WORKSPACE_RETENTION_DAYS} days..."
STALE_WORKSPACES=$(find /data01/docker/ -maxdepth 2 -regextype posix-extended \
  -regex '.*/ada.*_agent[0-9]+/[0-9]+' \
  -mtime +"$WORKSPACE_RETENTION_DAYS" 2>/dev/null || true)

if [ -z "$STALE_WORKSPACES" ]; then
    echo "  -> No workspaces found older than ${WORKSPACE_RETENTION_DAYS} days."
else
    count_workspaces_deleted=$(echo "$STALE_WORKSPACES" | wc -l)
    if [ "$DRY_RUN" = "true" ]; then
        echo "  -> [DRY-RUN] The following stale workspaces would be deleted:"
        echo "$STALE_WORKSPACES" | awk '{print "     - " $0}'
    else
        echo "  -> Removing stale workspaces..."
        echo "$STALE_WORKSPACES" | xargs -I {} rm -rf {}
        echo "  -> Stale workspaces deleted."
    fi
fi

# ==============================================================================
# STEP 3: INTERMEDIATE DOCKER ARTIFACTS
# ==============================================================================
echo -e "\n[Step 3/5] Checking for stopped containers, anonymous volumes, and dead networks..."
if [ "$DRY_RUN" = "true" ]; then
    RECLAIMABLE_CONTAINERS=$(docker system df --format "{{.Reclaimable}}" | head -n 2 | tail -n 1 || echo "0B")
    echo "  -> [DRY-RUN] Standard system prune would reclaim approximately: $RECLAIMABLE_CONTAINERS"
else
    echo "  -> Purging stopped containers, unreferenced networks, and anonymous volumes..."
    docker system prune -f --volumes
fi

# ==============================================================================
# STEP 4: CUSTOM RULES FOR MAIN VS FEATURE IMAGES
# ==============================================================================
echo -e "\n[Step 4/5] Evaluating image versions (Main vs Feature tags)..."

REPOS=$(docker images --format "{{.Repository}}" | sort -u | grep -v "<none>" || true)

for repo in $REPOS; do
    # --------------------------------------------------------------------------
    # RULE A: Main Artifacts (Pure numerical tags 1-3 digits) -> Keep 2 Newest
    # --------------------------------------------------------------------------
    MAIN_IMAGES=$(docker images "$repo" --format "{{.Repository}}:{{.Tag}}" | grep -E ':[0-9]+\.[0-9]+\.[0-9]{1,3}$' | tail -n +3 || true)
    
    if [ -n "$MAIN_IMAGES" ]; then
        while read -r image_to_delete; do
            if [ -z "$image_to_delete" ]; then continue; fi
            count_main_images_deleted=$((count_main_images_deleted + 1))
            if [ "$DRY_RUN" = "true" ]; then
                echo "     - [DRY-RUN] Would prune old MAIN version (outside top 2): $image_to_delete"
            else
                if echo "$image_to_delete" | grep -qE "$ACTIVE_IMAGES"; then continue; fi
                echo "     - Pruning old MAIN version: $image_to_delete"
                docker rmi -f "$image_to_delete" || true
            fi
        done <<< "$MAIN_IMAGES"
    fi

    # --------------------------------------------------------------------------
    # RULE B: Feature Artifacts (Commit hashes or 4+ digit build numbers) -> Keep 5 Days
    # --------------------------------------------------------------------------
    FEATURE_IMAGES=$(docker images "$repo" --format "{{.Repository}}:{{.Tag}}" | grep -E ':[0-9]+\.[0-9]+\.([a-zA-Z0-9]*[a-zA-Z][a-zA-Z0-9]*|[0-9]{4,})$' || true)
    
    if [ -n "$FEATURE_IMAGES" ]; then
        while read -r feature_image; do
            if [ -z "$feature_image" ]; then continue; fi
            
            CREATE_EPOCH=$(docker inspect --format='{{.Created}}' "$feature_image" | xargs date +%s -d)
            NOW_EPOCH=$(date +%s)
            AGE_DAYS=$(( (NOW_EPOCH - CREATE_EPOCH) / 86400 ))
            
            if [ "$AGE_DAYS" -gt "$FEATURE_IMAGE_RETENTION_DAYS" ]; then
                count_feature_images_deleted=$((count_feature_images_deleted + 1))
                if [ "$DRY_RUN" = "true" ]; then
                    echo "     - [DRY-RUN] Would prune old FEATURE version (Age: ${AGE_DAYS} days): $feature_image"
                else
                    if echo "$feature_image" | grep -qE "$ACTIVE_IMAGES"; then continue; fi
                    echo "     - Pruning old FEATURE version (Age: ${AGE_DAYS} days): $feature_image"
                    docker rmi -f "$feature_image" || true
                fi
            fi
        done <<< "$FEATURE_IMAGES"
    fi
done

# ==============================================================================
# STEP 5: BUILDKIT EMIT CACHE
# ==============================================================================
echo -e "\n[Step 5/5] Assessing BuildKit pipeline build-stage caches..."
if [ "$DRY_RUN" = "true" ]; then
    BUILD_CACHE_SIZE=$(docker builder du --format "{{.Size}}" | tail -n 1 || echo "0B")
    echo "  -> [DRY-RUN] Builder prune would evaluate up to $BUILD_CACHE_SIZE of structural layers inside containerd."
else
    echo "  -> Flashing BuildKit builder engine layer cache..."
    docker builder prune -f
fi

echo -e "\n=============================================================================="
echo "                        MAINTENANCE RUN COMPLETE                              "
echo "=============================================================================="

# ==============================================================================
# SYSLOG INGESTION SUMMARY (FOR DYNATRACE)
# ==============================================================================
# Format log metrics cleanly as a structured space-separated key-value string.
# Dynatrace log ingestion patterns natively parse this layout without complex regex rules.
SYSLOG_TAG="docker-maintenance"
SUMMARY_MSG="status=success dry_run=${DRY_RUN} pruned_workspaces=${count_workspaces_deleted} pruned_main_images=${count_main_images_deleted} pruned_feature_images=${count_feature_images_deleted}"

# Emit directly to standard syslog facility
logger -t "$SYSLOG_TAG" "$SUMMARY_MSG"
