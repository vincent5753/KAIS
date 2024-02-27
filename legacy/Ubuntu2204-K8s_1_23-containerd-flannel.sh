#!/bin/bash

# Install basic packages
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install Docker From Docker Official
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/containerd.io_1.5.10-1_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce_20.10.24~3-0~ubuntu-jammy_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-cli_20.10.24~3-0~ubuntu-jammy_amd64.deb
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

# Add k8s Repo
sudo su -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
sudo apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update

# Install k8s packages
version=1.23.17-00
echo $version
apt-cache show kubectl | grep "Version: $version"
sudo apt install -y kubelet=$version kubectl=$version kubeadm=$version
sudo apt-mark hold kubelet kubeadm kubectl

# Pull Image
sudo docker pull k8s.gcr.io/kube-apiserver-amd64:v1.23.17
sudo docker pull k8s.gcr.io/kube-controller-manager-amd64:v1.23.17
sudo docker pull k8s.gcr.io/kube-scheduler-amd64:v1.23.17
sudo docker pull k8s.gcr.io/kube-proxy-amd64:v1.23.17
sudo docker pull k8s.gcr.io/pause:3.6
sudo docker pull k8s.gcr.io/etcd:3.5.1-0
sudo docker pull k8s.gcr.io/coredns/coredns:v1.8.6

# Essential Tweaks
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
sudo swapoff -a

# Disable swap
sed -e '/swap/ s/^#*/# /' -i /etc/fstab
sudo free -m
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Init cluster
## For Master Node

sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --v=6
### Copy Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

### Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

### Waiting until Ready
kubectl cluster-info
watch -n 1 kubectl get nodes -o wide

### Taint(if needed)
kubectl taint nodes --all node-role.kubernetes.io/master-
