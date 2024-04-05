#!/bin/bash

sudo apt-get install -y apt-transport-https ca-certificates curl gpg wget
sudo mkdir -m 755 /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.24/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.24/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
apt-cache madison kubeadm
sudo apt-get install -y kubelet kubeadm kubectl

sudo sed -ri 's/.*swap.*/#&/' /etc/fstab
sudo swapoff -a

mkdir containerd && cd containerd

wget -c https://github.com/containerd/containerd/releases/download/v1.6.8/containerd-1.6.8-linux-amd64.tar.gz
tar -xzvf containerd-1.6.8-linux-amd64.tar.gz
sudo mv bin/* /usr/local/bin/

wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mv containerd.service  /usr/lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
systemctl  status containerd
curl -LO https://github.com/opencontainers/runc/releases/download/v1.1.1/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

wget -c https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -xzvf  cni-plugins-linux-amd64-v1.1.1.tgz -C /opt/cni/bin/

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

#cat << EOF | sudo tee /etc/sysctl.conf
#net.bridge.bridge-nf-call-ip6tables=1
#net.bridge.bridge-nf-call-iptables=1
#net.ipv4.ip_forward=1
#vm.swappiness=0
#EOF
#sudo sysctl -p

sudo bash -c 'echo net.bridge.bridge-nf-call-ip6tables=1 >> /etc/sysctl.conf'
sudo bash -c 'echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf'
sudo bash -c 'echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf'
sudo bash -c 'echo vm.swappiness=0 >> /etc/sysctl.conf'
sudo sysctl -p

sudo sed -i 's/sandbox_image = "k8s.gcr.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.6"/g' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
systemctl status containerd --no-pager
kubeadm config images list --image-repository=registry.k8s.io --kubernetes-version=v1.24.17
kubeadm config images pull --image-repository=registry.k8s.io --kubernetes-version=v1.24.17
sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --image-repository=registry.k8s.io --v=6

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
watch -n 5 kubectl get po -A -o wide
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
