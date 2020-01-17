#!/bin/bash
#
# Help install a minikube setup
#
# Consider this script an alpha version as not validation for success is present
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine
# You will be prompted to enter the sudo password as well

DEFAULT_MINIKUBE_VERSION="v1.6.1"
DEFAULT_KUBECTL_VERSION="v1.17.0"
DEFAULT_VIRTUALBOX_VERSION="6.0"

usage="$(basename "$0") Helps deploy a standard minikube setup.
  Arguments:

  -u <luxoft username>: Provide this argument if deploying in a LUXOFT environment.
                        This represents you Luxoft account username. You will be prompted for your account passowrd!

  -k <string>:          Kubectl version to install. If not passed default will be used (default: $DEFAULT_KUBECTL_VERSION)

  -m <string>:          Minikube version to install. If not passed default will be used (default: $DEFAULT_MINIKUBE_VERSION)

  -v <string>:          VirtualBox version to install. If not passed default will be used (default $DEFAULT_VIRTUALBOX_VERSION)
  "


while getopts 'hu:k:m:v:' option
do
case "${option}"
in
h) echo "$usage"
   exit
   ;;
u) LUX_USER=${OPTARG};;
k) KUBECTL_VERSION=${OPTARG};;
m) MINIKUBE_VERSION=${OPTARG};;
v) VIRTUALBOX_VERSION=${OPTARG};;
*)echo 'Unknown argument passed as input. Exiting!'
  exit 1
  ;;
esac
done

# Storing desired variable values. Check if passed by argument, else pass default
if [ -z "$KUBECTL_VERSION" ]; then
  echo "No <kubectl> version passed. Using default: $DEFAULT_KUBECTL_VERSION"
  KUBECTL_VERSION="$DEFAULT_KUBECTL_VERSION"
else
  echo "Setting <kubectl> version to: $KUBECTL_VERSION"
fi

if [ -z "$MINIKUBE_VERSION" ]; then
  echo "No <minikube> version passed. Using default: $DEFAULT_MINIKUBE_VERSION"
  MINIKUBE_VERSION="$DEFAULT_MINIKUBE_VERSION"
else
  echo "Setting <minikube> version to: $MINIKUBE_VERSION"
fi

if [ -z "$VIRTUALBOX_VERSION" ]; then
  echo "No <minikube> version passed. Using default: $DEFAULT_VIRTUALBOX_VERSION"
  VIRTUALBOX_VERSION="$DEFAULT_VIRTUALBOX_VERSION"
else
  echo "Setting <minikube> version to: $VIRTUALBOX_VERSION"
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

# Check virtualization support in Linux
if [ -z "$(grep -E --color 'vmx|svm' /proc/cpuinfo)" ]; then
    echo "No Virtualization support in Linux"
    exit  1
else
    echo "Virtualization support is enabled"
fi

# Installing docker
echo "Installing docker"
sudo docker version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Docker already installed"
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
fi

# Check if kubectl is installed
echo "Installing kubectl $KUBECTL_VERSION"
kubectl > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Kubectl is installed"
else
    curl -LO https://storage.googleapis.com/kubernetes-release/release/"$KUBECTL_VERSION"/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    # Add below line in ~/.bashrc for persistence
    # source <(kubectl completion bash)
fi

# Check if VirtualBox is installed
echo "Installing virtualbox $VIRTUALBOX_VERSION"
vboxmanage --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "VirtualBox already installed"
else
    #Add the following line to your /etc/apt/sources.list
    sudo add-apt-repository "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
    sudo apt-get -y update
    sudo apt-get install -y virtualbox-"$VIRTUALBOX_VERSION"
fi

# Check if minikube is installed
echo "Installing minikube $MINIKUBE_VERSION"
minikube > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Minikube already installed"
else
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/"$MINIKUBE_VERSION"/minikube-linux-amd64 && chmod +x minikube
    sudo mkdir -p /usr/local/bin/
    sudo install minikube /usr/local/bin/
    rm minikube

    if [ -n "$LUX_USER" ]; then
      # Copy certifiates
      sudo mkdir -p ~/.minikube/files/etc/ssl/certs
      sudo cp luxoft_root_ca.crt /usr/local/share/ca-certificates/luxoft/luxoft_root_ca.crt
      sudo cp luxoft_root_ca.crt ~/.minikube/files/etc/ssl/certs/luxoft_root_ca.crt

      # Update certificates
      sudo update-ca-certificates
    fi
  fi

echo "Starting minikube"
sudo minikube start


mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/configkubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


