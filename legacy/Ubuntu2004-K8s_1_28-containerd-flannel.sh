#!/bin/bash
# By VP@23.08.17

# Install bacsic packages
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install Docker From Docker Official
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.6.22-1_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_24.0.5-1~ubuntu.20.04~focal_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_24.0.5-1~ubuntu.20.04~focal_amd64.deb
sudo dpkg -i *.deb
rm *.deb
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
sudo docker version

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
grep SystemdCgroup /etc/containerd/config.toml
sudo systemctl restart containerd

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

sudo su -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update

# Essential Tweaks
sudo swapoff -a
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# insall k8s
version=1.28.0-00
echo $version
apt-cache show kubectl | grep "Version: $version"
sudo apt install -y kubelet=$version kubectl=$version kubeadm=$version
sudo apt-mark hold kubelet kubeadm kubectl
sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --v=6

## Copy Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

## Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

## Waiting until Ready
kubectl cluster-info
watch -n 1 kubectl get nodes -o wide

## Taint(if needed)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
