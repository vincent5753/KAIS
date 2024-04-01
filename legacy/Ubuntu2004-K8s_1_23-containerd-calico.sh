#!/bin/bash

sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

mkdir debfiles && cd debfiles

# Install Docker From Docker Official
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.5.10-1_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_20.10.9~3-0~ubuntu-focal_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.9~3-0~ubuntu-focal_amd64.deb
sudo dpkg -i *.deb
rm *.deb
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
sudo docker version

# change docker cgroup driver to systemd
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl status --no-pager docker

# Pull k8s from legacy repo
wget https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/cri-tools_1.26.0-00_amd64_5ba786e8853986c7f9f51fe850086083e5cf3c3d34f3fc09aaadd63fa0b578df.deb
wget https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/kubeadm_1.23.17-00_amd64.deb
wget https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/kubectl_1.23.17-00_amd64.deb
wget https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/kubelet_1.23.17-00_amd64.deb
wget https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/kubernetes-cni_1.2.0-00_amd64_0c2be3775ea591dee9ce45121341dd16b3c752763c6898adc35ce12927c977c1.deb
sudo apt install -y ./*.deb
rm ./*.deb

# Essential Tweaks
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo free -m
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Init cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
## Copy Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

### calico CNI
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml

## Waiting until Ready
kubectl cluster-info
watch -n 1 kubectl get nodes
watch kubectl get pods -n calico-system

## Taint(if needed)
kubectl taint nodes --all node-role.kubernetes.io/master-
#kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-
