#!/usr/bin/bash
##############################################
# Description: MongoDB Full and Incremental
# backup solution
#
# Date: 1/8/26
# Written By: Brian Dickey & Brandon Dodson
# Version: 1.0
##############################################
ENV=${1^^}
ACTION=${2^^}

# HARD CODED SCRIPT VARS
SCRIPT_NAME="mongodb_oplogbackup.sh"
TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")

# HARD CODED VARS
BASE_BACKUP_DIR="/var/backups/mongodb"
FULL_FILENAME="full_backup_${DB_NAME}_${TIMESTAMP}.bson.gz"
DELTA_FILENAME="delta_backup_${DB_NAME}_${TIMESTAMP}.bson.gz"
RETENTION_DAYS=7

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
    echo "./${SCRIPT_NAME}"
    echo ""
    echo "Examples:"
    echo "------------------"
    echo "${SCRIPT_NAME} [ENV] [ACTION]"
    echo "${SCRIPT_NAME} author full"
    echo "${SCRIPT_NAME} prod incremental"
    echo ""
} #END USAGE

VALIDATE_VARIABLES() {
    echo "INFO: Validating variables ..."
    if [[ ${MONGODB_USER} == "" || ${CONTAINER_NAME} == "" || ${DB_NAME} == "" ]]; then
        echo "ERROR: Required pipeline variables are not set!"

        if [[ ${DEBUG} == 1 ]]; then
           echo "DEBUG: MONGODB_USER: ${MONGODB_USER}"
           echo "DEBUG: MONGODB_PASS: ${MONGODB_PASS}"
           echo "DEBUG: CONTAINER_NAME: ${CONTAINER_NAME}"
           echo "DEBUG: DB_NAME: ${DB_NAME}"
        fi
        ERROR_EXIT
    else
	echo "INFO: Variables verified ..."
    fi
} #END VALIDATE_VARIABLES

SETUP_BACKUP_ENV() {
    echo "INFO: Verifying ${BASE_BACKUP_DIR} exists ..."
    if [[ ! -d "${BASE_BACKUP_DIR}" ]]; then
       mkdir -p ${BASE_BACKUP_DIR}

       RC=$?
       if [[ ${RC} != 0 ]]; then
          echo "INFO: Directory created successfully ..."
       else
          echo "ERROR: Unable to create ${BASE_BACKUP_DIR}!"
          ERROR_EXIT
       fi
    else
        echo "INFO: Directory exists ..."
    fi
    echo ""
} #END SETUP_BACKUP

EXECUTE_BACKUP() {
    echo "INFO: Executing ${ACTION} Backup ..."
    echo ""
    if [[ ${ACTION} == "FULL" ]]; then
       FILE="${BASE_BACKUP_DIR}/${FULL_FILENAME}"
       BACKUP_CMD="docker exec \"${CONTAINER_NAME}\" sh -c \"mongodump -u '${MONGODB_USER}' -p '${MONGODB_PASS}' --authenticationDatabase=admin --db '${DB_NAME}' --archive --gzip\" > ${FILE}"
    else
      FILE="${BASE_BACKUP_DIR}/${DELTA_FILENAME}"
      BACKUP_CMD="docker exec \"${CONTAINER_NAME}\" sh -c \"mongodump -u '${MONGODB_USER}' -p '${MONGODB_PASS}' --authenticationDatabase=admin --db local --collection=oplog.rs --queryFile ${BASE_BACKUP_DIR}/query.js --archive --gzip\" > ${FILE}"
    fi
    if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${BACKUP_CMD}"
    fi
      
    eval ${BACKUP_CMD}
    
    RC=$?
    if [[ ${RC} != 0 ]]; then
       echo "ERROR: Backup Status: FAILED!"
       ERROR_EXIT
    fi 

    if [ -s "${FILE}" ]; then
       echo "INFO: Backup Status: SUCCESS"
       echo "INFO: $(ls -l ${FILE})"
    else
       echo "ERROR: Backup Status: FAILED: ${FILE}"
    fi
    echo ""
} #END EXECUTE_FULL_BACKUP

CREATE_LAST_TIMESTAMP() {
    TIMESTAMP=$(date +"%s")
    echo "INFO: Create timestamp successful backup ..."
    echo ${TIMESTAMP} > "${BASE_BACKUP_DIR}/last_timestamp.txt"
} #END CREATE_LAST_BACKUP_TIMESTAMP

READ_TIMESTAMP() {
    LAST_TIMESTAMP_CMD="cat ${BASE_BACKUP_DIR}/last_timestamp.txt"

    if [[ ${DEBUG} == 1 ]]; then
       echo "DEBUG: ${LAST_TIMESTAMP_CMD}"
    fi

    LAST_TIMESTAMP=`eval ${LAST_TIMESTAMP_CMD}`

    if [[ -f "${BASE_BACKUP_DIR}/last_timestamp.txt" ]]; then
       echo "INFO: Reading Last Backup Timestamp ..."
       echo "INFO: Timestamp: ${LAST_TIMESTAMP}"
    else
       echo "ERROR: Unable to read or locate timestamp!"
       ERROR_EXIT
    fi
} #END READ_TIMESTAMP

CREATE_QUERY() {
    echo "INFO: Creating Query File ..."
    if [[ "${LAST_TIMESTAMP}" != "" ]]; then
       QUERY_STRING="{\"ts\":{\"\$gt\":{\"\$timestamp\":{\"t\":${LAST_TIMESTAMP},\"i\":1}}}}"

       if [[ ${DEBUG} == 1 ]]; then
          echo "DEBUG: ${QUERY_STRING}"
       fi
       echo ${QUERY_STRING} > ${BASE_BACKUP_DIR}/query.js
    
       RC=$?
       if [[ ${RC} != 0 ]]; then
          echo "ERROR: Unable to create query file!"
          ERROR_EXIT
       else
          echo "INFO: Query file created successfully ..."
       fi
    fi
} # END UPDATE_QUERY

DOCKER_COPY_QUERY() {
   echo "INFO: Copy Query.js to Docker Container ..."
   DOCKER_COPY_CMD="docker cp ${BASE_BACKUP_DIR}/query.js ${CONTAINER_NAME}:${BASE_BACKUP_DIR}/query.js"

   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${DOCKER_COPY_CMD}"
   fi

   eval ${DOCKER_COPY_CMD}
   
   RC=$?
   if [[ ${RC} != 0 ]]; then
       echo "ERROR: Unable to copy query.js to container ${CONTAINER_NAME}!"
       ERROR_EXIT
   else
      echo "INFO: Docker copy successful ..."
   fi
} #END DOCKER_COPY_QUERY

BACKUP_CLEANUP() {
    echo "INFO: Locating backups older than ${RETENTION_DAYS} days ..."
    echo "INFO: Location: ${BASE_BACKUP_DIR}"

    if [[ ${ACTION} == "FULL" ]]; then
       BACKUP_PREFIX="full_backup"
    else
       BACKUP_PREFIX="delta_backup"
       
    fi
    CLEANUP_ARRAY_CMD="find \"${BASE_BACKUP_DIR}\" -type f -name \"${BACKUP_PREFIX}_*.bson.gz\" -mtime +${RETENTION_DAYS}"

    if [[ ${DEBUG} == 1 ]]; then
       echo "DEBUG: ${CLEANUP_ARRAY_CMD}"
    else
       eval ${CLEANUP_ARRAY_CMD}
    fi
    
    for file in "${CLEANUP_ARRAY[@]}"; do
        if [[ ${DEBUG} == 1 ]]; then
           echo "DEBUG: Removing ${file}"
        else
           echo "INFO: Removing ${file}"
	   STATUS=1
           REMOVE_CMD="rm -rf ${file}"
           eval ${REMOVE_CMD}
        fi

        RC=$?
        if [[ ${RC} != 0 ]]; then
            echo "WARNING: Unable to remove ${file}!"
        else
            echo "INFO: ${file} removed successfully ..."
        fi
    done

    if [[ ${STATUS} != 1 ]]; then
       echo "INFO: No files found to cleanup ..."
    fi
} #BACKUP_CLEANUP

PRINT_MENU() {
   echo ""
   echo ""
   if [[ ${DEBUG} == 1 ]]; then
      echo "!!! DEBUG ENABLED !!!"
   fi
   echo "##################################"
   echo "          VARIABLES"
   echo "##################################"
   echo "Environment: ${ENV}"
   echo "Container: ${CONTAINER_NAME}"
   echo "Database: ${DB_NAME}"
   echo "Action: ${ACTION}"
   echo "##################################"
   echo "Documentation: https://azdevops.int.chickasaw.net/Tribal%20Services/Enhanced%20Citizen%20Services/_wiki/wikis/Enhanced-Citizen-Services.wiki/114/MongoDB-Backup-Strategy"
   echo ""
   echo ""

} # END PRINT_MENU

#################################
# MAIN ROUTINE
#################################
if [[ "${ACTION}" == "" || ${ACTION} != "FULL" && ${ACTION} != "INCREMENTAL" ]]; then
    USAGE
    exit 1
fi

PRINT_MENU
VALIDATE_VARIABLES
SETUP_BACKUP_ENV
if [[ ${ACTION} == 'INCREMENTAL' ]]; then
   READ_TIMESTAMP
   CREATE_QUERY
   DOCKER_COPY_QUERY
fi
EXECUTE_BACKUP
CREATE_LAST_TIMESTAMP
BACKUP_CLEANUP

echo "Script Complete ..."
