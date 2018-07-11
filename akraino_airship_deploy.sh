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

echo "Updating resolv.conf"
echo "nameserver 8.8.4.4 >> /etc/resolv.conf"

echo "Adding neutron interface for the host"
tee -a /etc/network/interfaces << EOF

#OVERLAY/NEUTRON
auto bond0.45
iface bond0.45 inet static
address 10.0.102.41
netmask 255.255.255.0
vlan-raw-device bond0
mtu 9000
EOF

echo "Updating Time Zone"
timedatectl set-timezone UTC

echo "Now we are starting to deploy airship"
sleep 3
mkdir -p /root/deploy && cd "$_"
git clone https://git.openstack.org/openstack/airship-in-a-bottle
cd airship-in-a-bottle/
git checkout 4e57ac85533b0a0962d567f344eb0a9c6150889f
sed -i -e 's/virt_type:.*$/virt_type: kvm/g' ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/nova.yaml
sed -i -e 's/tunnel: docker0$/tunnel: docker0\n      auto_bridge_add:\n        br-ex: bond0/g' \
    -e 's/flat_networks: public$/flat_networks: public\n          ml2_type_vlan:\n            network_vlan_ranges: physnet:46:300/g' \
    ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/neutron.yaml
sed -i '0,/public:br-ex/s/public:br-ex/physnet:br-ex/' ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/neutron.yaml

cd manifests/dev_single_node
./airship-in-a-bottle.sh  -y -y
