#!/usr/bin/env bash
set -Eeuo pipefail

ssh_setup(){
  printf '%b' 'Setting up ssh\t\n'

  REQUIRED_PKG="openssh-server openssh-client"
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed" || true;)
  if [ "" = "$PKG_OK" ]; then
    printf '%b' "Installing $REQUIRED_PKG\t\n"
    apt update && apt install $REQUIRED_PKG -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --allow-downgrades --allow-remove-essential --allow-change-held-packages && rm -rf /var/lib/apt/lists/*
  fi

  echo "root:Docker!" | chpasswd
  usermod --shell /bin/sh root

  if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
    # generate fresh rsa key
    printf '%b' 'generate fresh rsa key\t\n'
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
  fi

  if [ ! -f "/etc/ssh/ssh_host_dsa_key" ]; then
    # generate fresh dsa key
    printf '%b' 'generate fresh dsa key\t\n'
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
  fi

  if [ ! -f "/etc/ssh/ssh_host_ecdsa_key" ]; then
    # generate fresh ecdsa key
    printf '%b' 'generate fresh ecdsa key\t\n'
    ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t dsa
  fi

  if [ ! -f "/etc/ssh/ssh_host_ed25519_key" ]; then
    # generate fresh ed25519 key
    printf '%b' 'generate fresh ed25519 key\t\n'
    ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t dsa
  fi

  #prepare run dir
  if [ ! -d "/var/run/sshd" ]; then
    mkdir -p /var/run/sshd
  fi

  # Get environment variables to show up in SSH session
  eval "$(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)"

  # starting sshd process
  printf '%b' 'Starting sshd process - defaults to port 2222\t\n'
  SSH_PORT=${SSH_PORT:-2222}
  sed -i "s/SSH_PORT/$SSH_PORT/g" /usr/local/etc/sshd_config
  /usr/sbin/sshd -e -f /usr/local/etc/sshd_config
}

