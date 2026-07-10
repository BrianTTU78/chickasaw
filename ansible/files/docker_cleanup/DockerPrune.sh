#!/usr/bin/env bash
##########################################
# Description: Prune old Docker resources (images, containers,
#              volumes, networks). Supports dry-run, execute,
#              per-target age overrides, and custom log file
#              via command-line arguments. Safe for cron use.
#
# Written By: Michael Salazar
# Updated By: Michael Salazar
# Date: 6/8/26
# Version: 1.1
##########################################

set -euo pipefail

LOG_FILE="/var/log/dockerprune.log"
SCRIPT_NAME="DockerPrune.sh"

# DRY RUN default (1 = show what WOULD be removed, 0 = actually remove)
# Override at runtime with -d/--dry-run or -x/--execute
DRY_RUN=1

##########################################
# TARGETS
# Format: "TYPE:AGE_IN_DAYS"
# TYPE options:
#   images      → docker images
#   containers  → docker containers
#   volumes     → docker volumes
#   networks    → docker networks
#
# AGE_IN_DAYS is converted to hours for Docker's --filter "until=..."
# Defaults used when no -t/--target flags are passed at runtime.
##########################################

TARGETS=(
    "images:30"
    "containers:14"
    "volumes:60"
    "networks:90"
)

# Runtime target overrides — populated by -t/--target flags
CLI_TARGETS=()

##########################################
# FUNCTIONS
##########################################

############################################################
# USAGE
############################################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  -d, --dry-run              Preview Docker resources that would be removed (no changes made) [default]
  -x, --execute              Remove Docker resources for real
  -t, --target TYPE:DAYS     Target a specific resource type with an age threshold in days.
                             Repeatable. If omitted, script runs against all default targets.
                             Valid types: images, containers, volumes, networks
  -l, --log-file PATH        Override the default log file path.
                             Default: /var/log/dockerprune.log
  -h, --help                 Show this help message and exit

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --execute
  $(basename "$0") --execute --target images:30 --target containers:14
  $(basename "$0") --dry-run --target volumes:60 --log-file /tmp/dockerprune_test.log
  $(basename "$0")                                # defaults to dry run, all targets
EOF
    exit 0
}

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[$ts] $*" | tee -a "$LOG_FILE"
    else
        echo "[$ts] $*" >> "$LOG_FILE"
    fi
}

debug() {
    [[ "$DRY_RUN" -eq 1 ]] && log "[DEBUG] $*"
}

docker_age_seconds() {
    local created="$1"
    # Strip trailing UTC if present: "2026-05-13 10:23:45 +0000 UTC" → "2026-05-13 10:23:45 +0000"
    created="${created/ UTC/}"
    local now=$(date +%s)
    local created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
    echo $((now - created_ts))
}

format_bytes() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1048576 )); then
        awk "BEGIN {printf \"%.1fKB\", $bytes/1024}"
    else
        awk "BEGIN {printf \"%.1fMB\", $bytes/1048576}"
    fi
}

############################################################
# ARGUMENT PARSING
############################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -x|--execute)
            DRY_RUN=0
            shift
            ;;
        -t|--target)
            [[ -z "${2:-}" ]] && { echo "[ERROR] --target requires a TYPE:DAYS argument." >&2; exit 1; }
            CLI_TARGETS+=("$2")
            shift 2
            ;;
        -l|--log-file)
            [[ -z "${2:-}" ]] && { echo "[ERROR] --log-file requires a path argument." >&2; exit 1; }
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1
            ;;
    esac
done

# If -t/--target flags were passed, override the default TARGETS array
if [[ ${#CLI_TARGETS[@]} -gt 0 ]]; then
    TARGETS=("${CLI_TARGETS[@]}")
fi

##########################################
# START
##########################################

mkdir -p "$(dirname "$LOG_FILE")"
log "Starting $SCRIPT_NAME"
log "=== Docker Cleanup Started (dry_run=$DRY_RUN) ==="

TOTAL_ITEMS=0
TOTAL_BYTES=0

##########################################
# MAIN LOOP
##########################################

for entry in "${TARGETS[@]}"; do

    TYPE="${entry%%:*}"
    DAYS="${entry##*:}"

    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        log "[WARN] Invalid days value '$DAYS' for target '$TYPE' — skipping"
        continuewhch
    fi

    HOURS=$((DAYS * 24))
    log "[INFO] Processing $TYPE older than $DAYS days ($HOURS hours)"

    ##########################################
    # BUILD DOCKER COMMAND
    ##########################################

    case "$TYPE" in
        images)
            LIST_CMD=(docker images --format "{{.ID}} {{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Size}}")
            PRUNE_CMD=(docker image prune --all --force --filter "until=${HOURS}h")
            ;;
        containers)
            LIST_CMD=(docker ps -a --format "{{.ID}} {{.Image}} {{.CreatedAt}} {{.Size}}")
            PRUNE_CMD=(docker container prune --force --filter "until=${HOURS}h")
            ;;
        volumes)
            LIST_CMD=(docker volume ls -q)
            PRUNE_CMD=(docker volume prune --force)
            ;;
        networks)
            LIST_CMD=(docker network ls --format "{{.ID}} {{.Name}} {{.CreatedAt}}")
            PRUNE_CMD=(docker network prune --force)
            ;;
        *)
            log "[WARN] Unknown type '$TYPE' — skipping"
            continue
            ;;
    esac

    debug "List command: ${LIST_CMD[*]}"
    debug "Prune command: ${PRUNE_CMD[*]}"

    ##########################################
    # GATHER ITEMS
    ##########################################

    ITEMS=()
    while IFS= read -r line; do
        ITEMS+=("$line")
    done < <("${LIST_CMD[@]}")

    ##########################################
    # PROCESS ITEMS
    ##########################################

    for item in "${ITEMS[@]}"; do

        case "$TYPE" in
            images)
                ID=$(awk '{print $1}' <<< "$item")
                NAME=$(awk '{print $2}' <<< "$item")
                CREATED=$(awk '{print $3" "$4" "$5" "$6}' <<< "$item")
                SIZE=0
                ;;
            containers)
                ID=$(awk '{print $1}' <<< "$item")
                NAME=$(awk '{print $2}' <<< "$item")
                CREATED=$(awk '{print $3" "$4" "$5" "$6}' <<< "$item")
                SIZE=$(docker container inspect "$ID" --format "{{.SizeRw}}" 2>/dev/null || echo 0)
                SIZE=${SIZE//[!0-9]/}
                SIZE=${SIZE:-0}
                ;;
            volumes)
                ID="$item"
                NAME="$item"
                CREATED=$(docker volume inspect "$item" --format "{{.CreatedAt}}" 2>/dev/null || echo "unknown")
                SIZE=0
                ;;
            networks)
                ID=$(awk '{print $1}' <<< "$item")
                NAME=$(awk '{print $2}' <<< "$item")
                # Strip nanoseconds and duplicate tz offset:
                # "2026-06-02 11:11:26.086130254 -0500 -0500" → "2026-06-02 11:11:26 -0500"
                CREATED=$(awk '{print $3" "$4" "$5}' <<< "$item" | sed 's/\.[0-9]*//')
                SIZE=0
                ;;
        esac

        AGE_SECS=$(docker_age_seconds "$CREATED")
        AGE_DAYS=$((AGE_SECS / 86400))

        # Skip if not old enough
        if (( AGE_DAYS < DAYS )); then
            continue
        fi

        TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
        TOTAL_BYTES=$((TOTAL_BYTES + SIZE))

        log "$TYPE → $NAME  AGE: ${AGE_DAYS}d  SIZE: $(format_bytes "$SIZE")"

    done

    ##########################################
    # PRUNE IF NOT DRY RUN
    ##########################################

    if [[ "$DRY_RUN" -eq 0 ]]; then
        log "[ACTION] Running prune: ${PRUNE_CMD[*]}"
        "${PRUNE_CMD[@]}" >> "$LOG_FILE" 2>&1
    else
        log "[DRY RUN] Would run: ${PRUNE_CMD[*]}"
    fi

done

##########################################
# SUMMARY
##########################################

HUMAN_SIZE=$(format_bytes "$TOTAL_BYTES")

log "=== SUMMARY ==="
log "Items affected: $TOTAL_ITEMS"
log "Space affected: $HUMAN_SIZE"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry run mode — no Docker resources were removed"
else
    log "Cleanup completed — Docker resources removed"
fi

log "=== Docker Cleanup Finished ==="
log "$SCRIPT_NAME finished"
exit 0