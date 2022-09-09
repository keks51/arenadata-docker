#!/bin/bash

#echo "" > /home/gpadmin/.ssh/known_hosts

log() {
  mes=$1
  echo "init_ssh.sh| $mes" | sudo tee -a /proc/1/fd/1
}

source /usr/local/greenplum-db-6.21.2/greenplum_path.sh

user=$(whoami)

log "Configuring passwordless connection between all nodes for user: ${user}"
hosts_str="-h $(hostname)"

while read host_to_connect || [ -n "$host_to_connect" ]
do
  log "Connecting to ${host_to_connect}"
  ssh-copy-id -o StrictHostKeyChecking=no "${user}@${host_to_connect}" | sudo tee -a /proc/1/fd/1
  hosts_str="${hosts_str} -h ${host_to_connect}"
done < /home/gpadmin/gpconfigs/hostfile_segments

if [ -n "$STANDBY_HOSTNAME"  ] && [ -n "$STANDBY_PORT"  ]; then
  log "Connecting to Standby node ${STANDBY_HOSTNAME}"
  ssh-copy-id -o StrictHostKeyChecking=no "${user}@${STANDBY_HOSTNAME}" | sudo tee -a /proc/1/fd/1
  hosts_str="${hosts_str} -h ${STANDBY_HOSTNAME}"
fi

log "Executing: gpssh-exkeys $hosts_str"
gpssh-exkeys $hosts_str | sudo tee -a /proc/1/fd/1

