
[![Apache v2 License](https://img.shields.io/badge/license-Apache%202.0-brightgreen.svg)](https://github.com/ansible/awx/blob/devel/LICENSE.md)

# High-Availability Kubernetes Cluster for Micro ONOS SDN Controller Deployment

## Abstract
This repository provides a comprehensive guide for implementing a High-Availability (HA) Kubernetes cluster to deploy the micro ONOS SDN controller as microservices. Using Raspberry Pi devices as OpenFlow switches and Kubernetes workers, and virtual machines (via Vagrant and VirtualBox) for the control plane, this solution ensures robust and scalable deployment. The setup is automated with Ansible for ease of deployment and management. Follow the instructions below to configure and deploy the environment.

![Cluster Architecture](https://github.com/ricardopg1987/kubernetes-rpi/blob/main/onos.svg)

---

## Resources

**Control Plane and etcd**:
- Master-1
- Master-2
- Master-3

**Worker Nodes**:
- Raspberry Pi 4 (ARM) x1
- Raspberry Pi 4 (ARM) x2
- Raspberry Pi 4 (ARM) x3

**Container Network Interface (CNI)**:
- Calico

**HA Kubernetes Cluster**:
- Keepalived
- HAproxy

---

## 1. Install Raspbian on Each Node

### Preparing an SD Card (Linux)

1. **Download Raspbian**:  
   Get the latest Raspbian image from the official Raspberry Pi site:  
   [Download Raspbian](https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64.img.xz)

2. **Write the Image to the SD Card**:
   ```bash
   sudo dd if=YYYY-MM-DD-raspios-buster-arm64-lite.img of=/dev/sdX bs=16M status=progress
   ```

3. **Provision Wi-Fi Settings on First Boot**:
   Update the `bootstrap/wpa_supplicant.conf` file:
   ```plaintext
   ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
   update_config=1
   country=AU
   
   network={
       ssid="your_wifi_ssid"
       psk="your_wifi_password"
       key_mgmt=WPA-PSK
   }
   ```
   Copy the file to the SD card:
   ```bash
   cp bootstrap/wpa_supplicant.conf /mnt/boot/
   ```

4. **Enable SSH**:
   ```bash
   cp bootstrap/ssh /mnt/boot/ssh
   ```

5. **Example Commands**:
   ```bash
   sudo umount /media/<user>/boot
   sudo dd if=2022-09-22-raspios-bullseye-arm64.img of=/dev/<disk> bs=16M status=progress
   sync
   ```

---

## 2. Update Cluster Configuration

- Edit `cluster.yml` to match your setup.
- Configure static IPs via DHCP or manual assignment.

---

## 3. Install Required Tools

### Install `sshpass`:
```bash
sudo apt-get install sshpass
```

### Install Kubernetes:
```bash
ansible-playbook -i cluster.yml playbooks/upgrade.yml
```

### Overclock Raspberry Pi (Optional):
```bash
ansible-playbook -i cluster.yml playbooks/overclock-rpis.yml
```

### Install `k3s` on the Cluster:
```bash
ansible-playbook -i cluster.yml site.yml
```

---

## 4. Set Up High-Availability Kubernetes Cluster

### Install Keepalived and HAproxy:
```bash
sudo apt-get install keepalived haproxy -y
```

### Configure HAproxy:
Edit `/etc/haproxy/haproxy.cfg`:
```plaintext
global
    log /dev/log local0
    chroot /var/lib/haproxy
    pidfile /var/run/haproxy.pid
    maxconn 4000
    user haproxy
    group haproxy
    daemon

frontend kube-apiserver
    bind *:6443
    mode tcp
    default_backend kube-apiserver

backend kube-apiserver
    mode tcp
    balance roundrobin
    server master1 192.168.1.101:6443 check
    server master2 192.168.1.102:6443 check
    server master3 192.168.1.103:6443 check
```
Restart HAproxy:
```bash
sudo systemctl restart haproxy
```

### Configure Keepalived:
Edit `/etc/keepalived/keepalived.conf`:
```plaintext
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    authentication {
        auth_type PASS
        auth_pass mypassword
    }
    virtual_ipaddress {
        192.168.1.250
    }
}
```
Restart Keepalived:
```bash
sudo systemctl restart keepalived
```

---

## References
- [Install K3s on Raspberry Pi with Ansible](https://github.com/k3s-io/k3s-ansible)
- [Vagrant Get Started](https://developer.hashicorp.com/vagrant/tutorials/getting-started)
- [Set Up an HA Kubernetes Cluster](https://kubesphere.io/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/)
