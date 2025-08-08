#!/bin/bash

# This script installs a single-node Kubernetes cluster with containerd and flannel.
# It supports both Debian-based (Ubuntu) and RHEL-based (Rocky Linux) distributions.

_info(){
    echo "[INFO] $1"
}

_error(){
    echo "[ERROR] $1"
}

detect_os_family() {
    _info "Detecting operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                OS_FAMILY="debian"
                ;;
            rocky|centos|rhel|fedora)
                OS_FAMILY="rhel"
                ;;
            *)
                _error "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
        _info "Detected OS family: $OS_FAMILY"
    else
        _error "Cannot detect OS: /etc/os-release not found."
        exit 1
    fi
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

disable_selinux(){

    _info "Disabling SELinux..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

}


add_yum_repo(){

    sudo yum-config-manager --add-repo "$1"

}


install_dnf_packages(){

    if [ "$#" -eq 0 ]; then
        _error "Please provide at least one package name to install."
        return 1
    fi

    _info "Updating package lists..."
    sudo dnf check-update -y

    _info "Installing specified packages..."
    for package in "$@"; do
        _info "Checking if ${package} is already callable..."
        if check_command_available "${package}"; then
            _info "${package} is already callable. Skipping installation."
        else
            _info "Attempting to install: ${package}"
            sudo dnf install -y "${package}"
            if [ $? -eq 0 ]; then
                _info "${package} installed successfully."
            else
                _error "Failed to install ${package}. Please check the package name or your internet connection."
            fi
        fi
    done

}

add_k8s_yum_repo(){

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

}


install_k8s_yum_packages(){

    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

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


add_k8s_apt_repo(){

    _info "Adding Kubernetes apt repo"
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/deb/Release.key" | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update

}


get_k8s_relaese_version(){

    local K8S_RELEASE_URL="https://dl.k8s.io/release/stable.txt"

    _info "Fetching latest stable Kubernetes version..."

    K8S_FULL_VERSION=$(curl -Ls "${K8S_RELEASE_URL}")

    if [ -z "$K8S_FULL_VERSION" ]; then
        _error "Could not fetch Kubernetes version from ${K8S_RELEASE_URL}"
        exit 1
    fi

    K8S_VERSION_NO_V=$(echo "$K8S_FULL_VERSION" | sed 's/^v//')
    K8S_MAJOR_MINOR_VERSION=$(echo "$K8S_VERSION_NO_V" | cut -d'.' -f1,2)

    _info "Latest Kubernetes MAJOR_MINOR Version: ${K8S_MAJOR_MINOR_VERSION}"

}


change_containerd_to_cgroup_driver(){

    _info "Setting up containerd to use cgroup driver"
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
    sudo systemctl restart containerd

}


do_k8s_tweaks(){

    _info "Doing some system tweaks needed by kubertes"
    _info "Disabling off swap"
    sudo swapoff -a
    sudo sed -i '/swap/s/^/#/' /etc/fstab
    [ ! -d "/etc/systemd/system-generators" ] && sudo mkdir -p "/etc/systemd/system-generators" && _info "Created path: /etc/systemd/system-generators"
    _info "Link /dev/null to /etc/systemd/system-generators/systemd-gpt-auto-generator to avoid systemd auto generate swap service"
    sudo ln -s /dev/null /etc/systemd/system-generators/systemd-gpt-auto-generator

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


get_flannel_latest_version(){

    local FLANNEL_LATEST_URL="https://api.github.com/repos/flannel-io/flannel/releases/latest"

    _info "Fetching latest stable Flannel version..."

    FLANNEL_VERSION=$(curl -Ls "${FLANNEL_LATEST_URL}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$FLANNEL_VERSION" ]; then
        _error "Could not fetch Flannel version from ${FLANNEL_LATEST_URL}"
        exit 1
    fi

    _info "Latest Flannel Version: ${FLANNEL_VERSION}"

}


main(){

    detect_os_family

    get_k8s_relaese_version
    get_flannel_latest_version

    if [ "$OS_FAMILY" == "rhel" ]; then
        _info "Running on a RHEL-based system."
        disable_selinux
        sudo yum install -y yum-utils
        add_yum_repo "https://download.docker.com/linux/centos/docker-ce.repo"
        install_dnf_packages "containerd.io"
        sudo systemctl enable containerd
        change_containerd_to_cgroup_driver
        add_k8s_yum_repo
        do_k8s_tweaks
        install_k8s_yum_packages
    elif [ "$OS_FAMILY" == "debian" ]; then
        _info "Running on a Debian-based system."
        PACKAGES_TO_INSTALL=(
            apt-transport-https
            ca-certificates
            curl
            gpg
        )
        install_apt_packages "${PACKAGES_TO_INSTALL[@]}"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        install_apt_packages "containerd.io"
        sudo systemctl enable containerd
        change_containerd_to_cgroup_driver
        add_k8s_apt_repo
        do_k8s_tweaks
        K8S_PACKAGES=(
            kubelet
            kubeadm
            kubectl
        )
        install_apt_packages "${K8S_PACKAGES[@]}"
        mark_apt_packages "${K8S_PACKAGES[@]}"
    else
        _error "Unsupported OS family: $OS_FAMILY"
        exit 1
    fi

    sudo systemctl enable --now kubelet
    sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --image-repository=registry.k8s.io --v=6
    copy_kube_config
    remove_node_taint
    kubectl apply -f https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION}/kube-flannel.yml

}

main
