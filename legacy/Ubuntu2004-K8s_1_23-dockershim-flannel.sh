#!/bin/bash
# Verified by VP@22.04.03 02:45:44(+8) ( also playing Elden Ring :) )

# Install basic packages
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install Docker From Docker Official
DOCKER_DEB=(
  containerd.io_1.5.10-1_amd64.deb \
  docker-ce-cli_20.10.9~3-0~ubuntu-focal_amd64.deb \
  docker-ce_20.10.9~3-0~ubuntu-focal_amd64.deb
)
for DEB in ${DOCKER_DEB[@]}
do
  curl -s --create-dirs -o /tmp/docker_debs/$DEB https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/$DEB
  sudo dpkg -i /tmp/docker_debs/$DEB
  sudo rm -rf /tmp/docker_debs
done

sudo usermod -aG docker $USER
sudo systemctl enable docker --now
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
K8S_DEB=(
  cri-tools_1.26.0-00_amd64_5ba786e8853986c7f9f51fe850086083e5cf3c3d34f3fc09aaadd63fa0b578df.deb \
  kubectl_1.23.17-00_amd64.deb \
  kubelet_1.23.17-00_amd64.deb \
  kubeadm_1.23.17-00_amd64.deb \
  kubernetes-cni_1.2.0-00_amd64_0c2be3775ea591dee9ce45121341dd16b3c752763c6898adc35ce12927c977c1.deb
)
for DEB in ${K8S_DEB[@]}
do
  wget -P /tmp/k8s_debs https://github.com/vincent5753/KAIS/raw/main/legacy/deb/1.23/$DEB
  sudo apt install -y /tmp/k8s_debs/$DEB
  sudo rm -rf /tmp/k8s_debs
done

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

# Pre-Pull Kubernetes Component Image
# sudo docker pull registry.k8s.io/kube-apiserver-amd64:v1.23.17
# sudo docker pull registry.k8s.io/kube-controller-manager-amd64:v1.23.17
# sudo docker pull registry.k8s.io/kube-scheduler-amd64:v1.23.17
# sudo docker pull registry.k8s.io/kube-proxy-amd64:v1.23.17
# sudo docker pull registry.k8s.io/pause:3.6
# sudo docker pull registry.k8s.io/etcd:3.5.1-0
# sudo docker pull registry.k8s.io/coredns/coredns:v1.8.6
# https://kubernetes.io/docs/reference/setup-tools/kubeadm/generated/kubeadm_config_images_pull/
sudo kubeadm config images list --image-repository=registry.k8s.io --kubernetes-version=v1.23.17
sudo kubeadm config images pull --image-repository=registry.k8s.io --kubernetes-version=v1.23.17

# Init cluster
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
kubectl taint nodes --all node-role.kubernetes.io/master-
