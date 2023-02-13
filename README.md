 [![Apache v2 License](https://img.shields.io/badge/license-Apache%202.0-brightgreen.svg)](https://github.com/ansible/awx/blob/devel/LICENSE.md)

# Abstract
This repository contains the necessary steps to implement a High-Availability Kubernetes cluster (HA) for deploying micro ONOS SDN controller as a set of microservices. We use a set of Raspberry pi as openflow switces and kubernetes workers, as well as vagrant virtual machines to implements the control plane. All Raspberrys are running as worker nodes and deployed via Ansible implementation. The control plane for HA uses vagrant and virtualbox for control plane and etcd storage. To use this repo follow the setup instructions below.  

# Workflow
**Control plane and etcd:**
- Master-1
- Master-2
- Master-3

**Worker:**
- rPi 4(ARM) x1
- rPi 4(ARM) x2
- rPi 4(ARM) x3

**CNI:**
- Calico

**HA Kubernetes cluster:**
- Keepalived and HAproxy

# Install Raspbian at each node
## Preparing an SD card on Linux
```
# Write the image to the SD card
# Raspbian for ARM processor (https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64.img.xz)

# Linux
$ sudo dd if=YYYY-MM-DD-raspios-buster-arm64-lite.img of=/dev/sdX bs=16M status=progress

# I use Raspberry Pi Imager

# Provision wifi settings on first boot
$ cat bootstrap/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=AU

network={
    ssid=""
    psk=""
    key_mgmt=WPA-PSK
}

$ cp bootstrap/wpa_supplicant.conf /mnt/boot/

# Enable SSH on first boot
$ cp bootstrap/ssh /mnt/boot/ssh
```

```
Example flash and ssh/wifi:
sudo umount /media/<user>/boot
sudo umount /media/<user>/rootfs
sudo dd if=2021-05-07-raspios-buster-arm64-lite.img of=/dev/<disk> bs=16M status=progress
sync

# Unplug/replug SD card

cp bootstrap/wpa_supplicant.conf /media/<user>/boot/
cp bootstrap/ssh /media/<user>/boot/

sync
sudo umount /media/<user>/boot
sudo umount /media/<user>/rootfs
```

## Updating cluster.yml to match your environment
This is where there individual rPi's are set to HA embedded etcd database.  
I have not changed any passwords or configured SSH keys as this cannot be easily done with a headless rPi setup.  
I am currently using DHCP static assignment to ensure each PI's MAC address is given the same IP address.  
Update the file as required for your specific setup.

# Install sshpass
This is used as part of ansible connecting to the pi's over SSH with password auth
```
sudo apt-get install sshpass
```

# Install Kubernetes
## apt-get upgrade
```
ansible-playbook -i cluster.yml playbooks/upgrade.yml
```

## rPi Overclocks (optional)
Ensure you update cluster.yml with the correct children mappings for each rpi model
```
ansible-playbook -i cluster.yml playbooks/overclock-rpis.yml
```

## Install k3s
With the below commands, you need to include the master node (node00) in all executions for the token to be set correctly.
```
# Bootstrap the master and all slaves
ansible-playbook -i cluster.yml site.yml

# Bootstrap a single slave (node05)
ansible-playbook -i cluster.yml site.yml -l node00,node05

# When running again, feel free to ignore the common tag as this will reboot the rpi's
ansible-playbook -i cluster.yml site.yml --skip-tags common
```

## Copy over the .kube/config
This logs into node00 and copies the .kube/config file back into the local users ~/.kube/config file
Allowing a locally installed kubectl/etc to be able to query the cluster

```
# Copy in your kube config
ansible-playbook -i cluster.yml playbooks/copy-kube-config.yml

# Set an alias to make it easier
alias kubectl='docker run -it --rm -v ~/.kube:/.kube -v $(pwd):/pwd -w /pwd bitnami/kubectl:1.21.3'

# Run kubectl within docker
kubectl version
```

# Running things on the cluster!
You can look in the README.md in the kubernetes subfolder to see a few examples of things to run!

# Extra misc commands
```
# Shutdown all nodes
ansible -i cluster.yml -a "shutdown -h now" all

# Ensure NFS mount is active across cluster
ansible -i cluster.yml -a "mount -a" all
```

# Upgrading your cluster
First you need to upgrade the control plane (node00).
The below example is an upgrade from v1.15.0 -> v1.15.1

## Install the target kubeadm
```
sudo apt-get install kubeadm=1.15.1-00
```

## Plan the upgrade
```
sudo kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.15.0
[upgrade/versions] kubeadm version: v1.15.1
[upgrade/versions] Latest stable version: v1.15.1
[upgrade/versions] Latest version in the v1.15 series: v1.15.1

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     7 x v1.15.0   v1.15.1

Upgrade to the latest version in the v1.15 series:

COMPONENT            CURRENT   AVAILABLE
API Server           v1.15.0   v1.15.1
Controller Manager   v1.15.0   v1.15.1
Scheduler            v1.15.0   v1.15.1
Kube Proxy           v1.15.0   v1.15.1
CoreDNS              1.3.1     1.3.1
Etcd                 3.3.10    3.3.10

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.15.1

_____________________________________________________________________
```

## Apply the upgrade
```
sudo kubeadm upgrade apply v1.15.1
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.15.1"
[upgrade/versions] Cluster version: v1.15.0
[upgrade/versions] kubeadm version: v1.15.1
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y

...

[upgrade/successful] SUCCESS! Your cluster was upgraded.

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

## Update kube_version
```
cat roles/kubernetes/defaults/main.yml
---
kube_version: "1.15.1-00"

<snip>
```

## Upgrade the kubeXYZ tooling
```
ansible-playbook -i cluster.yml site.yml --tags upgrade,kubernetes
```

# Install control plane for all nodes
To install control plane nodes, this implementation apply the vagrant configuration file provided in this repository.
In this file we can configure the nodes that we want to deploy. In this case we are going to deploy 3 master nodes and 3 worker nodes. The required packages are installed in each node through the
**bootstrap.sh** file.
```
cd vagrantfile
vagrant up
vagrant ssh master1
```
Once vagrant deploy all virtualbox machines, we most to acces to each one to install all the packages required.
```
vagrant ssh master1
wget -c https://golang.org/dl/go1.16.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
nano ~/.profile
export PATH=$PATH:/usr/local/go/bin
source ~/.profile
go version
```

Install KIND
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Install Helm
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Install make, python-pip and reuse
```
sudo apt install make
apt-get install python3-pip -y
pip3 install --user reuse
```

Clone helmit repo
```
git clone https://github.com/onosproject/helmit.git
cd helmit
make deps
GO111MODULE=on go get github.com/onosproject/helmit/cmd/helmit
```

# Set up an HA Kubernetes Cluster Using Keepalived and HAproxy
A highly available Kubernetes cluster ensures your applications run without outages which is required for production. In this connection, there are plenty of ways for you to choose from to achieve high availability. https://kubesphere.io/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/

This tutorial demonstrates how to configure Keepalived and HAproxy for load balancing and achieve high availability. The steps are listed as below:
The cluster architecture is shown in the Figure below:
![This is an image](https://kubesphere.io/images/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/architecture-ha-k8s-cluster.png)

## Prerequisites
Install keepalived and haproxy on all nodes
```
sudo apt-get install keepalived haproxy -y
```
Configure HAproxy on all nodes
```
sudo nano /etc/haproxy/haproxy.cfg
```
Modify the following lines according to your environment:
```
global
    log /dev/log  local0 warning
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

   stats socket /var/lib/haproxy/stats

defaults
  log global
  option  httplog
  option  dontlognull
        timeout connect 5000
        timeout client 50000
        timeout server 50000

frontend kube-apiserver
  bind *:6443
  mode tcp
  option tcplog
  default_backend kube-apiserver

backend kube-apiserver
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server kube-apiserver-1 172.16.0.4:6443 check # Replace the IP address with your own.
    server kube-apiserver-2 172.16.0.5:6443 check # Replace the IP address with your own.
    server kube-apiserver-3 172.16.0.6:6443 check # Replace the IP address with your own.
```
Save the file and run the following command to restart HAproxy.
```
sudo systemctl restart haproxy
```
Configure Keepalived on all nodes
```
sudo nano /etc/keepalived/keepalived.conf
```
Add the following lines to the file, according to your environment:
```
global_defs {
  notification_email {
  }
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  vrrp_garp_interval 0
  vrrp_gna_interval 0
}

vrrp_script chk_haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}

vrrp_instance haproxy-vip {
  state BACKUP
  priority 100
  interface eth1                       # Network card
  virtual_router_id 60
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass 1111
  }
  unicast_src_ip 192.168.56.121      # The IP address of this machine
  unicast_peer {
    192.168.56.122                         # The IP address of peer machines
  }

  virtual_ipaddress {
    192.168.56.200/24                  # The VIP address
  }

  track_script {
    chk_haproxy
  }
}
```
Save the file and run the following command to restart Keepalived.
```
sudo systemctl restart keepalived
```
## Use KubeKey to Create a Kubernetes Cluster
Download KubeKey from its GitHub Release Page or use the following command directly.
```
curl -sfL https://get-kk.kubesphere.io | VERSION=v3.0.2 sh -
chmod +x kk
./kk create config --with-kubesphere v3.3.1 --with-kubernetes v1.22.12
```
### Deploy KubeSphere and Kubernetes
After you run the commands above, a configuration file config-sample.yaml will be created. Edit the file to add machine information, configure the load balancer and more.
```
...
spec:
  hosts:
  - {name: master1, address: 172.16.0.4, internalAddress: 172.16.0.4, user: root, password: Testing123}
  - {name: master2, address: 172.16.0.5, internalAddress: 172.16.0.5, user: root, password: Testing123}
  - {name: master3, address: 172.16.0.6, internalAddress: 172.16.0.6, user: root, password: Testing123}
  - {name: worker1, address: 172.16.0.7, internalAddress: 172.16.0.7, user: root, password: Testing123}
  - {name: worker2, address: 172.16.0.8, internalAddress: 172.16.0.8, user: root, password: Testing123}
  - {name: worker3, address: 172.16.0.9, internalAddress: 172.16.0.9, user: root, password: Testing123}
  roleGroups:
    etcd:
    - master1
    - master2
    - master3
    control-plane:
    - master1
    - master2
    - master3
    worker:
    - worker1
    - worker2
    - worker3
  controlPlaneEndpoint:
    domain: lb.kubesphere.local
    address: 172.16.0.10   # The VIP address
    port: 6443
...
```
Run the following command to deploy KubeSphere and Kubernetes.
```
./kk create cluster -f config-sample.yaml
```
### Verify installation
Run the following command to inspect the logs of installation.
```
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f
```
## Setup Raspberry PI as an OpenFlow switch
```
# Download openvswitch
wget http://openvswitch.org/releases/openvswitch-2.5.2.tar.gz
# Unpack archive
tar -xvzf openvswitch-2.5.2.tar.gz
# Install following dependancies
apt-get install python-simplejson python-qt4 libssl-dev python-twisted-conch automake autoconf gcc uml-utilities libtool build-essential pkg-config
apt-get install linux-headers-3.10-3-rpi
# Make the switch (Navigate to openvswitch-2.5.2 and enter the following commands)
./configure --with-linux=/lib/modules/3.10-3-rpi/build
make
make install

# Turn on openvswitch module
cd openvswitch-2.5.2/datapath/linux
modprobe openvswitch

# Create ovs_script.sh with the following code
#!/bin/bash
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
 --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
 --private-key=db:Open_vSwitch,SSL,private_key \
 --certificate=db:Open_vSwitch,SSL,certificate \
 --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
 --pidfile –detach
ovs-vsctl --no-wait init
ovs-vswitchd --pidfile –detach
ovs-vsctl show

# Create a file for the database, which will contain the details of the switch
touch /usr/local/etc/ovs-vswitchd.conf
# Create the following directory
mkdir -p /usr/local/etc/openvswitch
# Populate the database, which will be used by the ovswitch
./openvswitch-2.5.2/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db openvswitch-2.5.2/vswitchd/vswitch.ovsschema

# Run ovs_script.sh

# Add a new bridge
ovs-vsctl add-br br0

# Bind the ports to the newly added bridge
ifconfig eth1 0 up
ifconfig eth2 0 up

# Set the interfaces up
ifconfig eth1 0 up
ifconfig eth2 0 up

# Connect the switch to an external controller
ovs-vsctl set-controller br0 tcp:20.0.0.7:6634

# Configuring the switch to initialize as an OpenFlow switch at startup
# Add the following bash script to the location of openvswitch-2.5.2 and rename it to main_script.sh
#!/bin/bash
cd openvswitch-2.5.2/datapath/linux
modprobe openvswitch
cd ..
cd ..
cd ..
./ovs_script.sh
ifconfig eth1 0 up
ifconfig eth2 0 up

# Then add the following line at the end of .bashrc
sudo sh [location of main_script.sh]/main_script.sh
```

