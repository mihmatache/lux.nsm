#!/bin/bash
#
# Help install a minikube setup
#
# Consider this script an alpha version as not validation for success is present
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine
# You will be prompted to enter the sudo password as well

DEFAULT_KUBERNETES_VERSION="1.17.0-00"

usage="$(basename "$0") Helps deploy a standard minikube setup.
  Arguments:

  -l <luxoft username>: Provide this argument if deploying in a LUXOFT environment.
                        This represents you Luxoft account username. You will be prompted for your account passowrd!

  -k <string>:          Kubeernetes version to install. If not passed default will be used (default: $DEFAULT_KUBERNETES_VERSION)
  "


while getopts 'hl:k:' option
do
case "${option}"
in
h) echo "$usage"
   exit
   ;;
l) LUX_USER=${OPTARG};;
k) KUBERNETES_VERSION=${OPTARG};;
*)echo 'Unknown argument passed as input. Exiting!'
  exit 1
  ;;
esac
done

# Storing desired variable values. Check if passed by argument, else pass default
if [ -z "$KUBERNETES_VERSION" ]; then
  echo "No <kubectl> version passed. Using default: $DEFAULT_KUBERNETES_VERSION"
  KUBERNETES_VERSION="$DEFAULT_KUBERNETES_VERSION"
else
  echo "Setting <kubectl> version to: $KUBERNETES_VERSION"
fi

# Checking if LUX_USER has been provided. If it is provided consider this a luxoft network and connect and prepare certificates
if [ -n "$LUX_USER" ]; then
  echo "Luxoft environment defined!"
  sudo install cpfw-login_amd64 /usr/local/bin/
  echo "Please enter passowrd for provided LUXOFT user:  $LUX_USER"
  cpfw-login_amd64 --user "$LUX_USER"
  if [ $? -ne 0 ]; then
    echo "ERROR: Invalid passowrd provided for user: $LUX_USER"
    exit 1
  fi

  # Create directories and their parent directories if necessary
  sudo mkdir -p /usr/local/share/ca-certificates/luxoft

  # Generate certificate
  echo -n | openssl s_client -showcerts -connect dl.k8s.io:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > kube.chain.pem

  # Extract the last certificate
  csplit -f htf kube.chain.pem '/-----BEGIN CERTIFICATE-----/' '{*}' | sudo cat $(ls htf* | sort | tail -1) > luxoft_root_ca.crt && rm -rf htf*
else
  echo "Non Luxoft environment!"
fi

# Install prerequisite packages
sudo apt-get -y update
sudo apt-get install -y curl
sudo apt-get install -y apt-transport-https
sudo apt-get install -y ca-certificates
sudo apt-get install -y software-properties-common


# Check if kubectl is installed
echo "Installing kubectl $KUBERNETES_VERSION"
kubectl > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Kubectl is installed"
    exit 0
fi

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

sudo apt-get install -y kubeadm="$KUBERNETES_VERSION"
sudo apt-get install -y kubectl="$KUBERNETES_VERSION"
sudo apt-get install -y kubelet="$KUBERNETES_VERSION"

echo "Adding nodes to hosts file"
HOSTS=$(cat .nodes)
echo "$HOSTS" | sudo tee -a /etc/hosts


echo 'Disabling swap'
sudo swapoff -a
sudo sed -i '/[/]swap.img/ s/^/#/' /etc/fstab
