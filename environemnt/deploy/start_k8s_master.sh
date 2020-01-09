#!/bin/bash
#


IP_ADDR=$(ip -o -f inet addr show | awk '/scope global/ {print $4}'| head -n1)

# Starting server
sudo kubeadm init --pod-network-cidr="$IP_ADDR"

# Adding .kube to user home
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/configkubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


# Deploying a Pod Network

echo ">>>> NODE JOIN COMMAND <<<<"
kubeadm token create --print-join-command
