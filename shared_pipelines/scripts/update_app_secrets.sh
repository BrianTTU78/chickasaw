#!/usr/bin/bash
############################################
# Description: This script updates secrets
#              in kubernetes via the pipeline
#
# Written By: Brian Dickey
# Date: 7/2/2026
# Version: 1.0
# Modified: N/A
############################################
SCRIPT_NAME="update_app_secrets.sh"
ENV="${1^^}"
APP_NAME="${2,,}"

FORMIO_ARRAY=()

USAGE() {
   echo "#######################"
   echo "USAGE:"
   echo "#######################"
   echo "${SCRIPT_NAME} [ENV] [APP NAME]"
   echo ""
   echo "Examples:"
   echo "------------------"
   echo "${SCRIPT_NAME} dev cn-ecs-web-app"
   echo ""
   echo "NOTE: APP_VERSION variable is typically set in ADO Library variables ..."
   } #END USAGE

ERROR_EXIT() {
   echo ""
   echo "Exiting ..."
   echo ""
   exit 1
   } #END ERROR_EXIT

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

CREATE_NAMESPACE() {
    echo "Verifying Kubernetes Namespace (${APP_NAME}) ..."
    GET_NAMESPACE_CMD="kubectl get namespace \"${APP_NAME}\" >/dev/null 2>&1"
    CREATE_NAMESPACE_CMD="kubectl create namespace \"${APP_NAME}\" --dry-run=client -o yaml | kubectl apply -f -"

    if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: GET: ${GET_NAMESPACE_CMD}"
      echo "DEBUG: CREATE: ${CREATE_NAMESPACE_CMD}"
    fi
    
    eval ${GET_NAMESPACE_CMD}

    RC=$?
    if [ $RC -eq 0 ]; then
        echo "INFO: Namespace exists ..."
    else
        echo "WARNING: Namespace ${APP_NAME} does NOT exist"
        echo "INFO: Creating Namespace: ${APP_NAME}"
        eval ${CREATE_NAMESPACE_CMD}

        RC=$?
        if [ $RC -eq 0 ]; then
            echo "INFO: Namespace created successfully ..."
        else
            echo "ERROR: Unable to create namespace!"
        fi
    fi 
} #END CREATE_NAMESPACE

UPDATE_SECRETS() {
    
    ####################################
    # FORM.IO
    ####################################
    if [[ "${APP_NAME}" == "formio-app" ]]; then
        echo "INFO: Setting ${APP_NAME} Kubernetes secrets ..."
        kubectl -n "${APP_NAME}" create secret generic "${APP_NAME}-secrets" \
            --from-literal=ADMIN_PASS="${ADMIN_PASS}" \
            --from-literal=DB_SECRET="${DB_SECRET}" \
            --from-literal=FORMIO_S3_SECRET="${FORMIO_S3_SECRET}" \
            --from-literal=JWT_SECRET="${JWT_SECRET}" \
            --from-literal=MONGO="${MONGO}" \
            --from-literal=PORTAL_SECRET="${PORTAL_SECRET}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    ####################################
    # DATA PLATFORM
    ####################################
    if [[ "${APP_NAME}" == "cn-ecs-data-platform" ]]; then 
        echo "INFO: Setting ${APP_NAME} Kubernetes secrets ..."   
        kubectl -n "${APP_NAME}" create secret generic "${APP_NAME}-secrets" \
            --from-literal=ECS_MONGODB_CONNECTION="${ECS_MONGODB_CONNECTION}" \
            --from-literal=OpenIddict__ClientSecret="${OpenIddict__ClientSecret}" \
            --from-literal=EntraExternalId__ClientSecret="${EntraExternalId__ClientSecret}" \
            --from-literal=EntraInternalId__ClientSecret="${EntraInternalId__ClientSecret}" \
            --from-literal=Cniq__Password="${Cniq__Password}" \
            --from-literal=RabbitMq__Password="${RabbitMq__Password}" \
            --from-literal=Notification__Email__ApiKey="${Notification__Email__ApiKey}" \
            --from-literal=Notification__Sms__AuthToken="${Notification__Sms__AuthToken}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    ####################################
    # IDENTITY-APP
    ####################################   
    if [[ "${APP_NAME}" == "cn-ecs-identity-app" ]]; then
        echo "INFO: Setting ${APP_NAME} Kubernetes secrets ..."
        kubectl -n "${APP_NAME}" create secret generic "${APP_NAME}-secrets" \
            --from-literal=SendGrid_ApiKey="${SendGrid_ApiKey}" \
            --from-literal=Twilio_AccountSid="${Twilio_AccountSid}" \
            --from-literal=Twilio_VerifyServiceSid="${Twilio_VerifyServiceSid}" \
            --from-literal=Twilio_AuthToken="${Twilio_AuthToken}" \
            --from-literal=InitialAdmin_Password="${Admin_Password}" \
            --from-literal=Database_Password="${Database_Password}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    ####################################
    # CHOKWAA-API
    ####################################   
    if [[ "${APP_NAME}" == "cn-ecs-chokwaa-api" ]]; then
        echo "INFO: Setting ${APP_NAME} Kubernetes secrets ..." 
        kubectl -n "${APP_NAME}" create secret generic "${APP_NAME}-secrets" \
            --from-literal=AddressServiceSettings__SubscriptionKey="${AddressServiceSettings__SubscriptionKey}" \
            --from-literal=AzureAd__ClientSecret="${AzureAd__ClientSecret}" \
            --from-literal=Cniq__Password="${Cniq__Password}" \
            --from-literal=dataProtectionConnectionString="${dataProtectionConnectionString}" \
            --from-literal=DraftsS3Settings__SecretKey="${DraftsS3Settings__SecretKey}" \
            --from-literal=FormioOptions__JwtSecret="${FormioOptions__JwtSecret}" \
            --from-literal=FormsSettings__ApiKey="${FormsSettings__ApiKey}" \
            --from-literal=postmanApiKey="${postmanApiKey}" \
            --from-literal=postmanCollectionUid="${postmanCollectionUid}" \
            --from-literal=SendGridSettings__ApiKey="${SendGridSettings__ApiKey}" \
            --from-literal=sitePassword="${sitePassword}" \
            --from-literal=UploadsS3Settings__SecretKey="${UploadsS3Settings__SecretKey}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    ####################################
    # CHOKWAA-APP (WEBSITE)
    ####################################
    if [[ "${APP_NAME}" == "cn-ecs-chokwaa-app" ]]; then
        echo "INFO: Setting ${APP_NAME} Kubernetes secrets ..."
        kubectl -n "${APP_NAME}" create secret generic "${APP_NAME}-secrets" \
            --from-literal=Cniq__Username="${cniqUsername}" \
            --from-literal=Cniq__Password="${cniqPassword}" \
            --from-literal=DraftsS3Settings__AccessKey="${draftsS3AccessKey}" \
            --from-literal=DraftsS3Settings__SecretKey="${draftsS3SecretKey}" \
            --from-literal=UploadsS3Settings__AccessKey="${uploadsS3AccessKey}" \
            --from-literal=UploadsS3Settings__SecretKey="${uploadsS3SecretKey}" \
            --from-literal=AuthSettings__SitePassword="${sitePassword}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi

   RC=$?
   if [ $RC -eq 0 ]; then
      echo "INFO: Secrets set successful ..."
   else
      echo "ERROR: Unable to set secrets!"
      ERROR_EXIT
   fi
} #END UPDATE_SECRETS

##################################
# MAIN ROUTINE
##################################
echo "#########################"
echo "        INPUTS"
echo "#########################"
echo "ENV: ${ENV}"
echo "APP_NAME: ${APP_NAME}"
echo ""

case "${ENV}" in
    DEV|TEST|STAGE-INT|STAGE-EXT|PROD-INT|PROD-EXT)
        VERIFY_KUBECTL
        CREATE_NAMESPACE
        UPDATE_SECRETS
        ;;
    *)
        USAGE
        ERROR_EXIT
        ;;
esac

echo "INFO: Script Complete ..."