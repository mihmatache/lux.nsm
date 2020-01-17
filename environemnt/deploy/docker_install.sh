#!/bin/bash
#
# Help install a minikube setup
#
# Consider this script an alpha version as not validation for success is present
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine
# You will be prompted to enter the sudo password as well

DEFAULT_DOCKER_VERSION="5:19.03.4~3-0~ubuntu"

usage="$(basename "$0") Install docker on current system: Ubuntu 18.04
  Arguments:

  -u <luxoft username>: Provide this argument if deploying in a LUXOFT environment.
                        This represents you Luxoft account username. You will be prompted for your account passowrd!

  -d <docker version>: Provide this argument to overwrite the default docker version. (Default: $DEFAULT_DOCKER_VERSION)
  "


while getopts 'hu:d:' option
do
case "${option}"
in
h) echo "$usage"
   exit
   ;;
u) LUX_USER=${OPTARG};;
d) DOCKER_VERSION=${OPTARG};;
*)echo 'Unknown argument passed as input. Exiting!'
  exit 1
  ;;
esac
done

# Setting docker version to use
if [ -z "$DOCKER_VERSION" ]; then
  echo "No <docker> version passed. Using default: $DEFAULT_DOCKER_VERSION"
  DOCKER_VERSION="$DEFAULT_DOCKER_VERSION"
else
  echo "Setting <docker> version to: $DOCKER_VERSION"
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

date & echo "Install prerequisite packages"
sudo apt-get -y update
sudo apt-get upgrade -y
sudo apt-get install -y curl
sudo apt-get install -y apt-transport-https
sudo apt-get install -y ca-certificates
sudo apt-get install -y software-properties-common
sudo apt-get install -y gnupg-agent

# Installing docker
echo "Installing docker"
sudo docker version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Docker already installed"
else
     # Install Docker CE
    ## Set up the repository:

    date & echo "Add Docker’s official GPG key"
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    sudo apt-key fingerprint 0EBFCD88
    sudo apt-get update

    date & echo "Add Docker apt repository."
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    date & echo "Install Docker CE."
    sudo apt-get update
    sudo apt-get install -y containerd.io=1.2.10-3
    sudo apt-get install -y  docker-ce="$DOCKER_VERSION-$(lsb_release -cs)"
    sudo apt-get install -y  docker-ce-cli="$DOCKER_VERSION-$(lsb_release -cs)"

    date & echo "Manage docker as non-root user"
    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker

    date & echo "Setup daemon."
    cat > /etc/docker/daemon.json <<EOF
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
    sudo mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml

    # Restart docker.
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker
    sudo systemctl restart containerd
fi

sudo systemctl status docker
