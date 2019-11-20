#!/bin/bash
#
# Copyright (c) 2018-2019 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SETUP LOGGING
MYLOGFILE="$(basename $0|cut -d. -f1)_$(date +'%FT%H-%M-%S%z').log"
exec 1> >(tee -a "$MYLOGFILE") 2>&1
echo "Logging to $MYLOGFILE"

echo "Updating resolv.conf"
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo "Updating Time Zone"
timedatectl set-timezone UTC

echo "Setup Docker and load any staged images"
apt -y install --no-install-recommends docker.io

echo "Now we are starting to deploy airship"
sleep 3
set -x
rm -rf /root/deploy
mkdir -p /root/deploy && cd "$_"
git clone https://opendev.org/airship/treasuremap/
cd /root/deploy/treasuremap/tools/deployment/aiab/
git checkout tags/v1.3

# use kvm instead of qemu for virtualization
sed -i -e 's/virt_type:.*$/virt_type: kvm/g' /root/deploy/treasuremap/site/aiab/software/charts/osh/openstack-compute-kit/nova.yaml

./airship-in-a-bottle.sh  -y -y
#./test_create_heat_stack.sh

echo "Make iptables rules persistent"
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
apt-get -y install iptables-persistent

# add script to run openstack cli commands from container
cp /opt/run_openstack_cli.sh /usr/local/bin/openstack
set +x

pods=$(kubectl get pods -n openstack |wc -l)
if [ $pods -gt 75 ]; then
        set -x
        CPU=$[$(grep -c ^processor /proc/cpuinfo)*3/4]
        MEM=$[$(grep MemTotal /proc/meminfo | awk '{print $2;}')/1024*3/4]

        openstack quota set --cores $CPU --ram $MEM admin
        openstack quota show admin
        openstack subnet set --dhcp --dns-nameserver 8.8.8.8 public
        openstack subnet show public
        set +x
        echo "Environment Deployed: Please login to environment to validate further"
        exit 0
else
        echo "ERROR: Openstack Environment deployment Failed"
        exit 1;
fi

