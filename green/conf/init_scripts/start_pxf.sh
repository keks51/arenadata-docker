#!/bin/bash

log() {
  mes=$1
  echo "start_pxf.sh| $mes" | sudo tee -a /proc/1/fd/1
}


pxf_data_dir=/data/pxf-base
create_extension=true

if [ -d "$pxf_data_dir" ] && [ "$(ls -A $pxf_data_dir)" ]; then
  log "MASTER: PXF  ${pxf_data_dir} not empty. Skipping prepare step"
  create_extension=false
else
  log "MASTER: Preparing PXF"
	pxf cluster prepare | sudo tee -a /proc/1/fd/1
	log "MASTER: Registering PXF"
	pxf cluster register | sudo tee -a /proc/1/fd/1
fi

sudo su root -s /home/gpadmin/init_scripts/add_pxf_libs.sh

log "MASTER: Starting PXF"
pxf cluster sync | sudo tee -a /proc/1/fd/1
pxf cluster start | sudo tee -a /proc/1/fd/1

log "MASTER: PXF successfully started"

if "$create_extension" ; then
  source /usr/local/greenplum-db-6.21.2/greenplum_path.sh
  log "Adding PXF extension"
  psql -c "CREATE EXTENSION pxf;" | sudo tee -a /proc/1/fd/1
  log "PXF extension was successfully registered"
else
  log "PXF extension exists. Skipping adding pxf extension"
fi
