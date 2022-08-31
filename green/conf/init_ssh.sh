#!/bin/bash

# If master:
# -connect to each segment
# -execute init script on each segment
# -connect to master from segment
#If segment:
# -connect to each segment
echo "" > /home/gpadmin/.ssh/known_hosts

if [[ "$1" == "master_node" ]]; then
  master_hostname=$(hostname)
  ssh -o StrictHostKeyChecking=no $master_hostname < /dev/null
   echo "Master: Added master host ${master_hostname}" | sudo tee -a /proc/1/fd/1

  while read host || [ -n "$host" ]
  do
    s="failed"
    echo " "
    echo "Master: Connecting to ${host}" | sudo tee -a /proc/1/fd/1
    for i in {1..10}; do ssh -o StrictHostKeyChecking=no $host < /dev/null && s="success" && break || sleep 1; done
    if [[ "$s" == "success" ]]; then
      echo "Master: Connected to ${host}" | sudo tee -a /proc/1/fd/1

      scp /home/gpadmin/gpconfigs/hostfile_gpinitsystem $host:/home/gpadmin/gpconfigs/hostfile_gpinitsystem
      echo "Master: Copied file /home/gpadmin/gpconfigs/hostfile_gpinitsystem to ${host}" | sudo tee -a /proc/1/fd/1

      ssh ${host} 'bash /home/gpadmin/init_ssh.sh < /dev/null' < /dev/null
      echo "Master: Executed init_ssh.sh on ${host}" | sudo tee -a /proc/1/fd/1

      ssh ${host} "ssh -o StrictHostKeyChecking=no ${master_hostname} < /dev/null" < /dev/null
      echo "Master: Connected to ${master_hostname} from ${host}" | sudo tee -a /proc/1/fd/1
    else
      echo "Master: Cannot connect to ${host}" | sudo tee -a /proc/1/fd/1
      exit 1
    fi
  done < /home/gpadmin/gpconfigs/hostfile_gpinitsystem
else
  segment_hostname=$(hostname)
  while read host || [ -n "$host" ]
  do
    s="failed"
    echo "Segment: ${segment_hostname} connecting to ${host}" | sudo tee -a /proc/1/fd/1
    for i in {1..10}; do ssh -o StrictHostKeyChecking=no $host < /dev/null && s="success" && break || sleep 1; done
    if [[ "$s" == "success" ]]; then
      echo "Segment: ${segment_hostname} connected to ${host}" | sudo tee -a /proc/1/fd/1
    else
      echo "Segment: ${segment_hostname} ${host}" | sudo tee -a /proc/1/fd/1
      exit 1
    fi
  done < /home/gpadmin/gpconfigs/hostfile_gpinitsystem
fi

echo "All nodes successfully connected" | sudo tee -a /proc/1/fd/1