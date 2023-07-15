#!/bin/bash
# Verified by VP@22.04.03 02:45:44(+8) ( also playing Elden Ring :) )

# Install basic packages
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Add Docker office gpg key
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

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

# Add k8s Repo
sudo su -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update

# Install k8s packages
version=1.23.6-00
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
# 感覺壞了?
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
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
