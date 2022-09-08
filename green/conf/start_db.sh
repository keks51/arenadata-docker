#!/bin/bash

log() {
  mes=$1
  echo "$mes" | sudo tee -a /proc/1/fd/1
}

source /usr/local/greenplum-db-6.21.2/greenplum_path.sh

master_data_dir="${CONF__MASTER_DIRECTORY:-/data/master}/gpseg-1"
master_port=${CONF__MASTER_PORT:-5432}
master_hostname=$(hostname)

log "MASTER: Segments are ${SEGMENT_HOSTNAMES}"

if [ -d "$master_data_dir" ]; then
  log "MASTER: Master host data directory ${master_data_dir} already exists. Skipping init step"
  gpstart -a -d "$master_data_dir" | sudo tee -a /proc/1/fd/1
else
  log "MASTER: Master host data directory ${master_data_dir} doesn't exists. Running init script"
  if [ -n "$STANDBY_HOSTNAME"  ] && [ -n "$STANDBY_PORT"  ]; then
    standby_data_dir=${STANDBY_DIRECTORY:-/data/master}
    log "MASTER: Starting Master HOST: ${master_hostname}, PORT: ${master_port}, MASTER DATA DIR: ${master_data_dir}"
    log "MASTER: With Standby Node HOST: ${STANDBY_HOSTNAME}, PORT: ${STANDBY_PORT}, STANDBY DATA DIR: ${standby_data_dir}"
    gpinitsystem -a \
      -c /home/gpadmin/gpconfigs/gpinitsystem_config \
      -h /home/gpadmin/gpconfigs/hostfile_segments \
      -P "$STANDBY_PORT" \
      -s "$STANDBY_HOSTNAME" \
      -S "$standby_data_dir" \
      | sudo tee -a /proc/1/fd/1

  else
    log "MASTER: Starting without standby node. "
    log "MASTER: Starting Master HOST: ${master_hostname} PORT: ${master_port} MASTER DATA DIR: ${master_data_dir}"
    gpinitsystem -a \
           -c /home/gpadmin/gpconfigs/gpinitsystem_config \
           -h /home/gpadmin/gpconfigs/hostfile_segments \
           | sudo tee -a /proc/1/fd/1

  fi
  log "MASTER: Creating default db 'gpadmin'"
  createdb -h $master_hostname -p $master_port gpadmin | sudo tee -a /proc/1/fd/1
fi

log "MASTER: Greenplum Database has started"
