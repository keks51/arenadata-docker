#!/bin/bash

# If master:
# -connect to each segment
# -execute init script on each segment
# -connect to master from segment
#If segment:
# -connect to each segment
#echo "" > /home/gpadmin/.ssh/known_hosts

log() {
  mes=$1
  echo "init_ssh.sh| $mes" | sudo tee -a /proc/1/fd/1
}

connect_master_to_segments() {
  host_to_connect=$1
  s="failed"
  log "MASTER: Connecting to ${host_to_connect}"
  for i in {1..10}; do ssh -o StrictHostKeyChecking=no $host_to_connect < /dev/null && s="success" && break || sleep 1; done
  if [[ "$s" == "success" ]]; then
    log "MASTER: Connected to ${host_to_connect}"

    scp /home/gpadmin/gpconfigs/hostfile_segments "$host_to_connect":/home/gpadmin/gpconfigs/hostfile_segments
    log "MASTER: Copied file /home/gpadmin/gpconfigs/hostfile_segments to ${host_to_connect}"

    (ssh "${host_to_connect}" 'bash /home/gpadmin/init_scripts/init_ssh_old.sh < /dev/null' | sudo tee -a /proc/1/fd/1) < /dev/null
    log "MASTER: Executed init_ssh.sh on ${host_to_connect}"

    ssh "${host_to_connect}" "ssh -o StrictHostKeyChecking=no ${master_hostname} < /dev/null" < /dev/null
    log "MASTER: Connected to ${master_hostname} from ${host_to_connect}"
    return 0
  else
    log "MASTER: Cannot connect to ${host_to_connect}"
    return 1
  fi
}

connect_segment_to_all() {
  segment_hostname=$1
  host_to_connect=$2
  s="failed"
  log "SEGMENT: ${segment_hostname} connecting to ${host_to_connect}"
  for i in {1..10}; do ssh -o StrictHostKeyChecking=no "$host_to_connect" < /dev/null && s="success" && break || sleep 1; done
  if [[ "$s" == "success" ]]; then
    log "SEGMENT: ${segment_hostname} connected to ${host_to_connect}"
  else
    log "SEGMENT: ${segment_hostname} ${host_to_connect}"
    exit 1
  fi
}





if [[ "$1" == "master_node" ]]; then
  master_hostname=$(hostname)
  ssh -o StrictHostKeyChecking=no $master_hostname < /dev/null
  log "MASTER: Added master host_to_connect ${master_hostname} to known_hosts"
  while read host_to_connect || [ -n "$host_to_connect" ]
  do
    res=$(connect_master_to_segments "$host_to_connect")
    if [ "$res" -eq "1" ]; then exit 1; fi
  done < /home/gpadmin/gpconfigs/hostfile_segments
  if [ -n "$STANDBY_HOSTNAME"  ] && [ -n "$STANDBY_PORT"  ]; then
    log "MASTER: Connecting to Standby node"
    res=$(connect_master_to_segments "$STANDBY_HOSTNAME")
    ssh "$STANDBY_HOSTNAME" "ssh -o StrictHostKeyChecking=no ${STANDBY_HOSTNAME} < /dev/null" < /dev/null
    ssh "$STANDBY_HOSTNAME" "ssh -o StrictHostKeyChecking=no ${master_hostname} < /dev/null" < /dev/null
    if [ "$res" -eq "1" ]; then exit 1; fi
  else
    log "MASTER: Standby host_to_connect or port in not configured. Skipping"
  fi
  log "MASTER: All nodes successfully connected"
else
  # executed on segment
  segment_hostname=$(hostname)
  log "SEGMENT: '${segment_hostname}' configuring ssh"
  while read host_to_connect || [ -n "$host_to_connect" ]; do
    connect_segment_to_all "$segment_hostname" "$host_to_connect"
    res=$(connect_segment_to_all "$segment_hostname" "$host_to_connect")
    if [ "$res" -eq "1" ]; then log "failed"; exit 1; fi
  done < /home/gpadmin/gpconfigs/hostfile_segments
  log "SEGMENT: '${segment_hostname}' All nodes successfully connected"
fi
