#!/bin/bash

set -e

TEMP_DIR="/tmp/kais"

PACKAGES_TO_INSTALL=(
    apt-transport-https
    ca-certificates
    curl
    gpg
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
    mkdir -p "${TEMP_DIR}"
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

    local request_result
    # Ensure OS_ID is lowercase for the URL
    local target_url="https://download.docker.com/linux/${OS_ID}/dists/${OS_CODE_NAME}/pool/stable/${CPU_ARCH}/"

    _info "Fetching versions from: ${target_url}"
    request_result=$(curl -sL "${target_url}")

    for package in docker-ce docker-ce-cli containerd.io
    do
        # This regex captures the full version string including metadata (~ubuntu...)
        # It looks for: package_ [capture everything] _cpu_arch.deb
        package_version=$(echo "${request_result}" | grep -oP "${package}_\K[^_]+(?=_${CPU_ARCH}\.deb)" | sort -V | tail -n 1)

        if [ -z "${package_version}" ]; then
            _error "Could not find version for ${package}"
            continue
        fi

        case "${package}" in
            docker-ce)     dockerce_version="${package_version}" ;;
            docker-ce-cli) dockercecli_version="${package_version}" ;;
            containerd.io) containerd_version="${package_version}" ;;
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


get_os_info(){

    OS_RELESE_VER=$(lsb_release -r -s 2>/dev/null)
    OS_CODE_NAME=$(lsb_release -c -s 2>/dev/null)
    OS_ID=$(lsb_release -i -s 2>/dev/null)

        case "${OS_ID}" in

            Debian)
            OS_ID="debian"
            ;;

            Ubuntu)
            OS_ID="ubuntu"
            ;;

            *)
            _error "Unexpected Distro ID."
            exit 1
            ;;
        esac
    _info "Detected OS_ID: ${OS_ID}"
    _info "Detected OS_CODE_NAME: ${OS_CODE_NAME}"
    _info "Detected OS_RELESE_VER: ${OS_RELESE_VER}"

    CPU_ARCH=$(uname -m)


        case "${CPU_ARCH}" in

            x86_64)
            CPU_ARCH="amd64"
            ;;

            amd64)
            CPU_ARCH="amd64"
            ;;

            aarch64)
            CPU_ARCH="arm64"
            ;;

            arm64)
            CPU_ARCH="arm64"
            ;;

            *)
            _error "Unexpected CPU ARCH."
            exit 1
            ;;
        esac

    _info "Detected CPU_ARCH: ${CPU_ARCH}"

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

    # _info "Latest Kubernetes Full Version: ${K8S_FULL_VERSION}"
    # _info "Latest Kubernetes Version: ${K8S_VERSION_NO_V}"
    _info "Latest Kubernetes MAJOR_MINOR Version: ${K8S_MAJOR_MINOR_VERSION}"

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
    if check_command_available "iptables"; then
        _info "iptables is installed."
    else
        _info "iptables is NOT installed, installing it because docker-ce needs it."
        install_apt_packages iptables
    fi

    local docker_deb_dir="${TEMP_DIR}/docker_debs"
    base_url="https://download.docker.com/linux/${OS_ID}/dists/${OS_CODE_NAME}/pool/stable/${CPU_ARCH}"

    # Step 1: Download all required debs first
    _info "Downloading debs from Docker repository..."
    for DEB in "${DOCKER_DEB[@]}"; do
        _info "Fetching: ${DEB}"
        curl -s --create-dirs -L -o "${docker_deb_dir}/${DEB}" "${base_url}/${DEB}"
    done

    # Step 2: Atomic installation
    # Passing all files to dpkg at once lets it resolve dependencies (CLI vs Engine) internally.
    _info "Installing Docker packages via dpkg..."
    sudo dpkg -i "${docker_deb_dir}/"*.deb || {
        _error "dpkg encountered issues; attempting to fix dependencies with apt..."
        sudo apt-get install -f -y
    }

    # Step 3: Containerd configuration (Crucial for K8s)
    _info "Setting up containerd"
    sudo mkdir -p /etc/containerd
    # Generate default config and enable SystemdCgroup
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml

    _info "Verifying SystemdCgroup setting:"
    grep "SystemdCgroup" /etc/containerd/config.toml

    sudo systemctl restart containerd

    # Step 4: Docker Engine configuration
    _info "Changing docker cgroup driver to systemd"
    sudo mkdir -p /etc/docker
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

    # Step 5: Post-install setup
    sudo mkdir -p /etc/systemd/system/docker.service.d

    _info "Adding current user to docker group"
    # Using $USER as a fallback if logname fails in certain shell environments
    CURRENT_USER=$(logname 2>/dev/null || echo $USER)
    sudo usermod -aG docker "$CURRENT_USER"

    _info "Reloading systemd and restarting Docker"
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker

    # Final health check
    systemctl status --no-pager docker | grep "Active:"
}


add_k8s_apt_repo(){

    _info "Adding Kubernetes apt repo"
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/deb/Release.key" | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update

}


do_k8s_tweaks(){

    _info "Doing some system tweaks needed by kubertes"

    _info "Disabling off swap"
    sudo swapoff -a
    sudo sed -i '/swap/s/^/#/' /etc/fstab
    sudo ln -sf /dev/null /etc/systemd/system-generators/systemd-gpt-auto-generator
    _info "Link /dev/null to /etc/systemd/system-generators/systemd-gpt-auto-generator to avoid systemd auto generate swap service"

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
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

}


remove_node_taint(){

    _info "Remove taint from the node"
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

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

    trap _clean_up EXIT

    # Gather the init info for installation
    get_os_info
    get_k8s_relaese_version
    get_flannel_latest_version
    # Create tmp dir for KAIS
    _mk_tmp_dir
    # Install essential packages for Kubernetes
    install_apt_packages "${PACKAGES_TO_INSTALL[@]}"
    # Install Container Runtime (Docker)
    _get_latest_docker_version
    if [ -z "${containerd_version}" ] || [ -z "${dockerce_version}" ] || [ -z "${dockercecli_version}" ]; then
        _error "Could not determine all latest Docker package versions. One or more version variables are empty."
    fi
    DOCKER_DEB=(
        "containerd.io_${containerd_version}_${CPU_ARCH}.deb"
        "docker-ce_${dockerce_version}_${CPU_ARCH}.deb"
        "docker-ce-cli_${dockercecli_version}_${CPU_ARCH}.deb"
    )
    install_docker_runtime
    # Install Kubernetes
    add_k8s_apt_repo
    do_k8s_tweaks
    install_apt_packages "${K8S_CONTROL_PLANE_PACKAGE[@]}"
    mark_apt_packages "${K8S_CONTROL_PLANE_PACKAGE[@]}"
    sudo systemctl enable --now kubelet
    if [ ! -f /etc/kubernetes/admin.conf ]; then
        sudo kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --image-repository=registry.k8s.io --v=6
    fi
    copy_kube_config
    remove_node_taint
    ## Apply CNI
    kubectl apply -f https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION}/kube-flannel.yml
    # Bye
    _clean_up

}

main
