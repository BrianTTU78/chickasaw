#!/usr/bin/bash
############################################
# Description: This script triggers argocd
#              to sync based on commits
#
# Written By: Brian Dickey
# Date: 5/15/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="trigger_argocd_sync.sh"
ARGOCD_OPTS="--grpc-web --insecure"

ENV="${1^^}"
SERVER="${2}"
APP_NAME="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ENV] [SERVER] [APP NAME]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} dev dev-ecs-argocd.int.chickasaw.net cn-ecs-web-app"
   echo ""
   echo "NOTE: Variables are typically set in ADO Libraries ..."
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

ARGOCD_WAIT() {
   ARGOCD_WAIT_CMD="argocd app wait ${APP_NAME} --server ${ARGOCD_URL} --auth-token \"${ARGOCD_AUTH_TOKEN}\" ${ARGOCD_OPTS} --health --sync --timeout 300"

   if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${ARGOCD_WAIT}"
   fi

   eval ${ARGOCD_WAIT_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: ArgoCD is Synced and Healthy ..."
      echo ""
   else
      echo "ERROR: ArgoCD state needs investigation!"
      ERROR_EXIT
   fi

} #END ARGOCD_SYNC

ARGOCD_SYNC() {
   ARGOCD_SYNC_CMD="argocd app sync ${APP_NAME} --server ${ARGOCD_URL} --auth-token \"${ARGOCD_AUTH_TOKEN}\" ${ARGOCD_OPTS}"

    if [[ ${DEBUG} -ne 0 ]]; then
      echo "DEBUG: ${ARGOCD_SYNC_CMD}"
   fi

   eval ${ARGOCD_SYNC_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: ArgoCD synced successfully ..."
      echo ""
   else
      echo "ERROR: ArgoCD sync failed!"
      ERROR_EXIT
   fi

} #END ARGOCD_SYNC

ARGOCD_GET() {
   ARGOCD_GET_CMD="argocd app get ${APP_NAME} --server ${ARGOCD_URL} --auth-token \"${ARGOCD_AUTH_TOKEN}\" ${ARGOCD_OPTS}"

   eval ${GIT_EMAIL_CMD}

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: ArgoCD get successfully ..."
      echo ""
   else
      echo "ERROR: ArgoCD get failed!"
      ERROR_EXIT
   fi

} #END ARGOCD_GET

CHECK_TOKEN() {
   if [ -z "$ARGOCD_AUTH_TOKEN" ]; then
      echo "ERROR: ARGOCD_AUTH_TOKEN is empty"
      ERROR_EXIT
   else
      echo "INFO: Token exists. Length: ${#ARGOCD_AUTH_TOKEN}"
   fi
} #END CHECK_TOKEN


##################################
# MAIN ROUTINE
##################################
echo "#########################"
echo "        INPUTS"
echo "#########################"
echo "ENV: ${ENV}"
echo "SERVER: ${ARGOCD_URL}"
echo "APP_NAME: ${APP_NAME}"
echo ""

if [[ -z "${GIT_TAG}" || "${ENV}" != "DEV" && "${ENV}" != "TEST" && "${ENV}" != "STAGE-INT" && "${ENV}" != "STAGE-EXT" && "${ENV}" != "PROD-INT" && "${ENV}" != "PROD-EXT" ]]; then
	USAGE
	ERROR_EXIT
else
   CHECK_TOKEN
   ARGOCD_GET
   ARGOCD_SYNC
   ARGOCD_WAIT
fi