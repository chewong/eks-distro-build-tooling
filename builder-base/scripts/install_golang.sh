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

set -x
set -e
set -o pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

VERSION="$1"

RELEASE_NUMBER="$(echo $VERSION | cut -d'-' -f 2)"

GOLANG_MAJOR_VERSION=${VERSION%.*}

NEWROOT=/golang-${GOLANG_MAJOR_VERSION}

source $SCRIPT_ROOT/common_vars.sh

mkdir -p /go/src /go/bin /go/pkg

function build::go::symlink() {
    local -r version=$1

    # Removing the last number as we only care about the major version of golang
    local -r majorversion=${version%.*}
    mkdir -p ${GOPATH}/go${majorversion}/bin
    for binary in go gofmt; do
        ln -s /root/sdk/go${version}/bin/${binary} ${GOPATH}/go${majorversion}/bin/${binary}
    done
    ln -s ${GOPATH}/bin/go${version} ${GOPATH}/bin/go${majorversion}
}

function build::go::install(){
    # Set up specific go version by using go get, additional versions apart from default can be installed by calling
    # the function again with the specific parameter.
    local version=${1%-*}

    if [ $TARGETARCH == 'amd64' ]; then 
        local arch='x86_64'
    else 
        local arch='aarch64'
    fi

    for artifact in golang golang-bin; do
        curl -sSL --retry 5 https://distro.eks.amazonaws.com/golang-go$version/releases/$RELEASE_NUMBER/RPMS/$arch/$artifact-$version-$RELEASE_NUMBER.amzn2.eks.$arch.rpm -o /tmp/$artifact-$version-$RELEASE_NUMBER.amzn2.eks.$arch.rpm
    done

    if [ $TARGETARCH == 'amd64' ]; then 
        curl -sSL --retry 5 https://distro.eks.amazonaws.com/golang-go$version/releases/$RELEASE_NUMBER/RPMS/$arch/golang-race-$version-$RELEASE_NUMBER.amzn2.eks.$arch.rpm -o /tmp/golang-race-$version-$RELEASE_NUMBER.amzn2.eks.$arch.rpm
    fi

    for artifact in golang-docs golang-misc golang-tests golang-src; do
        curl -sSL --retry 5 https://distro.eks.amazonaws.com/golang-go$version/releases/$RELEASE_NUMBER/RPMS/noarch/$artifact-$version-$RELEASE_NUMBER.amzn2.eks.noarch.rpm -o /tmp/$artifact-$version-$RELEASE_NUMBER.amzn2.eks.noarch.rpm
    done

    build::go::extract $version
    build::go::symlink $version
}

function build::go::extract() {
    local version=$1
    mkdir -p /tmp/go-extracted
    for rpm in /tmp/golang-*.rpm; do $(cd /tmp/go-extracted && rpm2cpio $rpm | cpio -idm && rm -f $rpm); done

    local -r golang_version=$(/tmp/go-extracted/usr/lib/golang/bin/go version | grep -o "go[0-9].* " | xargs)

    mkdir -p /root/sdk/$golang_version
    mv /tmp/go-extracted/usr/lib/golang/* /root/sdk/$golang_version

    for license_dir in "/usr/share/licenses/golang" "/usr/share/doc/golang-$VERSION"; do
        if [ -d /tmp/go-extracted/$license_dir ]; then
            mv /tmp/go-extracted/$license_dir/* /root/sdk/$golang_version
        fi
    done

    version=$(echo "$golang_version" | grep -o "[0-9].*")
    ln -s /root/sdk/go${version}/bin/go ${GOPATH}/bin/$golang_version

    rm -rf /tmp/go-extracted /tmp/golang-*.rpm
}


build::go::install "${VERSION}"

# symlink default golang install to newroot bin
for binary in go gofmt; do
    ln -s ${GOPATH}/go${GOLANG_MAJOR_VERSION}/bin/${binary} ${USR_BIN}/${binary}
done

mkdir -p ${NEWROOT}/root
mv /root/sdk ${NEWROOT}/root
mv ${GOPATH} ${NEWROOT}/${GOPATH}
