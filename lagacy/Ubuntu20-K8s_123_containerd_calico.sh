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
## For Master Node

# flannel config
#sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --v=6
# calico config
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
### Copy Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

### Flannel CNI
#kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
### calico CNI
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml


### Waiting until Ready
kubectl cluster-info
watch -n 1 kubectl get nodes
watch kubectl get pods -n calico-system

### Taint(if needed)
kubectl taint nodes --all node-role.kubernetes.io/master-
#kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-

