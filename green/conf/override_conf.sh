#!/bin/bash

conf_file="/home/gpadmin/gpconfigs/gpinitsystem_config"

echo "Overriding variables..." | sudo tee -a /proc/1/fd/1
while IFS='=' read -r -d '' conf_k v; do
    if [[ $conf_k == CONF__* ]]
    then
      k=$(echo "${conf_k//CONF__/}")
      echo "${k}"

      echo "Applying ${k}=${v}" | sudo tee -a /proc/1/fd/1
      if [[ $k == "DATA_DIRECTORY" ]]; then
        sed -i "/^declare -a DATA_DIRECTORY=/c\declare -a DATA_DIRECTORY=${v}" "$conf_file"
        elif [[ $k == "MIRROR_DATA_DIRECTORY" ]]; then
          sed -i "/^#declare -a MIRROR_DATA_DIRECTORY=/c\declare -a MIRROR_DATA_DIRECTORY=${v}" "$conf_file"
          else
            if grep -q "#${k}=" "$conf_file"; then
              sed -i "/#${k}=/c\\${k}=${v}" "$conf_file"
            else
              sed -i "/^${k}=/c\\${k}=${v}" "$conf_file"
            fi
      fi
    fi
done < <(env -0)
