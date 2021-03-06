#!/bin/bash

distro=""

function add_ntp_entry() {
  if [[ -r "/etc/ntp.conf" ]]; then
    sed -e '/^pool/ s/^/#/' -i /etc/ntp.conf
    sed -e '/^server/ s/^/#/' -e '/^#.*server\s*169\.254\.169\.123\s*prefer\s*iburst/ s/^#//' -i /etc/ntp.conf
    # shellcheck disable=SC2016
    sed '/^server\s*169\.254\.169\.123/{h;s/^server\s*169\.254\.169\.123\s*.*/server 169.254.169.123 prefer iburst/};${x;/^$/{s//server 169.254.169.123 prefer iburst/;H};x}' -i /etc/ntp.conf
    return 0
  else
    echo "/etc/ntp.conf not found. verify that ntp is installed"
    return 1
  fi
}

function add_chrony_entry() {
  if [[ ${distro} == "ubuntu" ]]; then
    if [[ -r "/etc/chrony/chrony.conf" ]]; then
      sed -e '/^pool/ s/^/#/' -i /etc/chrony/chrony.conf
      sed -e '/^server/ s/^/#/' -e '/^#.*server\s*169\.254\.169\.123\s*prefer\s*iburst/ s/^#//' -i /etc/chrony/chrony.conf
      # shellcheck disable=SC2016
      sed '/^server\s*169\.254\.169\.123/{h;s/^server\s*169\.254\.169\.123\s*.*/server 169.254.169.123 prefer iburst/};${x;/^$/{s//server 169.254.169.123 prefer iburst/;H};x}' -i /etc/chrony/chrony.conf
      return 0
    else
      echo "/etc/chrony/chrony.conf not found. verify that chrony is installed"
      return 1
    fi
  else
    if [[ -r "/etc/chrony.conf" ]]; then
      sed -e '/^pool/ s/^/#/' -i /etc/chrony.conf
      sed -e '/^server/ s/^/#/' -e '/^#.*server\s*169\.254\.169\.123\s*prefer\s*iburst/ s/^#//' -i /etc/chrony.conf
      # shellcheck disable=SC2016
      sed '/^server\s*169\.254\.169\.123/{h;s/^server\s*169\.254\.169\.123\s*.*/server 169.254.169.123 prefer iburst/};${x;/^$/{s//server 169.254.169.123 prefer iburst/;H};x}' -i /etc/chrony.conf
      grep -q '^1' /etc/chrony.keys || sed -e '0,/^#1\s*.*/ s/^#//' -i /etc/chrony.keys
      return 0
    else
      echo "/etc/chrony.conf not found. verify that chrony is installed"
      return 1
    fi
  fi
}

function restart_ntp() {
  systemctl=$( command -v systemctl )
  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    if [[ ${systemctl} ]]; then
      systemctl restart ntpd
    else
      service ntpd restart
    fi
  elif [[ ${distro} == "ubuntu" ]]; then
    if [[ ${systemctl} ]]; then
      systemctl restart ntp
    else
      service ntp restart
    fi
  fi
}

function restart_chrony() {
  systemctl=$( command -v systemctl )

  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    if [[ ${systemctl} ]]; then
      systemctl enable chronyd
      systemctl restart chronyd
    else
      chkconfig chronyd on
      service chronyd restart
    fi
  elif [[ ${distro} == "ubuntu" ]]; then
    if [[ ${systemctl} ]]; then
      systemctl enable chrony
      systemctl restart chrony
    else
      service chrony restart
    fi
  fi
}

function install_chrony() {
  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    yum install -y -q chrony
    return 0
  elif [[ ${distro} == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get install -y --quiet chrony
    return 0
  else
    return 1
  fi
}

function install_ntp() {
  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    yum install -y -q ntp
    return 0
  elif [[ ${distro} == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get install -y --quiet ntp
    return 0
  else
    return 1
  fi
}

function remove_ntp() {
  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    yum -y remove ntp -y -q
    return 0
  elif [[ ${distro} == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get remove ntp -y -q=2
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get purge ntp -q=2
    return 0
  else
    return 1
  fi
}

function remove_chrony() {
  if [[ ${distro} == "rhel" || ${distro} == "centos" || ${distro} == "amzn" ]]; then
    yum -y remove chrony -y -q
    return 0
  elif [[ ${distro} == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get remove chrony -y -q=2
    flock --timeout 60 --exclusive --close /var/lib/dpkg/lock apt-get purge chrony -q=2
    return 0
  else
    return 1
  fi
}

get_distro() {
  # Available on all support platforms except RHEL/CENTOS 6
  if [[ -f /etc/os-release ]]; then
    # As per docs values in os-release are considered env
    # variable compatible so this works
    # shellcheck disable=SC1091
    source /etc/os-release
    distro="${ID}"
  elif [[ -f /etc/redhat-release ]]; then
    # This is what you'll hit for RHEL/CENTOS 6
    if grep -q -s "centos" /etc/redhat-release; then
      distro="centos"
    else
      distro="rhel"
    fi
  else
    return 1
  fi
}

preferred_time_client="{{PreferredTimeClient}}"


if ! get_distro; then
  echo "Distro unrecognized"
  exit 1
fi

if [[ ${preferred_time_client} == "ntp" ]]; then
  echo -e "Removing chrony..."
  remove_chrony
  echo -e "Installing ntp (Suppressed output)..."
  install_ntp
  if (( $? == 1 )); then
    echo -e "Error installing ntp"
  fi
  echo -e "Modifying ntp configuration..."
  add_ntp_entry
  if (( $? == 1 )); then
    echo -e "Error modifying ntp configuration"
  fi
  echo -e "Restarting ntp..."
  restart_ntp
  if (( $? == 1 )); then
    echo -e "Error restarting ntp"
  fi
  sleep 5
  echo -e "NTP status"
  ntpq -p
  exit 0
fi

if [[ ${preferred_time_client} == "chrony" ]]; then
  echo -e "Removing ntp..."
  remove_ntp
  echo -e "Installing chrony (suppressed output)..."
  install_chrony
  if (( $? == 1 )); then
    echo -e "Error installing chrony"
  fi
  echo -e "Modifying chrony configuration"
  add_chrony_entry
  if (( $? == 1 )); then
    echo -e "Error modifying chrony configuration"
  fi
  echo -e "Restarting chrony..."
  restart_chrony
  if (( $? == 1 )); then
    echo -e "Error restarting chrony"
  fi
  sleep 5
  echo -e "Chrony status"
  chronyc tracking
  exit 0
fi
