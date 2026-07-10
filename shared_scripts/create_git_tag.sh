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
SCRIPT_NAME="create_git_tag.sh"

RELEASE="${1}"
GIT_COMMIT="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [RELEASE] [COMMIT ID]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} 1.0"
   echo "${SCRIPT_NAME} 1.0 a3df3dq"
   echo ""
   echo "NOTE: RELEASE variable is typically set in ADO Library variables ..."
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

CHECK_TAG_EXISTS() {
   echo "INFO: Checking if tag ${RELEASE} already exists ..."
   EXISTING_TAG=$(git tag -l "${RELEASE}")
   if [[ ! -z "${EXISTING_TAG}" ]]; then
      echo "INFO: Tag ${RELEASE} already exists. Skipping tagging."
      exit 0
   else
      echo "INFO: Tag ${RELEASE} does not exist. Proceeding with tagging..."
   fi
}

GET_CURRENT_BRANCH() {
   echo "INFO: Determining if Feature Build ..." 
   if [[ "${BUILD_SOURCEBRANCHNAME}" == "main" ]]; then
      echo "INFO: GIT Branch is: ${BUILD_SOURCEBRANCHNAME} ..."
   else
      echo "ERROR: Current Branch is NOT main!"
      ERROR_EXIT
   fi

} #END GET_CURRENT_BRANCH

FIND_LATEST_TAG() {
   echo "INFO: Finding Latest GIT Tag ..."
   LATEST_GIT_TAG_CMD="git tag -l ${RELEASE}.* | sort -Vr | head -1"
   if [[ DEBUG -ne 0 ]]; then
      echo "DEBUG: ${LATEST_GIT_TAG_CMD}"
   fi

   LATEST_GIT_TAG_OUTPUT=$(eval ${LATEST_GIT_TAG_CMD})
   
   if [ -z "${LATEST_GIT_TAG_OUTPUT}" ]; then
      echo "WARNING: No GIT tag found ..."
      echo "INFO: Setting GIT tag: ${RELEASE}.0"
      LATEST_GIT_TAG_OUTPUT="${RELEASE}.0"
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
   NEW_GIT_TAG="${RELEASE}.${NEW_BUILD_NUMBER}"
   echo "INFO: New GIT tag: ${NEW_GIT_TAG}"
   } #END DETERMINE_NEXT_TAG

GIT_TAGGING() {
   if [ -z "${GIT_COMMIT}" ]; then
      echo "INFO: Creating GIT Tag from ${BUILD_SOURCEBRANCHNAME} ..."
      git tag ${NEW_GIT_TAG} -m "Creating automated tag for build off head revision"
   else
      echo "INFO: Creating GIT Tag from ${GIT_COMMIT} ..."
      git tag "${NEW_GIT_TAG}" ${GIT_COMMIT} -m "Creating automated tag for build off commit id"
   fi
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

   if [[ DEBUG -ne 0 ]]; then
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
   echo "INFO: Verify GIT Tag Exists: ${NEW_GIT_TAG} ..."
   VERIFY_TAG_CMD="git tag | grep ${NEW_GIT_TAG}"

   if [[ DEBUG -ne 0 ]]; then
      echo "DEBUG: ${VERIFY_TAG_CMD}"
   fi

   VERIFY_TAG_OUTPUT=$(eval ${VERIFY_TAG_CMD})

   if [ -z "${VERIFY_TAG_OUTPUT}" ]; then
      echo "ERROR: Tag does not exist!"
      ERROR_EXIT
   fi
      echo "INFO: Tag Exists ..."
      echo "INFO: Setting ADO Variable GIT_TAG: ${NEW_GIT_TAG}"
      echo "##vso[task.setvariable variable=GIT_TAG;isOutput=true]$NEW_GIT_TAG"
      echo "INFO: Tagging Complete ..."
   } #END GIT_VERIFY_TAG_EXISTS

##################################
# MAIN ROUTINE
##################################
# RELEASE_TAG is set by MFT pipeline, which sets RELEASE_TAG as env variable
if [[ ! -z "$RELEASE_TAG" ]]; then
   RELEASE="$RELEASE_TAG"
   NEW_GIT_TAG=$RELEASE_TAG
fi
if [[ -z "${RELEASE}" ]]; then
	USAGE
	ERROR_EXIT
else
	echo "#########################"
	echo "        INPUTS"
	echo "#########################"
   echo "RELEASE: ${RELEASE}"
   echo ""
fi
CHECK_TAG_EXISTS
GET_CURRENT_BRANCH
# Generate tag if RELEASE_TAG does not exist
if [[ -z "$RELEASE_TAG" ]]; then
   FIND_LATEST_TAG
   DETERMINE_NEXT_TAG
fi
GIT_TAGGING
GIT_UPDATE_REPO
GIT_VERIFY_TAG_EXISTS
