#!/bin/bash

log() {
  mes=$1
  echo "add_pxf_libs.sh| $mes" | sudo tee -a /proc/1/fd/1
}


pxf_data_dir_lib=/data/pxf-base/lib
pxf_data_dir_servers=/data/pxf-base/servers

load_libs_servers() {
  load_libs_from=$1/lib
  log "Looking for libs in path $load_libs_from"
  if [ "$(ls -A $load_libs_from)" ]; then
   for dir in ${load_libs_from}/*/
   do
     lib_name=$(basename "$dir")
     log "Adding Lib $lib_name"
     lib_path=$pxf_data_dir_lib/$lib_name
     if [ -d "$lib_path" ]; then
       log "Lib $lib_name already exists in $pxf_data_dir_lib. Skipping"
     else
       cp -r "$dir" $pxf_data_dir_lib
       log "Lib $lib_name was added to $pxf_data_dir_lib"
     fi
   done
  else
   log "Dir $load_libs_from is empty"
  fi

  load_servers_from=$1/servers
  log "Looking for servers in path $load_servers_from"
  if [ "$(ls -A $load_servers_from)" ]; then
    for dir in ${load_servers_from}/*/
    do
      server_name=$(basename $dir)
      log "Adding Server $server_name"
      server_path=$pxf_data_dir_servers/$server_name
      if [ -d "$server_path" ]; then
        log "Server $server_name already exists $pxf_data_dir_servers. Skipping"
      else
        cp -r "$dir" $pxf_data_dir_servers
        log "Server $server_name was added to $pxf_data_dir_servers"
      fi
    done
  else
    log "Dir $load_servers_from is empty"
  fi
  chown -R gpadmin:gpadmin $pxf_data_dir_lib
  chown -R gpadmin:gpadmin $pxf_data_dir_servers
}

log "Loading system libs and servers"
load_libs_servers "/home/gpadmin/pxf"

log "Loading external libs and servers"
load_libs_servers "/data/extra_pxf"
