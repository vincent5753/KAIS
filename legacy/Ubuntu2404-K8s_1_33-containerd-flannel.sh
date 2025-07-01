#!/bin/bash

TEMP_DIR="/tmp/kais"
OS_CODE_NAME="noble"
OS_RELESE_VER="24.04"
CPU_ARCH="amd64"
KERNEL_VER="6.8.0"
K8S_VER="1.33"

PACKAGES_TO_INSTALL=(
    apt-transport-https
    ca-certificates
    curl
    gpg
)

DOCKER_DEB=(
    containerd.io_1.7.27-1_amd64.deb
    docker-ce_28.3.0-1~ubuntu.24.04~noble_amd64.deb
    docker-ce-cli_28.3.0-1~ubuntu.24.04~noble_amd64.deb
)

K8S_CONTROL_PLANE_PACKAGE=(
    kubelet
    kubeadm
    kubectl
)

K8S_WORKER_NODE_PACKAGE=(
    kubelet
    kubeadm
)



_mk_tmp_dir(){
    mkdir "${TEMP_DIR}"
}


_clean_up(){

    sudo rm -rf "${TEMP_DIR}"

}


_info(){
    echo "[INFO] $1"
}


_error(){
    echo "[ERROR] $1"
}


_get_latest_docker_version(){

    request_result=$(curl https://download.docker.com/linux/ubuntu/dists/${OS_CODE_NAME}/pool/stable/${CPU_ARCH}/)

    for package in docker-ce docker-ce-cli containerd.io
    do

        package_version=$(echo "${request_result}" | grep "${package}_" | sed -n "s/.*${package}_\([^_]*\)_${CPU_ARCH}\.deb.*/\1/p" | sort -V | tail -n 1 | cut -d'~' -f1)

    case "${package}" in

        docker-ce)
        dockerce_version="${package_version}"
        ;;

        docker-ce-cli)
        dockercecli_version="${package_version}"
        ;;

        containerd.io)
        containerd_version="${package_version}"
        ;;

        *)
        _error "Not expected package."
        ;;
    esac

    done

}



check_command_available(){

    local command_name="$1"

    which "${command_name}" > /dev/null 2>&1

    if [ $? -eq 0 ]
    then
        return 0
    else
        return 1
    fi

}


install_apt_packages(){

    if [ "$#" -eq 0 ]; then
        _error "Please provide at least one package name to install."
        return 1
    fi

    _info "Updating package lists..."
    sudo apt-get update -y

    _info "Installing specified packages..."
    for package in "$@"; do
        _info "Checking if ${package} is already callable..."
        if check_command_available "${package}"; then
            _info "${package} is already callable. Skipping installation."
        else
            _info "Attempting to install: ${package}"
            sudo apt-get install -y "${package}"
            if [ $? -eq 0 ]; then
                _info "${package} installed successfully."
            else
                _error "Failed to install ${package}. Please check the package name or your internet connection."
            fi
        fi
    done

    _info "Package installation process completed."

}


mark_apt_packages(){

    if [ "$#" -eq 0 ]; then
        _error "Please provide at least one package name to mark."
        return 1
    fi

    sudo apt-mark hold "$@"

}


install_docker_runtime(){

    _info "Checking if iptables is installed"
    if check_command_available "iptables"
    then
        _info "iptables is installed."
    else
        _info "iptables is NOT installed, installing it cuz docker-ce needs it."
        install_apt_packages iptables
    fi

    base_url="https://download.docker.com/linux/ubuntu/dists/${OS_CODE_NAME}/pool/stable/${CPU_ARCH}"

    _info "Download and installing debs from docker"
    for DEB in ${DOCKER_DEB[@]}
    do
        _info "Download and installing ${DEB}"
        curl -s --create-dirs -o "${TEMP_DIR}/docker_debs/${DEB}" "${base_url}/$DEB"
        sudo dpkg -i "${TEMP_DIR}/docker_debs/${DEB}"
    done

    # containerd
    _info "Setting up containerd"
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
    grep SystemdCgroup /etc/containerd/config.toml
    sudo systemctl restart containerd

_info "Changing docker cgroup driver to systemd"
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
    _info "Adding current user to docker group"
    sudo usermod -aG docker $(logname)
    _info "Restarting docker"
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker
    systemctl status --no-pager docker

}


add_k8s_apt_repo(){

    _info "Adding Kubernetes apt repo"
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key" | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update

}


do_k8s_tweaks(){

    _info "Doing some system tweaks needed by kubertes"
    _info "Disabling off swap"
    sudo swapoff -a
    sudo sed -i '/swap/s/^/#/' /etc/fstab
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    _info "Loading Linux Kernel Modules"
    sudo modprobe overlay
    sudo modprobe br_netfilter
    _info "Writing sysctl configs"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system

}


copy_kube_config(){

    _info "Copy kube config to home directory"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

}


remove_node_taint(){

    _info "Remove taint from the node"
    kubectl taint nodes --all node-role.kubernetes.io/master-
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-

}


main(){

    _mk_tmp_dir
    install_apt_packages "${PACKAGES_TO_INSTALL[@]}"
    install_docker_runtime
    add_k8s_apt_repo
    do_k8s_tweaks
    install_apt_packages "${K8S_CONTROL_PLANE_PACKAGE[@]}"
    mark_apt_packages "${K8S_CONTROL_PLANE_PACKAGE[@]}"
    sudo systemctl enable --now kubelet
    sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --image-repository=registry.k8s.io --v=6
    copy_kube_config
    remove_node_taint
    kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.24.4/kube-flannel.yml
    _clean_up

}

main
