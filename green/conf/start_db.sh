#!/bin/bash

source /usr/local/greenplum-db-6.21.2/greenplum_path.sh
host_data_dir="/data/master/gpseg-1"
master_hostname=$(hostname)

if [ -d "$host_data_dir" ]; then
  echo "Master host data directory ${host_data_dir} already exists. Skipping init step" | sudo tee -a /proc/1/fd/1
  gpstart -a -d "$host_data_dir" | sudo tee -a /proc/1/fd/1
else
  echo "Master host data directory ${host_data_dir} doesn't exists. Running init script" | sudo tee -a /proc/1/fd/1
  gpinitsystem -a -c /home/gpadmin/gpconfigs/gpinitsystem_config -h /home/gpadmin/gpconfigs/hostfile_gpinitsystem | sudo tee -a /proc/1/fd/1

  master_port=${CONF__MASTER_PORT:-5432}
  echo "Creating default db 'gpadmin'" | sudo tee -a /proc/1/fd/1
  createdb -h $master_hostname -p $master_port gpadmin
fi

echo "Greenplum Database is started" | sudo tee -a /proc/1/fd/1
