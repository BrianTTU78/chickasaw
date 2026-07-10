#!/bin/bash
############################################
# Description: This script creates a GIT tag
#              for every build
#
# Written By: Brian Dickey
# Date: 2/27/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="online_server_check.sh"

FILENAME=$1

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [FILE NAME]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} servers.txt"
   echo ""
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

CREATE_ARRAY() {
    servers=()
    while IFS= read -r line; do
        SERVERS+=("$line")
    done < ${FILENAME}
} #END OPEN FILE

VERIFY_STATUS() {
    for server in ${SERVERS[@]};
        do
          if ping -c 1 -W 2 "$server" &> /dev/null; then
              echo "$server is alive ..."
          else
              echo "$server is NOT alive ..."
          fi
        done
} #END OPEN FILE

# MAIN
echo "##################################"
echo "#          Variables"
echo "##################################"
echo "FILENAME: ${FILENAME}"
echo ""
CREATE_ARRAY
VERIFY_STATUS


