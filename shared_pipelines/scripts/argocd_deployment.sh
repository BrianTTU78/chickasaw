#!/usr/bin/bash
############################################
# Description: Deploys Applications with Helm
#
# Written By: Brian Dickey
# Date: 6/12/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="argocd_deployment.sh"

ENV="${1}"
APP_NAME="${2}"
LOCATION="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ENV] [APP_NAME]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} DEV cn-ecs-web-app"
   echo "${SCRIPT_NAME} DEV argocd"
   echo ""
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

VERIFY_HELM() {
   echo "INFO: Verifying Helm ..."
   VERIFY_HELM_CMD="which helm"
   
   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${VERIFY_HELM_CMD}"
   fi
   
   eval ${VERIFY_HELM_CMD}

   RC=$?
   if [[ "${RC}" != 0 ]]; then
      echo "ERROR: Helm not found!"
      ERROR_EXIT
   else
      echo "INFO: Helm Installed, proceeding ..."
   fi
} #END VERIFY_HELM

VERIFY_KUBECTL() {
   echo "INFO: Verifying Kubectl ..."
   VERIFY_KUBECTL_CMD="which kubectl"
   
   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${VERIFY_KUBECTL_CMD}"
   fi
   
   eval ${VERIFY_KUBECTL_CMD}

   RC=$?
   if [[ "${RC}" != 0 ]]; then
      echo "ERROR: Kubectl not found!"
      ERROR_EXIT
   else
      echo "INFO: Kubectl Installed, proceeding ..."
   fi
} #END VERIFY_KUBECTL

GET_KUBECONFIG() {
   echo "INFO: Setting Kubeconfig for environment ..."
   if [[ -z "$KUBECONFIG" ]]; then
      echo "ERROR: Kubeconfig NOT set!"
   else
      echo "INFO: Kubeconfig set, proceeding ..."
   fi

   chmod 600 ${KUBECONFIG}

} #END GET_KUBECONFIG

CHANGE_DIRECTORIES() {
   echo "INFO: Changing directories ..."
   if [[ "${HELM_FLAG}" == "true" ]]; then
      CHDIR_CMD="cd helm_charts/${APP_NAME}"
   else
      CHDIR_CMD="cd applications/${ENV}"
   fi

    if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${CHDIR_CMD}"
   fi

   eval ${CHDIR_CMD}

   RC=$?
   if [[ "${RC}" != 0 ]]; then
      echo "ERROR: Change directories failed!"
      ERROR_EXIT
   else
      echo "INFO: Changing directories successful ..."
   fi

   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG:"
      echo "-------------------------"
      ls -l
      echo "-------------------------"
      echo ""
   fi

} #END CHANGE_DIRECTORIES


HELM_DEPENDENCY_UPDATE() {
   echo "INFO: Updating Helm Dependencies ..."
   HELM_DEP_CMD="helm dependency update"

   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${HELM_DEP_CMD}"
   fi
   
   eval ${HELM_DEP_CMD}

   RC=$?
   if [[ "${RC}" != 0 ]]; then
      echo "ERROR: Helm dependency update failed!"
      ERROR_EXIT
   else
      echo "INFO: Helm dependency update complete ..."
   fi
} #END HELM_DEPENDENCY_UPDATE

DEPLOY() {
   echo "INFO: Deploying ${APP_NAME} ..."
   if [[ "${APP_NAME}" == "argocd" ]]; then
      DEPLOY_CMD="helm upgrade --install ${APP_NAME} . -n ${APP_NAME} --create-namespace -f values.yaml -f ${ENV}-values.yaml --set-string \"argo-cd.configs.secret.extra.oidc\\.clientSecret=$ARGO_CD_SSO_SECRET\""
   elif [[ "${APP_NAME}" == "rancher" ]]; then
      DEPLOY_CMD="helm upgrade --install ${APP_NAME} . -n cattle-system --create-namespace -f values.yaml -f ${ENV}-values.yaml"
   else
      DEPLOY_CMD="kubectl apply -f ${APP_NAME}.yaml"
   fi

   if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${DEPLOY_CMD}"
   fi

   eval ${DEPLOY_CMD}

   RC=$?
   if [[ "${RC}" != 0 ]]; then
      echo "ERROR: Deployment for ${APP_NAME} failed!"
      ERROR_EXIT
   else
      echo "INFO: ${APP_NAME} deployment successful ..."
   fi
} # END HELM_DEPLOY

###################################
# MAIN
###################################

if [[ "${APP_NAME}" == "" ]]; then
   USAGE
fi

VERIFY_HELM
VERIFY_KUBECTL
GET_KUBECONFIG
if [[ "${APP_NAME}" == "argocd" || "${APP_NAME}" == "rancher" ]]; then
   HELM_FLAG="true"
fi
CHANGE_DIRECTORIES
if [[ "${HELM_FLAG}" == "true" ]]; then
   HELM_DEPENDENCY_UPDATE
fi

DEPLOY

echo "INFO: Script Complete ..."
echo ""

