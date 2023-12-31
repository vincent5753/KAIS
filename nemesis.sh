#!/bin/bash

sudo kubeadm reset -f
rm -rf ~/.kube
sudo apt remove -y --allow-change-held-packages kubelet kubectl kubeadm
sudo apt autoremove -y

sudo systemctl stop docker.socket
sudo systemctl stop docker.service
sudo dpkg --purge docker-ce-cli docker-ce containerd.io

sudo rm -rf /var/lib/docker /etc/docker
sudo rm /etc/apparmor.d/docker
sudo groupdel docker
sudo rm -rf /var/run/docker.sock

sudo systemctl stop containerd
sudo dpkg --purge containerd.io
sudo dpkg --purge containerd
sudo rm -rf /var/lib/containerd/
