#!/bin/bash

set -e
# SSM currently doesn't have a region variable for SendCommand docs so we pull
# it from the instance metadata server instead
REGION="$(curl http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null|grep region|awk -F\" '{print $4}')"
echo "Region retrieved is: ${REGION}"

# Available on all support platforms except RHEL/CENTOS 6
if [[ -f /etc/os-release ]];
then
  # As per docs values in os-release are considered env
  # variable compatible so this works
  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO="${ID}"
else
  echo "Unknown Distro!"
  exit 1
fi

echo "Distro reported is: ${DISTRO}"

function yum_install_codedeploy() {
  set -e
  yum -q -y update
  yum -y -q install ruby wget
  if [[ -d /home/ec2-user ]]; then
    cd /home/ec2-user
  else
    cd /home/centos
  fi
  wget -q "https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install"
  chmod +x ./install
  ./install auto
}

function apt_get_install_codedeploy() {
  set -e
  export DEBIAN_FRONTEND=noninteractive
  flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get -q update
  if [[ ${VERSION_ID} == "14.04" ]]; then
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get -y -q install ruby2.0 wget
  else
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get -y -q install ruby wget
  fi
  cd /home/ubuntu
  wget -q "https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install"
  chmod +x ./install
  ./install auto
}

if [[ ${DISTRO} == "amzn" || ${DISTRO} == "rhel" || ${DISTRO} == "centos" ]]; then
  set +e
  # First see if the package is installed in the first place
  yum list installed codedeploy-agent
  COMMAND_RC=$?
  if [[ ${COMMAND_RC} != 0 ]]; then
    # It's not installed so pull it down
    yum_install_codedeploy
  fi

  # Check to see if the agent is running and if not start the service
  # Realistically this should be started after install but just to be safe
  set +e
  if [[ $(service codedeploy-agent status) != 0 ]]; then
    # This is so the service starting causing an error should bail out the
    # whole process
    set -e
    service codedeploy-agent start
    exit 0
  else
    # Both the package is installed and the service is running so bail with
    # success
    exit 0
  fi
elif [[ ${DISTRO} == "ubuntu" ]]; then
  set +e
  # First see if the package is installed in the first place
  dpkg -s codedeploy-agent
  COMMAND_RC=$?
  if [[ ${COMMAND_RC} != 0 ]]; then
    # It's not installed so pull it down
    apt_get_install_codedeploy
  fi

  # Check to see if the agent is running and if not start the service
  # Realistically this should be started after install but just to be safe
  set +e
  if [[ $(service codedeploy-agent status) != 0 ]]; then
    # This is so the service starting causing an error should bail out the
    # whole process
    set -e
    service codedeploy-agent start
    exit 0
  else
    # Both the package is installed and the service is running so bail with
    # success
    exit 0
  fi
fi
