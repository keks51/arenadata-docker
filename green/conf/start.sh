#!/bin/bash

# setting env variable from parent process
for e in $(tr "\000" "\n" < /proc/1/environ); do
        eval "export $e"
done

mkdir -p /data/primary
mkdir -p /data/mirror
mkdir -p /data/master
chown -R gpadmin:gpadmin /data/*

echo "MASTER: Segments are ${SEGMENT_HOSTNAMES}" | sudo tee -a /proc/1/fd/1
echo "${SEGMENT_HOSTNAMES}" | sed "s/,/\n/g" > /home/gpadmin/gpconfigs/hostfile_segments

echo "MASTER: Overriding greenplum conf with env variables" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/init_scripts/override_conf.sh

echo "MASTER: Configuring ssh connections" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/init_scripts/init_ssh.sh

echo "MASTER: Starting db" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/init_scripts/start_db.sh

echo "MASTER: Replacing ip addresses in pg_hba.conf" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/init_scripts/replace_pg_hba.sh

if [[ $START_PXF == "true" ]]; then
  echo "MASTER: Starting PXF server on all nodes" | sudo tee -a /proc/1/fd/1
  su gpadmin -s /home/gpadmin/init_scripts/start_pxf.sh "master_node"
else
  echo "MASTER: Skipping PXF" | sudo tee -a /proc/1/fd/1
fi

echo "MASTER: start script successfully finished" | sudo tee -a /proc/1/fd/1
