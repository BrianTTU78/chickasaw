#!/usr/bin/bash
##########################################
# Description: Start and Stop Rancher
#
# Written By: Brian Dickey
# Date: 4/1/26
# Version: 1.0
##########################################
SCRIPT_NAME="managek8s.sh"
ACTION=${1,,}

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
    echo ""
} #END USAGE

RKE2_START() {
  echo "INFO: Not Written yet!"
  ERROR_EXIT
} # END RKE2_START

RKE2_STOP() {
    echo "INFO: Stopping RKE2 services..."

     for svc in rke2-server rke2-agent; do
        if systemctl list-units --full -all | grep -q "$svc"; then
            echo "Stopping $svc ..."
            sudo systemctl stop "$svc" || true
            sudo systemctl disable "$svc" || true

            echo "INFO: Waiting for $svc to stop cleanly..."
            for i in {1..15}; do
                if ! systemctl is-active --quiet "$svc"; then
                    echo "INFO: $svc stopped ..."
                    break
                fi

                echo "INFO: $svc still stopping... (${i}/15)"
                sleep 2
            done

            if systemctl is-active --quiet "$svc"; then
                echo "WARN: $svc did not stop cleanly after waiting."
            fi
        fi
    done

    echo "INFO: Checking for left-over processes..."
    PIDS=$(ps aux | grep -E 'rke2|kube|containerd' | grep -v grep | awk '{print $2}')

    if [ -n "$PIDS" ]; then
        echo "Killing remaining processes: $PIDS"
        sudo kill -9 $PIDS || true
    else
        echo "INFO: No leftover processes found ..."
    fi

    echo "INFO: Checking for open ports ..."
    if sudo ss -tulnp | grep -q ':6443'; then
        echo "Port 6443 still in use"
    else
        echo "INFO: Kubernetes API port is closed ..."
    fi

    echo "Final service status:"
    for svc in rke2-server rke2-agent; do
        if systemctl list-units --full -all | grep -q "$svc"; then
            systemctl is-active $svc || true
        fi
    done

    echo "INFO: RKE2 shutdown complete ..."
    echo ""
} # END RKE2_STOP

##################################
# MAIN FUNCTION
##################################

if [[ ${ACTION} == "" ]]; then
  USAGE
elif [[ ${ACTION} == "start" ]]; then
    RKE2_START
elif [[ ${ACTION} == "stop" ]]; then
    RKE2_STOP
fi