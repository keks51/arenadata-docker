#!/bin/bash

log() {
  mes=$1
  echo "$mes" | sudo tee -a /proc/1/fd/1
}



master_hostname=$(hostname)
master_data_dir="${CONF__MASTER_DIRECTORY:-/data/master}"
master_ip=$(grep "$master_hostname" /etc/hosts | awk '{ print $1 }')

log "Replacing ip addresses in pg_hba.conf with hostnames"

log "Master hostname: $master_hostname  ip: $master_ip"
escaped_master_ip="$(echo "$master_ip" | sed "s/\./\\\\./g")"
sed -i $"s/${escaped_master_ip}\/32/$master_hostname/g" "${master_data_dir}/gpseg-1/pg_hba.conf"

if [ -n "$STANDBY_HOSTNAME"  ] && [ -n "$STANDBY_PORT"  ]; then
  standby_host="$STANDBY_HOSTNAME"
  standby_ip=$(ping -c 1 -w 1 "$standby_host" | grep "bytes from" | sed 's/^.*(\(.*\)).*$/\1/')
  standby_data_dir="${STANDBY_DIRECTORY:-/data/master}"
  log "Standby hostname: $standby_host  ip: $standby_ip"
  escaped_standby_ip="$(echo "$standby_ip" | sed "s/\./\\\\./g")"
  sed -i $"s/${escaped_standby_ip}\/32/$standby_host/g" "${master_data_dir}/gpseg-1/pg_hba.conf"

  ssh_command1="sed -i $\"s/${escaped_master_ip}\/32/$master_hostname/g\" \"${standby_data_dir}/pg_hba.conf\""
  ssh_command2="sed -i $\"s/${escaped_standby_ip}\/32/$standby_host/g\" \"${standby_data_dir}/pg_hba.conf\""
  ssh $standby_host "\$(""$ssh_command1"") < /dev/null"
  ssh $standby_host "\$(""$ssh_command2"") < /dev/null"
else
  log "Skipping standby pg_hba.conf"
fi
