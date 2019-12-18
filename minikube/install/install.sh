#!/bin/bash
#
# Help install a minikube setup
#
# Consider this script an alpha version as not validation for success is present
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine



while getopts u: option
do
case "${option}"
in
u) LUXUSER=${OPTARG};;
*) UNKNOWN=${OPTARG};;
esac
done


if [ -n "$UNKNOWN" ]; then
  echo "$UNKNOWN"
  echo 'Has extra parameter'
  exit 1
fi

if [ -n "$LUXUSER" ]; then
  sudo install cpfw-login_amd64 /usr/local/bin/
  cpfw-login_amd64 --user "$LUXUSER"

  # Create directories and their parent directories if necessary
  sudo mkdir -p /usr/local/share/ca-certificates/luxoft
  sudo mkdir -p ~/.minikube/files/etc/ssl/certs

  # Generate certificate
  echo -n | openssl s_client -showcerts -connect dl.k8s.io:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > kube.chain.pem

  # Extract the last certificate
  csplit -f htf kube.chain.pem '/-----BEGIN CERTIFICATE-----/' '{*}' | sudo cat $(ls htf* | sort | tail -1) > luxoft_root_ca.crt && rm -rf htf*
fi
# Install curl
sudo apt-get install -y curl

# install kubectl
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Uninstall docker first
sudo apt-get -y remove docker docker-engine docker.io containerd runc

# Install packaes to allow apt to use a repository over HTTPS
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

#Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Install Docker
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

# Download minikube
sudo curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Give execute rightes
sudo chmod +x minikube

# Add minikube to path
sudo mkdir -p /usr/local/bin/
sudo install minikube /usr/local/bin/

#Install VirtualBox
sudo apt-get -y update
sudo apt-get -y install virtualbox

# Add to path
if [ -n "$LUXUSER" ]; then
  # Copy certifiates
  sudo cp luxoft_root_ca.crt /usr/local/share/ca-certificates/luxoft/luxoft_root_ca.crt
  sudo cp luxoft_root_ca.crt ~/.minikube/files/etc/ssl/certs/luxoft_root_ca.crt

  # Update certificates
  sudo update-ca-certificates
fi

sudo minikube start --vm-driver=none
