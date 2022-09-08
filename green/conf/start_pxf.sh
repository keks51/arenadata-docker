#!/bin/bash

log() {
  mes=$1
  echo "$mes" | sudo tee -a /proc/1/fd/1
}


pxf_data_dir=/data/pxf-base
if [ -d "$pxf_data_dir" ] && [ "$(ls -A $pxf_data_dir)" ]; then
  log "MASTER: PXF  ${pxf_data_dir} not empty. Skipping prepare step"
  log "MASTER: Starting PXF"
  pxf cluster start | sudo tee -a /proc/1/fd/1
else
  log "MASTER: Preparing PXF"
	pxf cluster prepare | sudo tee -a /proc/1/fd/1
	log "MASTER: Registering PXF"
	pxf cluster register | sudo tee -a /proc/1/fd/1
	log "MASTER: Starting PXF"
	pxf cluster start | sudo tee -a /proc/1/fd/1
fi

log "MASTER: PXF successfully started"
