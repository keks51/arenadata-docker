# ArenaData QuickMarts installation scripts

docker-deploy.sh and install.sh documentation. Important sections:

1. [Redeployment/Docker](#docker-deploy)
	1. [Privileged mode](#docker-deploy-priv)
	1. [Important notes](#docker-deploy-important)
1. [Cluster installer](#install)
	1. [Important notes](#install-important)

***

## ADCM and Nodes (re)Deployment Scripts

### Docker-compose (docker-deploy.sh) <a name="docker-deploy"></a>

#### Description

Script name: docker-deploy.sh Steps performed by the script:

- stop containers, 
- remove ADCM (ArenaData Cluster Manager) image and settings
- build required images
- start containers

*Note: Script returns 'exit 0' instantly after container start, it's not waiting for full ADCM start.*

#### Dependencies

- docker installed
- docker-compose installed
- privileged mode enabled for docker
- docker-compose.yml and Dockerfile in the same folder

Docker-compose specification used for ADCM and ClickHouse nodes definition. Dockerfile contains all the commands a user could call on the command line to assemble ClickHouse node image.
No user-defined environment variables required.

##### Docker privileged mode <a name="docker-deploy-priv"></a>
Privileged mode required fo ClickHouse containers. Without privileged mode container SystemD services such as 'sshd' will fail to start.

![](readme-img/osx-docker-settings.jpg "Docker Settings OSX")
Config example (OSX):
```
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "default-cgroupns-mode": "host",
  "experimental": false,
  "features": {
    "buildkit": true
  }
}
```
This specific line ```default-cgroupns-mode": "host"``` enables privileged mode.

#### Volumes

Script creates container volumes based on 'docker-compose.yml' definition.
In script itself, volumes/adcm cleaning is hard-coded. So it always removes ADCM cluster configuration.

##### Important notes <a name="docker-deploy-important"></a>

**[[Important]]**: If you want to change volume location, change both 'docker-compose.yml' and 'docker-deploy.sh'

**[Important]** Script does not clean ClickHouse data volume, but you may need to clean it manually if you restart deployment scripts while *decreasing host count*


***

## Cluster installer script <a name="install"></a>
Script name: 'install.sh'. Script waits for ADCM start (no timeout set) and can be started right after ADCM deployment script. 
### Dependencies
	
- Bash (Unix shell)
- GNU Core Utilities or coreutils 
- Additional software
	- curl
	- jq
	- mktemp
	- rename
- Settings Files (JSON) in any location:
	- ADCM Settings file ```-- adcm-config <adcm config>.json```
	- ADQM Settings file ```--adqmdb-config <adqmdb config>.json```
- Bundle files ```--bundles-location <bundles location directory>```	
	- SSH Common Bundle https://store.arenadata.io/#products/arenadata_cluster_manager
	- ADQM Bundle https://store.arenadata.io/#products/arenadata_quickmarts	see "Infrastructure Bundles" section
- Environment Variables
	- ADCM_USERNAME and ADCM_PASSWORD
		<br>```export ADCM_USERNAME=...``` 
		<br>```export ADCM_PASSWORD=...```
		<br>ADCM Default Login and password: https://docs.arenadata.io/adcm/user/quick.html
	- ANSIBLE_USERNAME and ANSIBLE_PASSWORD
		<br>```export ANSIBLE_USERNAME=root```
		<br>```export ANSIBLE_PASSWORD=root```


#### Tested Versions
bash-3.2.57(1)-release, curl-7.79.1, jq-1.6, rename-1.601

### Example and parameters description 

```
./install.sh -a http://localhost:8000 -b bundles -c "ADQM Cluster" -t "ch1 ch2 ch3 ch4" --adcm-config adcmconfig.json --adqmdb-config adqmdbconfig.json --
```
```-a http://localhost:8000``` – define ADCM address, the script will use API from this host

```-b bundles``` – specify directory with bundle files
	```
		$ ls bundles
		adcm_host_ssh_v2.7-1_community.tgz
		adcm_cluster_adqm_v22.3.7.28_arenadata1_b1-1_community.tgz
	```

```-c "ADQM Cluster"``` – tell ADCM the name of the new Cluster

```-t "ch1 ch2 ch3 ch4"``` – tell ADCM target hostnames (Cluster member names)

![](readme-img/adcm2_hosts.png "Host list example")

![](readme-img/adcm2_host_config.png "Host settings example")

```--adcm-config adcmconfig.json``` – configuration JSON file for Global Configuration http://localhost:8000/admin/settings

![](readme-img/adcmconfig.png "ADCM Settings applied from --adcm-config")

```--adqmdb-config adqmdbconfig.json``` - configuration JSON file for ADCM/CLUSTERS/ADQM CLUSTER/SERVICES/ADQMDB

![](readme-img/adqmdbconfig.png "ADQM Settings applied from --adqmdb-config")

### Installation steps description

1. 
Bundle upload from specified bundles directory (-b / --bundles-location).
![](readme-img/adcm0.png "Bundle upload from specified bundles directory")

1. Host provider created.
![](readme-img/adcm1.png "Host provider created")

1. Hosts created (defined by -t / --target-hosts option).
![](readme-img/adcm2_hosts.png "Hosts created")

1. Status checkers installed for all hosts.
![](readme-img/adcm3.png "Status checkers installed for all hosts")

1. Cluster created. Services an hosts added to the cluster.
![](readme-img/adcm4_services.png "Services added to the cluster")
![](readme-img/adcm5_hosts.png "Hosts added to the cluster")

1. Service Components mapped to cluster hosts (all-to-all except for Zookeeper). Zookeeper Cluster requires odd member for cluster voting consensus.
![](readme-img/adcm6_mappings.png "Hosts added to the cluster")

1. Installation starts
![](readme-img/adcm7_installation.png "Installation steps")

1. Installation success
![](readme-img/adcm8_client.png "Installation success")

### Important notes <a name="install-important"></a>

You may need to delete Cluster, HostProvider and Hosts from ADCM if:
	- Cluster name already exists
	- One of the hosts you define in ```-t``` is already part of the cluster

**[Important]** Make sure you have a valid backup of your ADQM DB Data if you modify or reinstall the cluster.