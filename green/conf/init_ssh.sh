#!/bin/bash

# If master:
# -connect to each segment
# -execute init script on each segment
# -connect to master from segment
#If segment:
# -connect to each segment
echo "" > /home/gpadmin/.ssh/known_hosts

connect_master_to_segments() {
  host=$1
  s="failed"
      log "Master: Connecting to ${host}"
      for i in {1..10}; do ssh -o StrictHostKeyChecking=no $host < /dev/null && s="success" && break || sleep 1; done
      if [[ "$s" == "success" ]]; then
        log "Master: Connected to ${host}"

        scp /home/gpadmin/gpconfigs/hostfile_gpinitsystem $host:/home/gpadmin/gpconfigs/hostfile_gpinitsystem
        log "Master: Copied file /home/gpadmin/gpconfigs/hostfile_gpinitsystem to ${host}"

        ssh ${host} 'bash /home/gpadmin/init_ssh.sh < /dev/null' < /dev/null
        log "Master: Executed init_ssh.sh on ${host}"

        ssh ${host} "ssh -o StrictHostKeyChecking=no ${master_hostname} < /dev/null" < /dev/null
        log "Master: Connected to ${master_hostname} from ${host}"
        return 0
      else
        log "Master: Cannot connect to ${host}"
        return 1
      fi
}

connect_segment_to_all() {
  segment_hostname=$1
  host=$2
  s="failed"
      log "Segment: ${segment_hostname} connecting to ${host}"
      for i in {1..10}; do ssh -o StrictHostKeyChecking=no $host < /dev/null && s="success" && break || sleep 1; done
      if [[ "$s" == "success" ]]; then
        log "Segment: ${segment_hostname} connected to ${host}"
      else
        log "Segment: ${segment_hostname} ${host}"
        exit 1
      fi
}

log() {
  mes=$1
  echo "$mes" | sudo tee -a /proc/1/fd/1
}




if [[ "$1" == "master_node" ]]; then
  master_hostname=$(hostname)
  ssh -o StrictHostKeyChecking=no $master_hostname < /dev/null
  log "Master: Added master host ${master_hostname}"
  while read host || [ -n "$host" ]
  do
    res=$(connect_master_to_segments "$host")
    if [ "$res" -eq "1" ]; then exit 1; fi
  done < /home/gpadmin/gpconfigs/hostfile_gpinitsystem
  if [ -n "$STANDBY_HOSTNAME"  ] && [ -n "$STANDBY_PORT"  ]; then
    log "Connecting to Standby node"
    res=$(connect_master_to_segments "$STANDBY_HOSTNAME")
    ssh "$STANDBY_HOSTNAME" "ssh -o StrictHostKeyChecking=no ${STANDBY_HOSTNAME} < /dev/null" < /dev/null
    ssh "$STANDBY_HOSTNAME" "ssh -o StrictHostKeyChecking=no ${master_hostname} < /dev/null" < /dev/null
    if [ "$res" -eq "1" ]; then exit 1; fi
  else
    log "Standby host or port in not configured. Skipping"
  fi
else
  segment_hostname=$(hostname)
  while read host || [ -n "$host" ]; do
    res=$(connect_segment_to_all "$segment_hostname" "$host")
    if [ "$res" -eq "1" ]; then exit 1; fi
  done < /home/gpadmin/gpconfigs/hostfile_gpinitsystem
fi

log "All nodes successfully connected"