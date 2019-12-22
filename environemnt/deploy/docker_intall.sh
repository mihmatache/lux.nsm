#!/bin/bash
#
# Help install a minikube setup
#
# Consider this script an alpha version as not validation for success is present
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine
# You will be prompted to enter the sudo password as well

usage="$(basename "$0") Install docker on current system: Ubuntu 18.04
  Arguments:

  -u <luxoft username>: Provide this argument if deploying in a LUXOFT environment.
                        This represents you Luxoft account username. You will be prompted for your account passowrd!
  "


while getopts 'hu:' option
do
case "${option}"
in
h) echo "$usage"
   exit
   ;;
u) LUX_USER=${OPTARG};;
*)echo 'Unknown argument passed as input. Exiting!'
  exit 1
  ;;
esac
done

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

# Installing docker
echo "Installing docker"
sudo docker version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Docker already installed"
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt -y update
    apt-cache policy docker-ce
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
fi

sudo systemctl status docker


