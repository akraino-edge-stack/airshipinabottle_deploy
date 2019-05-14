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
for i in `ls /opt/images/img*.tar`; do echo "loading image $i"; docker load -i $i ; done

echo "Now we are starting to deploy airship"
sleep 3
set -x
mkdir -p /root/deploy && cd "$_"
git clone https://git.openstack.org/openstack/airship-in-a-bottle
cd airship-in-a-bottle/
git checkout 5613857adebf4b063f4e01ceaaee17fb62e50e3d
export PROMENADE_IMAGE="quay.io/airshipit/promenade:66ab47386f5a5a41746ec32fc3bc166079e79b43"

sed -i -e 's/virt_type:.*$/virt_type: kvm/g' ~/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/charts/osh/compute-kit/nova.yaml

cd manifests/dev_single_node
sed -i -e 's/curl/#curl/g' test_create_heat_stack.sh
curl -LO https://raw.githubusercontent.com/openstack/openstack-helm/master/tools/gate/files/heat-basic-vm-deployment.yaml
curl -LO https://raw.githubusercontent.com/openstack/openstack-helm/master/tools/gate/files/heat-public-net-deployment.yaml
sed -i -e 's/enable_dhcp: .*$/enable_dhcp: true/g' -e 's/10.96.0.10/8.8.8.8/g' heat-public-net-deployment.yaml

# reduce frequency of shipyard status checks
export max_shipyard_count=${max_shipyard_count:-30}
export shipyard_query_time=${shipyard_query_time:-120}

./airship-in-a-bottle.sh  -y -y
./test_create_heat_stack.sh

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

        ~/deploy/airship-in-a-bottle/tools/run_openstack_cli.sh quota set --cores $CPU --ram $MEM admin
        ~/deploy/airship-in-a-bottle/tools/run_openstack_cli.sh quota show admin
        ~/deploy/airship-in-a-bottle/tools/run_openstack_cli.sh subnet set --dhcp --dns-nameserver 8.8.8.8 public
        ~/deploy/airship-in-a-bottle/tools/run_openstack_cli.sh subnet show public
        set +x
        echo "Environment Deployed: Please login to environment to validate further"
        exit 0
else
        echo "ERROR: Openstack Environment deployment Failed"
        exit 1;
fi

