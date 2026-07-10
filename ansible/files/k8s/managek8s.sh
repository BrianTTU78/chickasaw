#!/usr/bin/bash
##########################################
# Description: Start and Stop Rancher
#
# Written By: Brian Dickey
# Updated By: Wade Rutherford 
# Date: 4/1/26
# Version: 2.0
##########################################
SCRIPT_NAME="managek8s.sh"
LOG_DIR="/data01/rancher/logs"
LOGFILE="${LOG_DIR}/managek8s.log"
DRY_RUN=0

ACTION=${1,,}

USAGE() {
    echo "#######################"
    echo "USAGE:"
    echo "#######################"
    echo "./${SCRIPT_NAME} [ACTION]"
    echo ""
    echo "Examples:"
    echo "./${SCRIPT_NAME} stop"
    echo "./${SCRIPT_NAME} start"
    echo ""
} #END USAGE

ERROR_EXIT() {
    echo ""
    echo "Exiting ..."
    exit 1
} # END ERROR_EXIT

##################################
# DETERMINE TYPE
##################################

DETERMINE_SERVER_OR_AGENT() {
    DETECT_SERVER_CMD="systemctl cat rke2-server 2>/dev/null"
    DETECT_AGENT_CMD="systemctl cat rke2-agent 2>/dev/null"

    if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${DETECT_SERVER_CMD}"
      echo "DEBUG ${DETECT_AGENT_CMD}"
    fi

    RKE2_SERVER_OUTPUT=$(eval "${DETECT_SERVER_CMD}")
    RKE2_AGENT_OUTPUT=$(eval "${DETECT_AGENT_CMD}")

    if [[ "${RKE2_SERVER_OUTPUT}" != "" ]]; then
        SERVER_TYPE="SERVER"
    elif [[ "${RKE2_AGENT_OUTPUT}" != "" ]]; then
        SERVER_TYPE="AGENT"
    else
        echo "ERROR: Unable to determine server type (RKE2 Server/Agent)!" | tee -a "${LOGFILE}"
        ERROR_EXIT
    fi
} # END DETERMINE_SERVER_OR_AGENT

##################################
# STATUS CHECK
##################################

STATUS_CHECK() {
    if ! command -v kubectl &>/dev/null; then
        echo "ERROR: kubectl not available; skipping cluster safety check" | tee -a "${LOGFILE}"
        return 1
    fi

    if [[ ${SERVER_TYPE} == "SERVER" ]]; then
        CURRENT_STATE=$(systemctl is-active rke2-server)
    else
        CURRENT_STATE=$(systemctl is-active rke2-server)
    fi

    echo "INFO: Current State is: ${CURRENT_STATE} ..."
}

##################################
# PID KILL
##################################

PID_KILL() {
    TRY_COUNT=0
    MAX_COUNT=10
    TIMER=5
    echo "INFO: Attempting graceful kill of stale PIDs ..."

    if [[ "${SERVER_TYPE}" == "SERVER" ]]; then
        PIDS=$(pgrep -f 'rke2|kubelet|kube-apiserver|kube-controller|kube-scheduler|containerd|etcd' || true)
    elif [[ "${SERVER_TYPE}" == "AGENT" ]]; then
        PIDS=$(pgrep -f 'rke2|kubelet|containerd' || true)
    fi

    if [[ -n "${PIDS}" ]]; then
        echo "INFO: Attempting shutdown PIDs"

        for pid in ${PIDS}; do
            if ps -p "${pid}" >/dev/null 2>&1; then
                sudo kill "${pid}" || true
            fi
        done

        # Wait for processes to exit
        while true; do
            REMAINING_PIDS=""
            for pid in ${PIDS}; do
                if ps -p "${pid}" >/dev/null 2>&1; then
                    REMAINING_PIDS="${REMAINING_PIDS} ${pid}"
                fi
            done

            if [[ -z "${REMAINING_PIDS}" ]]; then
                echo "INFO: All processes stopped cleanly ..."
                break
            fi
 
            ((TRY_COUNT++))
            if (( TRY_COUNT >= MAX_COUNT )); then
                echo "WARNING: Processes still running after graceful shutdown: ${REMAINING_PIDS}"
                break
            fi

            echo "INFO: Waiting for processes to stop (${TRY_COUNT}/${MAX_COUNT}) ..."
            sleep "${TIMER}"
        done

        ### BEGIN FORCE KILL ###
        if [[ -n "${REMAINING_PIDS}" ]]; then
            echo "WARNING: Force killing remaining processes: ${REMAINING_PIDS}"
            for pid in ${REMAINING_PIDS}; do
                if ps -p "${pid}" >/dev/null 2>&1; then
                    sudo kill -9 "${pid}" || true
                fi
            done
        fi
    else
        echo "INFO: Kubernetes has shutdown ..."
    fi
}

##################################
# STOP
##################################

RKE2_STOP() {
    echo "INFO: Stopping rke2-${SERVER_TYPE,,} ..." | tee -a "${LOGFILE}"

    TRY_COUNT=0
    MAX_COUNT=10
    TIMER=15

    SVC="rke2-${SERVER_TYPE,,}"
    STOP_CMD="sudo systemctl stop ${SVC}"

    if [[ ${DEBUG} == 1 ]]; then
        echo "DEBUG: ${STOP_CMD}"
    fi

    eval "${STOP_CMD}"

    while true; do
        ((TRY_COUNT++))
        SHUTDOWN_OUTPUT=$(systemctl is-active "${SVC}" 2>/dev/null || true)
        echo "INFO: Status: ${SVC}: PIDs still active (${TRY_COUNT}/${MAX_COUNT})" | tee -a "${LOGFILE}"

        # CHECK FOR REMAINING PIDS
        if [[ "${SERVER_TYPE}" == "SERVER" ]]; then
            PIDS=$(pgrep -f 'rke2|kubelet|kube-apiserver|kube-controller|kube-scheduler|containerd|etcd' || true)
        elif [[ "${SERVER_TYPE}" == "AGENT" ]]; then
            PIDS=$(pgrep -f 'rke2|kubelet|containerd' || true)
        fi

        # FULLY SHUTDOWN
        if [[ "${SHUTDOWN_OUTPUT}" != "active" && -z "${PIDS}" ]]; then
            echo "INFO: Kubernetes has shutdown ..." | tee -a "${LOGFILE}"
            break
        fi

        # STALE PIDS DETECTED
        if [[ "${SHUTDOWN_OUTPUT}" != "active" && -n "${PIDS}" ]]; then

            if (( TRY_COUNT >= MAX_COUNT )); then
                echo "WARNING: Stale Kubernetes PIDs still exist after ${TRY_COUNT} checks; killing now ..." | tee -a "${LOGFILE}"
                PID_KILL
                break
            fi
        fi

        # TIMEOUT
        if (( TRY_COUNT >= MAX_COUNT )); then
            echo "WARNING: TIMEOUT: Kubernetes is still active after ${MAX_COUNT} checks!" | tee -a "${LOGFILE}"
            PID_KILL
            break
        fi
        sleep "${TIMER}"
    done
}

##################################
# START
##################################

RKE2_START() {
    echo "INFO: Starting rke2-${SERVER_TYPE,,} ..." | tee -a "${LOGFILE}"
    TRY_COUNT=0
    MAX_COUNT=15
    TIMER=15
    SVC="rke2-${SERVER_TYPE,,}"
    START_CMD="sudo systemctl start ${SVC}"

    if [[ ${DEBUG} == 1 ]]; then
      echo "DEBUG: ${START_CMD}"
    fi

    echo "INFO: ${SVC} Startup Status:" | tee -a "${LOGFILE}"
    eval "${START_CMD}"

    if [[ "${SERVER_TYPE}" == "SERVER" ]]; then
    while true; do
        ((TRY_COUNT++))
        READY_OUTPUT=$(kubectl get --raw='/readyz?verbose' 2>&1)
        echo "${READY_OUTPUT}" | tee -a "${LOGFILE}"

        if echo "${READY_OUTPUT}" | grep -q "readyz check passed"; then
            echo "INFO: Kubernetes API is healthy ..." | tee -a "${LOGFILE}"
            break
        fi

        if (( TRY_COUNT >= MAX_COUNT )); then
            echo "ERROR: Kubernetes API failed readiness check after ${MAX_COUNT} attempts" | tee -a "${LOGFILE}"
            ERROR_EXIT
        fi

        echo "INFO: Waiting (${TRY_COUNT}/${MAX_COUNT})" | tee -a "${LOGFILE}"
        sleep "${TIMER}"
    done
    fi

    if [[ "${SERVER_TYPE}" == "AGENT" ]]; then
    while true; do
        ((TRY_COUNT++))
        if systemctl is-active --quiet rke2-agent; then
            echo "INFO: rke2-agent service is active ..." | tee -a "${LOGFILE}"
            break
        fi

        if (( TRY_COUNT >= MAX_COUNT )); then
            echo "ERROR: RKE2-Agent failed startup after ${MAX_COUNT} attempts" | tee -a "${LOGFILE}"
            ERROR_EXIT
        fi

        echo "INFO: Waiting (${TRY_COUNT}/${MAX_COUNT}) ..." | tee -a "${LOGFILE}"
        sleep "${TIMER}"
    done
    fi

    echo "INFO: Startup complete ..." | tee -a "${LOGFILE}"
}


##################################
# MAIN
##################################
if [[ -z "${ACTION}" ]]; then
    USAGE
    ERROR_EXIT
fi

if [[ -z "${DEBUG}" ]]; then
    DEBUG="0"
fi

DETERMINE_SERVER_OR_AGENT
echo "##################################"
echo "             INPUTS"
echo "##################################"
echo "SCRIPT: ${SCRIPT_NAME}"
echo "SERVER TYPE: ${SERVER_TYPE}"
echo "ACTION: ${ACTION}"
echo "DEBUG: ${DEBUG}"
echo ""

STATUS_CHECK

if [[ ${ACTION} == "stop" ]]; then    
    RKE2_STOP
elif [[ ${ACTION} == "start" ]]; then
    RKE2_START
else
    echo "ERROR: Incorrect Usage!"
    USAGE
    ERROR_EXIT
fi

echo ""
echo "INFO: Script Complete ..."
echo ""