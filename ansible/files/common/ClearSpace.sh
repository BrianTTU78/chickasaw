#!/usr/bin/env bash
##########################################
# Description: ClearSpace.sh — Clean up logs to make space
#
# Written By: Michael Salazar
# Updated By: Michael Salazar
# Date: 2026-06-08
# Version: 1.2
##########################################

set -euo pipefail
trap 'log "ERROR" "Unexpected error on line $LINENO — exiting." >&2; exit 1' ERR

############################################################
# VARIABLES
############################################################

# Script identity — update here if the script is renamed
SCRIPT_NAME="ClearSpace.sh"

# Log file where output is written
LOG_FILE="/var/log/clearspace.log"

# Dry run mode default (1 = preview only, 0 = delete files)
# Override at runtime with --dry-run or --execute
DRY_RUN=1

# Unified cleanup rules — used when no -t flags are passed at runtime
# Format: "PATH:EXT_PATTERN:DAYS"
# Use EXT_PATTERN="*" to delete ALL files regardless of extension
TARGETS=(
    "/var/log/temp:*.log:14"
    "/var/log/net/temp:*.gz:30"
    "/tmp:*.json:7"
    "/opt/app/cache:*:5"   # example: delete ALL files older than 5 days
)

# Runtime targets populated by -t flags; overrides TARGETS if non-empty
CLI_TARGETS=()

############################################################
# USAGE
############################################################

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  -d, --dry-run              Preview files that would be deleted (no changes made) [default]
  -x, --execute              Delete files for real
  -t, --target PATH:EXT:DAYS Add a cleanup target (repeatable; overrides script defaults)
  -l, --log-file PATH        Override the default log file location
  -h, --help                 Show this help message and exit

Examples:
  $(basename "$0")                         # defaults to dry run with hardcoded targets
  $(basename "$0") --dry-run               # explicit dry run with hardcoded targets
  $(basename "$0") --execute               # live deletion with hardcoded targets

  # Test specific targets interactively before promoting to cron:
  $(basename "$0") -d -l /tmp/clearspace_test.log -t "/var/log/temp:*.log:14" -t "/tmp:*.json:7"

  # Same args promoted to cron (swap -d for -x and point log to production path):
  $(basename "$0") -x -l /var/log/clearspace.log -t "/var/log/temp:*.log:14" -t "/tmp:*.json:7"
EOF
    exit 0
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
            CLI_TARGETS+=("$2")
            shift 2
            ;;
        -l|--log-file)
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

# If -t flags were passed, use them; otherwise fall back to hardcoded TARGETS
if [[ ${#CLI_TARGETS[@]} -gt 0 ]]; then
    TARGETS=("${CLI_TARGETS[@]}")
fi

############################################################
# FUNCTIONS
############################################################

log() {
    local level="$1"
    shift
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[$ts] [$level] $*"

    # Errors go to stderr; everything goes to the log file
    if [[ "$level" == "ERROR" ]]; then
        echo "$msg" | tee -a "$LOG_FILE" >&2
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        echo "$msg" | tee -a "$LOG_FILE"
    else
        echo "$msg" >> "$LOG_FILE"
    fi
}

debug() {
    [[ "$DRY_RUN" -eq 1 ]] && log "DEBUG" "$*" || true
}

############################################################
# START
############################################################

mkdir -p "$(dirname "$LOG_FILE")"

log "INFO" "Starting $SCRIPT_NAME"
log "INFO" "=== Cleanup started (dry_run=$DRY_RUN) ==="

# Summary counters
TOTAL_FILES=0
TOTAL_BYTES=0

############################################################
# MAIN LOOP — iterate through TARGETS
############################################################

for entry in "${TARGETS[@]}"; do

    TARGET_PATH="${entry%%:*}"
    REST="${entry#*:}"
    EXT_PATTERN="${REST%%:*}"
    DAYS="${REST##*:}"

    if [[ ! -d "$TARGET_PATH" ]]; then
        log "WARN" "'$TARGET_PATH' is not a directory — skipping"
        continue
    fi

    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        log "WARN" "Invalid days value '$DAYS' for '$TARGET_PATH' — skipping"
        continue
    fi

    if [[ "$EXT_PATTERN" == "*" ]]; then
        log "INFO" "Cleaning ALL files in '$TARGET_PATH' (older than $DAYS days)"
        FIND_CMD=(find "$TARGET_PATH" -type f -mtime +"$DAYS")
    else
        log "INFO" "Cleaning '$TARGET_PATH' (older than $DAYS days, matching $EXT_PATTERN)"
        FIND_CMD=(find "$TARGET_PATH" -type f -mtime +"$DAYS" -name "$EXT_PATTERN")
    fi

    debug "Running: ${FIND_CMD[*]}"

    # Collect file list
    FILE_LIST=()
    while IFS= read -r f; do
        FILE_LIST+=("$f")
    done < <("${FIND_CMD[@]}")

    # Count + accumulate size
    for f in "${FILE_LIST[@]}"; do
        if [[ -f "$f" ]]; then
            size=$(stat -c%s "$f" 2>/dev/null || echo 0)
            TOTAL_BYTES=$((TOTAL_BYTES + size))
            TOTAL_FILES=$((TOTAL_FILES + 1))
        fi
    done

    ############################################################
    # AGE + SIZE REPORTING
    ############################################################

    report_file() {
        local f="$1"
        local mtime secs days hours mins secs2 bytes size_fmt
        mtime=$(stat -c %y "$f")
        secs=$(( $(date +%s) - $(date -d "$mtime" +%s) ))
        days=$((secs/86400))
        hours=$((secs%86400/3600))
        mins=$((secs%3600/60))
        secs2=$((secs%60))
        bytes=$(stat -c%s "$f")
        if (( bytes < 1048576 )); then
            size_fmt="$(awk "BEGIN {printf \"%.1f KB\", $bytes/1024}")"
        else
            size_fmt="$(awk "BEGIN {printf \"%.1f MB\", $bytes/1048576}")"
        fi
        log "INFO" "$f  AGE: ${days}d ${hours}h ${mins}m ${secs2}s  SIZE: $size_fmt"
    }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        debug "Files that WOULD be deleted:"
        for f in "${FILE_LIST[@]}"; do
            [[ -f "$f" ]] && report_file "$f"
        done
    else
        for f in "${FILE_LIST[@]}"; do
            [[ -f "$f" ]] && report_file "$f"
        done

        if [[ ${#FILE_LIST[@]} -gt 0 ]]; then
            printf "%s\0" "${FILE_LIST[@]}" | xargs -0 rm -f 2>>"$LOG_FILE"
        else
            log "INFO" "No files found matching criteria in '$TARGET_PATH' — nothing to delete"
        fi
    fi

done

############################################################
# SUMMARY
############################################################

HUMAN_SIZE=$(awk "BEGIN {
    b = $TOTAL_BYTES
    if (b >= 1073741824)      printf \"%.1f GB\", b/1073741824
    else if (b >= 1048576)    printf \"%.1f MB\", b/1048576
    else if (b >= 1024)       printf \"%.1f KB\", b/1024
    else                      printf \"%d B\", b
}")

log "INFO" "=== SUMMARY ==="
log "INFO" "Files affected: $TOTAL_FILES"
log "INFO" "Space affected: $HUMAN_SIZE"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "INFO" "Dry run mode enabled — no files were deleted"
else
    log "INFO" "Cleanup completed — files deleted"
fi

log "INFO" "=== Cleanup finished ==="
log "INFO" "$SCRIPT_NAME finished"
exit 0