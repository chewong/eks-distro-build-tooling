#!/usr/bin/env bash
# Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -o pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

NEWROOT=/ansible

source $SCRIPT_ROOT/common_vars.sh

function instal_ansible() {
    local -r deps="python3-pip"
    yum install -y $deps

    #################### IMAGE BUILDER ####################
    # Install image-builder build dependencies - pip, Ansible, Packer
    # Post upgrade, pip3 got renamed to pip and moved locations. It works completely with python3
    # Symlinking pip3 to pip, to have pip3 commands work successfully
    if [ "$IS_AL22" = "false" ]; then 
        pip3 install --no-cache-dir -U pip setuptools
        ln -sf $USR_LOCAL_BIN/pip $USR_BIN/pip3
    fi

    ANSIBLE_VERSION="$ANSIBLE_VERSION"
    pip3 install --user --no-cache-dir "ansible==$ANSIBLE_VERSION"

    PYWINRM_VERSION="$PYWINRM_VERSION"
    pip3 install --user --no-cache-dir "pywinrm==$PYWINRM_VERSION"
    
    rm -rf ${NEWROOT}/usr/*
    mv /root/.local/* ${NEWROOT}/usr

    rm -rf /root/.cache
}

[ ${SKIP_INSTALL:-false} != false ] || instal_ansible
