#!/usr/bin/bash
############################################
# Description: This script copies the docker
#              tarball to the K8S environment
#
# Written By: Brian Dickey
# Date: 5/15/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="copy_artifacts.sh"
RKE2_HOME="/data01/rancher/rke2"
IMAGE_LOCATION="/data01/docker/images"

ENV="${1^^}"
APP_NAME="${2}"
GIT_TAG="${3}"

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ENV] [APP NAME] [GIT_TAG]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} dev cn-ecs-web-app 1.0.1"
   echo ""
   echo "NOTE: Variables are typically set in ADO Libraries ..."
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

CHECK_SERVERS() {
    echo "INFO: Check if ADO Variable is set ..."    
    if [[ -z ${KUBERNETES_CLUSTER} ]]; then
        echo "ERROR: KUBERNETES_CLUSTER variable is NOT set!"
    else
        echo "INFO: KUBERNETES_CLUSTER variable is set, proceeding ..."
        CLUSTER_ARRAY=(${KUBERNETES_CLUSTER})
    fi
} #END CHECK SERVERS

COPY_ARTIFACTS() {
    echo "INFO: Copy tagged Docker image to Kubernetes cluster ..."
    for SERVER in "${CLUSTER_ARRAY[@]}"; do
        echo "INFO: Copying image to ${SERVER} ..."   
        COPY_CMD="scp -i /home/agent/.ssh/ado_prod_master_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o LogLevel=ERROR ${APP_NAME}-${GIT_TAG}.tar cnadmin@${SERVER}:/data01/docker/images/"
        IMPORT_CMD="ssh -i /home/agent/.ssh/ado_prod_master_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o LogLevel=ERROR cnadmin@${SERVER} \"sudo ${RKE2_HOME}/bin/ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images import ${IMAGE_LOCATION}/${APP_NAME}-${GIT_TAG}.tar\""
        
        if [[ ${DEBUG} -ne 0 ]]; then
            echo "DEBUG: ${COPY_CMD}"
            echo "DEBUG: ${IMPORT_CMD}"
        fi

        eval ${COPY_CMD}

        RC=$?
        if [ $RC -eq 0 ]; then
            echo "INFO: Artifact replication successfully ..."
            echo ""
        else
            echo "ERROR: Artifact replication failed on ${SERVER}!"
            ERROR_EXIT
        fi

        echo "INFO: Importing image artifact on ${SERVER} ..."

        eval ${IMPORT_CMD}

        RC=$?
        if [ $RC -eq 0 ]; then
            echo "INFO: Artifact ${GIT_TAG} import successful ..."
            echo ""
        else
            echo "ERROR: Artifact ${GIT_TAG} import failed on ${SERVER}!"
            ERROR_EXIT
        fi
    done  
} #END COPY_ARTIFACTS

##################################
# MAIN ROUTINE
##################################

echo "#########################"
echo "        INPUTS"
echo "#########################"
echo "ENV: ${ENV}"
echo "SERVERS: ${KUBERNETES_CLUSTER}"
echo "APP_NAME: ${APP_NAME}"
echo "GIT_TAG: ${GIT_TAG}"
echo ""
if [[ -z "${GIT_TAG}" || "${ENV}" != "DEV" && "${ENV}" != "TEST" && "${ENV}" != "STAGE-INT"  && "${ENV}" != "STAGE-EXT" && "${ENV}" != "PROD-INT"  && "${ENV}" != "PROD-EXT" ]]; then
	USAGE
	ERROR_EXIT
else
    CHECK_SERVERS
    COPY_ARTIFACTS
fi
echo "INFO: Script Complete ..."