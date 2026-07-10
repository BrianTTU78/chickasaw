#!/usr/bin/bash
##########################################
# Description: Manage Artifactory
#
# Written By: Brian Dickey
# Date: 4/27/26
# Version: 1.0
##########################################
SCRIPT_NAME="manageArt.sh"
ACTION="${1}"

SERVICES=(
  artifactory
  nginx
  postgresql
  router
  metadata
  frontend
  access
  event
  observability
  jfconnect
  integration
  insight
)

ERROR_EXIT() {
    echo ""
    echo "Exiting ..."
    echo ""
    exit 1
} #END ERROR_EXIT

USAGE() {
    echo "#######################"
    echo "USAGE:"
    echo "#######################"
    echo "./${SCRIPT_NAME} stop"
    echo "./${SCRIPT_NAME} start"
    echo "./${SCRIPT_NAME} status"
    echo ""
    echo ""
} #END USAGE

STATUS() {
  echo "Artifactory Service Status"
  echo "=========================="

  for svc in "${SERVICES[@]}"; do
    # Right-align service names to 20 characters
    printf "%13s : " "$svc"

    if systemctl list-unit-files | grep -q "^${svc}.service"; then
      if systemctl is-active --quiet "$svc"; then
        echo "RUNNING"
      else
        echo "STOPPED / FAILED"
      fi
    else
      echo "SERVICE NOT FOUND"
    fi
  done
} #END STATUS

START_SERVICE()
  {
  sudo systemctl start artifactory
  sudo systemctl status artifactory
  } #END START SERVICE

STOP_SERVICE()
  {
  SERVICE="artifactory"
  TIMEOUT=60

  echo "Stopping ${SERVICE}..."
  sudo systemctl stop "${SERVICE}" || true

  echo "Waiting for Artifactory processes to stop..."
  end=$((SECONDS + TIMEOUT))

  while pgrep -f 'artifactory|jf-router|access|tomcat|frontend|metadata|event|jfconfig|topology|observability' >/dev/null; do
    if (( SECONDS >= end )); then
      echo "Timeout reached. Killing remaining Artifactory processes..."
      sudo pkill -TERM -f 'artifactory|jf-router|access|tomcat|frontend|metadata|event|jfconfig|topology|observability' || true
      sleep 10
      sudo pkill -KILL -f 'artifactory|jf-router|access|tomcat|frontend|metadata|event|jfconfig|topology|observability' || true
      break
    fi
    sleep 2
  done
} #END STOP_SERVICE

KILL_PIDS()
  {
  echo "Removing stale PID files..."
  sudo find /data01/artifactory/var -name "*.pid" -type f -delete 2>/dev/null || true

  echo "Checking remaining processes..."
  ps -ef | grep -E 'artifactory|jf-router|access|tomcat|frontend|metadata|event|jfconfig|topology|observability' | grep -v grep || echo "No Artifactory processes running."

  echo "Checking ports..."
  sudo ss -lntp | grep -E '8081|8082|8040|8045|8046|8047|8020|8021|8071' || echo "No Artifactory ports listening."

  echo "Artifactory stop cleanup complete."
}

##################################
# MAIN FUNCTION
##################################
if [[ "${ACTION}" == "" ]]; then
	USAGE
	ERROR_EXIT
else
	echo "#########################"
	echo "        INPUTS"
	echo "#########################"
  echo "ACTION: ${ACTION}"
  echo ""
fi

if [[ ${ACTION} == "start" ]]; then
  START_SERVICE
  sleep 30
  STATUS
elif [[ ${ACTION} == "stop" ]]; then
  STOP_SERVICE
  KILL_PIDS
elif [[ ${ACTION} == "status" ]]; then
  STATUS
else
  echo "ERROR: Incorrect Action!"
  USAGE
  ERROR_EXIT
fi

