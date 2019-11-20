#!/bin/bash
# Copyright 2018-2019 AT&T Intellectual Property.  All other rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Define variables
COMMAND='openstack'
OPENSTACK_CLI_IMAGE="${OPENSTACK_CLI_IMAGE:-docker.io/openstackhelm/heat:ocata}"
NAMESPACE="${NAMESPACE:-openstack}"

# Define Base Docker Command
base_docker_command=$(cat << EndOfCommand
sudo docker run -it --rm --net=host
-e http_proxy=${HTTP_PROXY}
-e https_proxy=${HTTPS_PROXY}
-e OS_AUTH_URL=${OS_AUTH_URL:-http://keystone.${NAMESPACE}.svc.cluster.local:80/v3}
-e OS_USERNAME=${OS_USERNAME:-admin}
-e OS_USER_DOMAIN_NAME=${OS_USER_DOMAIN_NAME:-default}
-e OS_PASSWORD=${OS_PASSWORD:-password123}
-e OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME:-default}
-e OS_PROJECT_NAME=${OS_PROJECT_NAME:-admin}
-e OS_REGION_NAME=${OS_REGION_NAME:-RegionOne}
-e OS_IDENTITY_API_VERSION=${OS_IDENTITY_API_VERSION:-3}
-w /host/$(pwd)
-v /:/host:rshared
EndOfCommand
)

# Warn about absolute references
if echo "$@" | grep ' /' ; then
    echo "WARNING:  Any absolute file references should start with /host/<path>/<filename> because openstack cli is running in a container" 1>&2
    echo "WARNING:  For example: 'openstack image create --file /host/tmp/ubuntu.img ubuntu' would create a new image with the file /tmp/ubuntu.img" 1>&2
fi

# Execute OpenStack CLI
${base_docker_command} ${OPENSTACK_CLI_IMAGE} ${COMMAND} $@

