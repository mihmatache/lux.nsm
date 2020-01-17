#!/bin/bash
#
# Help install git
#
# If on a LUXOFT network, provide with -u <LUXOFT USERNAME> parameter.
#     - You will be prompted to pass the password at runtine
# You will be prompted to enter the sudo password as well



usage="$(basename "$0") Install git on current system: Ubuntu 18.04
  Arguments:

  -l <luxoft username>: Provide this argument if deploying in a LUXOFT environment.
                        This represents you Luxoft account username. You will be prompted for your account passowrd!

  -u <git_usernme>:     Enter GitHub username (mandatory)

  -e <git_email>:       Enter GitHub email address for the provided git username (mandatory)

  -h:                   Shows this hep text
  "


while getopts 'hl:u:e:' option
do
case "${option}"
in
h) echo "$usage"
   exit
   ;;
u) GIT_USERNAME=${OPTARG};;
e) GIT_EMAIL=${OPTARG};;
l) LUX_USER=${OPTARG};;
*)echo 'Unknown argument passed as input. Exiting!'
  exit 1
  ;;
esac
done

if [ -z "$GIT_USERNAME" ]; then
  echo "Git username not given. Aborting."
  exit 1
fi

if [ -z "$GIT_EMAIL" ]; then
  echo "Git email not given. Aborting."
  exit 1
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


# Installing docker
echo "Installing git"
sudo git --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Git is already installed"
else
    sudo apt -y install git
fi

echo "Adding username and email to git config"
git config --global user.name "$GIT_USERNAME"
git config --global user.email "$GIT_EMAIL"

