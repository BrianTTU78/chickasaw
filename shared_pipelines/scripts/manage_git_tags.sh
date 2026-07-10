#!/usr/bin/bash
############################################
# Description: This script creates a GIT tag
#              for every build
#
# Written By: Brian Dickey
# Date: 2/27/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="manage_git.sh"
FULL_NAME="Brian Dickey"
EMAIL="brian.dickey@chickasaw.net"

ACTION="${1^^}"
APP_VERSION="${2}"
GIT_TAG="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ACTION] [APP_VERSION]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} CREATE 1.0"
   echo "${SCRIPT_NAME} FIND 1.0"
   echo ""
   echo "NOTE: APP_VERSION variable is typically set in ADO Library variables ..."
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

SETUP_USER() {
   echo "INFO: Setting GIT Username & Email ..."
   GIT_USER_CMD="git config --global user.name ${FULL_NAME}"
   GIT_EMAIL_CMD="git config --global user.email ${EMAIL}"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${GIT_USER_CMD}"
      echo "DEBUG: ${GIT_EMAIL_CMD}"
   fi

   eval ${GIT_USER_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT user set successful ..."
   else
      echo "ERROR: GIT user set failed!"
      ERROR_EXIT
   fi

   eval ${GIT_EMAIL_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT user email set successful ..."
      echo ""
   else
      echo "ERROR: GIT user email set failed!"
      ERROR_EXIT
   fi

   } #END SETUP_USER

SET_ADO_VARIABLES() {
   echo "##vso[task.setvariable variable=GIT_TAG]$GIT_TAG"
   echo "##vso[task.setvariable variable=GIT_TAG;isOutput=true]$GIT_TAG"
} #END SET_ADO_VARIABLES

CHECK_TAG_EXISTS() {
   echo "INFO: Checking if tag ${GIT_TAG} already exists ..."
   EXISTING_TAG_CMD="git ls-remote --tags origin \"${GIT_TAG}\""
   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${EXISTING_TAG_CMD}"
   fi

   EXISTING_TAG=$(eval "${EXISTING_TAG_CMD}")
   
   if [[ ! -z "${EXISTING_TAG}" ]]; then
      echo "INFO: Tag ${GIT_TAG} already exists. Skipping tagging."
      ERROR_EXIT
   else
      echo "INFO: Tag ${GIT_TAG} does not exist. Proceeding with tagging..."
   fi
}

SET_FEATURE_TAG() {
   echo "INFO: Setting Feature Tag ..."
   COMMIT_ID_CMD="git rev-parse --short HEAD"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${COMMIT_ID_CMD}"
   fi

   COMMIT_ID=$(eval ${COMMIT_ID_CMD})

   GIT_TAG=${APP_VERSION}.${COMMIT_ID}
   echo "INFO: GIT_TAG: ${GIT_TAG}"
   SET_ADO_VARIABLES
   exit 0
} #END SET_FEATURE_TAG

GET_CURRENT_BRANCH() {
   echo "INFO: Determining if Feature Build ..." 
   if [[ "${BUILD_SOURCEBRANCHNAME}" == "main" ]]; then
      echo "INFO: GIT Branch is: ${BUILD_SOURCEBRANCHNAME} ..."
   else
      echo "INFO: Current Branch is NOT main!"
      SET_FEATURE_TAG
   fi

} #END GET_CURRENT_BRANCH

FIND_LATEST_TAG() {
   echo "INFO: Finding Latest GIT Tag ..."
   LATEST_GIT_TAG_CMD="git tag -l ${APP_VERSION}.* | sort -Vr | head -1"
   
   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${LATEST_GIT_TAG_CMD}"
   fi

   LATEST_GIT_TAG_OUTPUT=$(eval ${LATEST_GIT_TAG_CMD})
   
   if [ -z "${LATEST_GIT_TAG_OUTPUT}" ]; then
      echo "WARNING: No GIT tag found ..."
      echo "INFO: Setting GIT tag: ${APP_VERSION}.0"
      LATEST_GIT_TAG_OUTPUT="${APP_VERSION}.0"
   fi

   RC=$?
   if [ ${RC} -eq 0 ]; then
      echo "INFO: Current Tag: ${LATEST_GIT_TAG_OUTPUT}"
   else
      echo "ERROR: GIT Find Latest Tag Failed!"
      ERROR_EXIT
   fi
   } #END FIND_LATEST_TAG

DETERMINE_NEXT_TAG() {
   OLD_BUILD_NUMBER=`echo ${LATEST_GIT_TAG_OUTPUT} | awk -F"." '{print $3}'`
   NEW_BUILD_NUMBER=$(($OLD_BUILD_NUMBER+1))
   GIT_TAG="${APP_VERSION}.${NEW_BUILD_NUMBER}"
   echo "INFO: New GIT tag: ${GIT_TAG}"
   SET_ADO_VARIABLES
   } #END DETERMINE_NEXT_TAG

GIT_TAGGING() {
   echo "INFO: Creating GIT Tag from ${BUILD_SOURCEBRANCHNAME} ..."
   git tag ${GIT_TAG} -m "AUTOMATION: Creating tag from HEAD revision"

   RC=$?
   if [ ${RC} -eq 0 ]; then
      echo "INFO: GIT Tagging Successful ..."
      echo ""
   else
      echo "ERROR: GIT Tagging Failed!"
      ERROR_EXIT
   fi
   }

GIT_UPDATE_REPO() {
   echo "INFO: Pushing GIT Tag to Repo ..."
   GIT_PUSH_TAG_CMD="git push --tag"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${GIT_PUSH_TAG_CMD}"
   fi

   GIT_TAG_OUTPUT=$(eval ${GIT_PUSH_TAG_CMD})
   
   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT Push Successful ..."
      echo ""
   else
      echo "ERROR: GIT Push Failed!"
      ERROR_EXIT
   fi
   } #END GIT_UPDATE_REPO

GIT_VERIFY_TAG_EXISTS() {
   echo "INFO: Verify GIT Tag Exists: ${GIT_TAG} ..."
   VERIFY_TAG_CMD="git tag | grep ${GIT_TAG}"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${VERIFY_TAG_CMD}"
   fi

   VERIFY_TAG_OUTPUT=$(eval ${VERIFY_TAG_CMD})

   if [ -z "${VERIFY_TAG_OUTPUT}" ]; then
      echo "ERROR: Tag does not exist!"
      ERROR_EXIT
   fi
      echo "INFO: Tag Exists ..."
      echo "INFO: Setting ADO Variable GIT_TAG: ${GIT_TAG}"
      SET_ADO_VARIABLES
      echo "INFO: Tagging Complete ..."
   } #END GIT_VERIFY_TAG_EXISTS

##################################
# MAIN ROUTINE
##################################
if [[ -z "${GIT_TAG}" ]]; then
   GIT_TAG="Not Set"
fi

if [[ -z "${APP_VERSION}" ]]; then
	USAGE
	ERROR_EXIT
else
	echo "#########################"
	echo "        INPUTS"
	echo "#########################"
   echo "ACTION: ${ACTION}"
   echo "APP_VERSION: ${APP_VERSION}"
   echo "GIT_TAG: ${GIT_TAG}"
   echo ""
fi
SETUP_USER

if [[ "${GIT_TAG}" != "Not Set" ]]; then
   CHECK_TAG_EXISTS
fi

GET_CURRENT_BRANCH

if [[ ${ACTION} == "FIND" ]]; then
   FIND_LATEST_TAG
   DETERMINE_NEXT_TAG
elif [[ ${ACTION} == "CREATE" ]]; then
   if [[ "${GIT_TAG}" != "Not Set" ]]; then
      GIT_TAGGING
      GIT_UPDATE_REPO
      GIT_VERIFY_TAG_EXISTS
   else
      echo "ERROR: Git Tag Not Set!"
      ERROR_EXIT
   fi
else
   echo "ERROR: Improper action provided!"
   USAGE
   ERROR_EXIT
fi