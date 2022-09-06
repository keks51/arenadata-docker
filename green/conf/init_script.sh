#!/bin/bash

# setting env variable from parent process
for e in $(tr "\000" "\n" < /proc/1/environ); do
        eval "export $e"
done

mkdir -p /data/primary
mkdir -p /data/mirror
mkdir -p /data/master
chown -R gpadmin:gpadmin /data/*

echo "\nSegments are ${SEGMENT_HOSTNAMES}" | sudo tee -a /proc/1/fd/1
echo ${SEGMENT_HOSTNAMES} | sed "s/,/\n/g" > /home/gpadmin/gpconfigs/hostfile_gpinitsystem

echo "\nOverriding conf with env variables" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/override_conf.sh

echo "\nConfiguring ssh connections" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/init_ssh.sh "master_node"

echo "\nStarting db" | sudo tee -a /proc/1/fd/1
su gpadmin -s /home/gpadmin/start_db.sh


