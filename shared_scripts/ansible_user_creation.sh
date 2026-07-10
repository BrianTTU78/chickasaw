#!/usr/bin/bash
##########################################
# Description: This runs the sets to setup
#              the ansible user to allow
#              tower to communicate
#
# Written By: Brian Dickey
# Date: 2/1/26
# Version: 1.0
##########################################
SCRIPT_NAME="ansible_user_creation.sh"
ANSIBLE_HOME="/home/ansible"

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

VERIFY_LOGIN_USER() {
  echo "INFO: Verifying logged in user ..."
  USERNAME=$(whoami)
  if [[ ${USERNAME} != "root" ]]; then
    echo "ERROR: Root access required and you are not root!"
    ERROR_EXIT
  fi
} #END VERIFY_LOGIN_USER

CREATE_USER() {
  echo "INFO: Creating User ..."
  CREATE_CMD="useradd -d ${ANSIBLE_HOME} -s /bin/bash ansible"
  eval ${CREATE_CMD}

  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to create user!"
    ERROR_EXIT
  else
    echo "INFO: User created successfully ..."
  fi
} #END CREATE_USER

CREATE_DIRECTORY() {
  echo "INFO: Creating Directory ..."
  CREATE_DIR_CMD="mkdir -p ${ANSIBLE_HOME}/.ssh"
  eval ${CREATE_DIR_CMD}

  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to create SSH directory!"
    ERROR_EXIT
  else
    echo "INFO: SSH directory created successfully ..."
  fi
} #END CREATE_DIRECTORY

CREATE_FILES() {
  echo "INFO: Creating Files ..."
  CREATE_FILE_CMD="touch ${ANSIBLE_HOME}/.ssh/authorized_keys"
  eval ${CREATE_FILE_CMD}

  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to create authorized_keys file!"
    ERROR_EXIT
  else
    echo "INFO: Authorized_keys created successfully ..."
  fi
} #END CREATE_FILES

SET_OWNERSHIP() {
  echo "INFO: Setting Ownership ..."
  SET_CHMOD_DIR_CMD="chmod 700 ${ANSIBLE_HOME}/.ssh"
  SET_CHOWN_SSH_CMD="chown -R ansible:ansible ${ANSIBLE_HOME}/"
  SET_CHMOD_FILE_CMD="chmod 600 ${ANSIBLE_HOME}/.ssh/*"
  
  eval ${SET_CHMOD_DIR_CMD}
  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to set .ssh permissions!"
    ERROR_EXIT
  else
    echo "INFO: SSH folder permissions set ..."
  fi

  eval ${SET_CHOWN_SSH_CMD}
  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to set folder ownership!"
    ERROR_EXIT
  else
    echo "INFO: Folder ownership set ..."
  fi

  eval ${SET_CHMOD_FILE_CMD}
  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to set file permissions!"
    ERROR_EXIT
  else
    echo "INFO: File permissions set ..."
  fi
} #END SET_OWNERSHIP

UPDATE_SUDOERS() {
  echo "ansible ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

  RC=$?
  if [[ "${RC}" != 0 ]]; then
    echo "ERROR: Unable to update sudoers file!"
    ERROR_EXIT
  else
    echo "INFO: Sudoers file set ..."
  fi

} #END UPDATE_SUDOERS
##################################
# MAIN FUNCTION
##################################

VERIFY_LOGIN_USER
CREATE_USER
CREATE_DIRECTORY
CREATE_FILES
SET_OWNERSHIP
UPDATE_SUDOERS
echo "INFO: You need to manually add the authorized key of the ansible user ..."
echo "INFO: HINT: It can be found in Secrets Server"
echo ""
echo "Script Complete ..."
echo ""
