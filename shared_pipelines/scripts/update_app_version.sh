#!/usr/bin/bash
############################################
# Description: This script updates the helm
#              tag under EMV-values.yaml
#
# Written By: Brian Dickey
# Date: 5/15/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="update_app_version.sh"
FULL_NAME="Brian Dickey"
EMAIL="brian.dickey@chickasaw.net"

ENV="${1^^}"
APP_NAME="${2}"
GIT_TAG="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ENV] [APP NAME] [APP_VERSION]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} dev cn-ecs-web-app 1.0.1"
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

CHECKOUT_BRANCH() {
   echo "INFO: Checking out MAIN branch ..."
   FETCH_CMD="git fetch --quiet origin main"
   CHECKOUT_CMD="git checkout --quiet -B main origin/main"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${FETCH_CMD}"
      echo "DEBUG: ${CHECKOUT_CMD}"
   fi

   eval ${FETCH_CMD}
   
   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT fetch successful ..."
      echo ""
   else
      echo "ERROR: GIT fetch failed failed!"
      ERROR_EXIT
   fi
   
   eval ${CHECKOUT_CMD}
   
   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT checkout MAIN successful ..."
      echo ""
   else
      echo "ERROR: GIT checkout MAIN failed failed!"
      ERROR_EXIT
   fi
} #END CHECKOUT_BRANCH

UPDATE_YAML() {
   echo "INFO: Updating Helm chart ${ENV,,}-values.yaml ..."
   YQ_UPDATE_CMD="yq -i '.image.tag = strenv(GIT_TAG)' ${APP_NAME}/${ENV,,}-values.yaml"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${YQ_UPDATE_CMD}"
   fi

   eval ${YQ_UPDATE_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: Helm chart updated successfully ..."
      echo ""
   else
      echo "ERROR: Helm chart update failed!"
      ERROR_EXIT
   fi      
} # END UPDATE_YAML

GIT_COMMIT() {
   echo "INFO: Committing Helm chart update ..."
   VALUES_FILE="${APP_NAME}/${ENV,,}-values.yaml"
   GIT_ADD_CMD="git add ${VALUES_FILE}"
   GIT_COMMIT_CMD="git commit -m \"AUTOMATED DEPLOYMENT: Updating ${APP_NAME} image tag to ${GIT_TAG}\""

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${GIT_ADD_CMD}"
      echo "DEBUG: ${GIT_COMMIT_CMD}"
   fi

   eval ${GIT_ADD_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT add ${ENV,,}-values.yaml to repo successful ..."
      echo ""
   else
      echo "ERROR: GIT add ${ENV,,}-values.yaml to repo failed!"
      ERROR_EXIT
   fi

   if git diff --cached --quiet; then
      echo "INFO: Nothing to commit. ${VALUES_FILE} already has image tag ${GIT_TAG}."
      git status
      echo ""
      return 0
   fi

   eval ${GIT_COMMIT_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT commit ${ENV,,}-values.yaml to repo successful ..."
      echo ""
   else
      echo "ERROR: GIT commit ${ENV,,}-values.yaml to repo failed!"
      ERROR_EXIT
   fi          
   
} #END GIT_COMMIT

GIT_UPDATE_REPO() {
   echo "INFO: Pushing Helm chart ${GIT_TAG} update to repo ..."
   GIT_PUSH_TAG_CMD="git push origin main"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${GIT_PUSH_TAG_CMD}"
   fi
   
   eval ${GIT_PUSH_TAG_CMD}
      
   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: GIT Push Successful ..."
      echo ""
   else
      echo "ERROR: GIT Push Failed!"
      ERROR_EXIT
   fi

   } #END GIT_UPDATE_REPO

##################################
# MAIN ROUTINE
##################################
echo "#########################"
echo "        INPUTS"
echo "#########################"
echo "ENV: ${ENV}"
echo "APP_NAME: ${APP_NAME}"
echo "GIT_TAG: ${GIT_TAG}"
echo ""

if [[ -z "${GIT_TAG}" || "${ENV}" != "DEV" && "${ENV}" != "TEST" && "${ENV}" != "STAGE-INT" && "${ENV}" != "STAGE-EXT" && "${ENV}" != "PROD-INT" && "${ENV}" != "PROD-EXT" ]]; then
	USAGE
	ERROR_EXIT
else
   SETUP_USER
   CHECKOUT_BRANCH
   UPDATE_YAML
   GIT_COMMIT
   GIT_UPDATE_REPO
fi