#!/bin/bash

sudo kubeadm reset -f
rm -rf ~/.kube
sudo apt remove -y --allow-change-held-packages kubelet kubectl kubeadm
sudo apt autoremove -y
sudo dpkg -r docker-ce
# sudo dpkg --purge docker-ce
sudo dpkg -r docker-ce-cli
# sudo dpkg --purge docker-ce-cli
sudo dpkg -r containerd.io
# sudo dpkg --purge containerd.io
sudo rm -rf /var/lib/docker /etc/docker
sudo rm /etc/apparmor.d/docker
sudo groupdel docker
sudo rm -rf /var/run/docker.sock