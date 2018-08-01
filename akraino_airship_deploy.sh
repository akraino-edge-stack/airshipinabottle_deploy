#!/bin/bash
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
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
MYLOGFILE="`basename $0`-`date -Im`.log"
exec 1> >(tee -a "$MYLOGFILE") 2>&1
echo "Logging to $MYLOGFILE"

echo "Updating resolv.conf"
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo "Updating Time Zone"
timedatectl set-timezone UTC

echo "Now we are starting to deploy airship"
sleep 3
set -x
mkdir -p /root/deploy && cd "$_"
git clone https://git.openstack.org/openstack/airship-in-a-bottle
cd airship-in-a-bottle/
#git checkout 4e57ac85533b0a0962d567f344eb0a9c6150889f
git checkout 3ebe9bd8a05bb8095f5cdc53a746219e069bb40d

sed -i -e 's/virt_type:.*$/virt_type: kvm/g' ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/nova.yaml
sed -i -e 's#PROMENADE_IMAGE=.*$#PROMENADE_IMAGE=${PROMENADE_IMAGE:-"quay.io/airshipit/promenade@sha256:ff1c58e1d40d8b729b573921b492c44a12bbef92ba53ce8b56eb132ab3d66d02"}#g' ~/deploy/airship-in-a-bottle/manifests/common/deploy-airship.sh

#sed -i -e 's/tunnel: docker0$/tunnel: docker0\n      auto_bridge_add:\n        br-ex: bond0/g' \
#    -e 's/flat_networks: public$/flat_networks: public\n          ml2_type_vlan:\n            network_vlan_ranges: physnet:46:300/g' \
#    ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/neutron.yaml
#sed -i '0,/public:br-ex/s/public:br-ex/physnet:br-ex/' ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/neutron.yaml

#cp -p ~/deploy/airship-in-a-bottle/manifests/dev_single_node/heat-public-net-deployment.yaml \
#   ~/deploy/airship-in-a-bottle/manifests/dev_single_node/heat-public-net-deployment.yaml.orig
#sed -i -e 's/enable_dhcp:.*$/enable_dhcp: true/g' ~/deploy/airship-in-a-bottle/manifests/dev_single_node/heat-public-net-deployment.yaml
#sed -i -e 's/10.96.0.10/8.8.8.8/g' ~/deploy/airship-in-a-bottle/manifests/dev_single_node/heat-public-net-deployment.yaml

cd manifests/dev_single_node
./airship-in-a-bottle.sh  -y -y
set +x

pods=$(kubectl get pods -n openstack |wc -l)
if [ $pods -gt 75 ]; then
        set -x
        CPU=$[$(grep -c ^processor /proc/cpuinfo)/2]
        MEM=$[$(grep MemTotal /proc/meminfo | awk '{print $2;}')/1024/2]

        ~/deploy/airship-in-a-bottle/manifests/dev_single_node/run_openstack_cli.sh quota set --cores $CPU --ram $MEM admin
        ~/deploy/airship-in-a-bottle/manifests/dev_single_node/run_openstack_cli.sh quota show admin
        set +x
        echo "Environment Deployed: Please login to environment to validate further"
        exit 0
else
        echo "ERROR: Openstack Environment deployment Failed"
        exit 1;
fi

