#!/usr/bin/env sh

ADCM_SETTINGS_FILE=adcmconfig.json
BUNDLE_NAME_SSH_COMMON="SSH Common"
BUNDLE_NAME_ADQM="ADQM"
HOSTPROVIDER_NAME="HostProvider0"
CLUSTER_NAME="Cluster0"
HOSTS=("ch1" "ch2" "ch3") # host name == host id
SERVICE_NAMES=("adqmdb" "zookeeper")
ADQMDB_SETTINGS_FILE="adqmdbconfig.json"
BUNDLES_LOCATION="$(pwd)/bundles"
PROGRAM_NAME=$(basename $0)
PROGRAM_VERSION="0.1"

set -e

function usage {
	echo "Pre-requisites:"
	echo "1. Set environment variables ADCM_USERNAME, ADCM_PASSWORD, ANSIBLE_USERNAME, ANSIBLE_PASSWORD. Example:"
	echo "    export ADCM_USERNAME=admin"
	echo "2. Make sure dependencies installed: curl, jq, mktemp"
	echo "3. Save bundles into 'bundles' subfolder located next to $PROGRAM_NAME"
	echo "    Bundles required: 'adcm_host_ssh<...>.tgz', 'adcm_cluster_adqm<...>.tgz'"
	echo "4. Make sure ADCM and target installation hosts are up and running"
	echo 
	echo "Usage:"
	echo "$PROGRAM_NAME --arg [value] --"
	echo
	echo "Usage example:"
	echo "$PROGRAM_NAME -a http://localhost:8000 --"
	echo
	echo "Application Arguments:"
	echo "-a, --adcm-address [value] \n    ADCM container address i.e. http://localhost:8000"
	echo "--help                     \n    display this help and exit"
	echo "--version                  \n    show version"
	echo
	echo "Required Arguments (see description above):"
	echo "-a [value] or --adcm-address [value]"
}

function argParseFail {
	echo "Error parsing arguments. Try $PROGRAM_NAME --help"       
	exit 1
}

if [ -z $1 ] 
then
	argParseFail
fi
while true; do     
        case $1 in 
                -a|--adcm-address)
                        ADCM_ADDRESS="$2"; shift; shift; continue
                ;;                                    
                -h|--help)                            
                        usage                         
                        exit 0                        
                ;;                                    
                -v|--version)                                   
                        printf "%s, version %s\n" "$PROGRAM_NAME" "$PROGRAM_VERSION"
                        exit 0                                                      
                ;;                                                                  
                --)                                                                 
                        # no more arguments to parse                                
                        break                                                       
                ;;                                                                  
                *)                                                                  
                        printf "Unknown option %s\n" "$1"                           
                        exit 1                                                      
                ;;                                                                  
        esac                                                                        
done     


#######################
# 0. Self-check
echo "[phase 0] Self-check"
######################

echo "Checking Arguments "
if [[ -z "$ADCM_ADDRESS" ]]; then
	argParseFail
fi

echo "Checking dependencies"
if ! command -v jq &> /dev/null
then
    echo "'jq' could not be found"
    exit
fi
if ! command -v curl &> /dev/null
then
    echo "'curl' could not be found"
    exit
fi
if ! command -v mktemp &> /dev/null
then
    echo "'mktemp' could not be found"
    exit
fi

echo "Checking env. variables"
if [[ -z "$ADCM_USERNAME" ]]; then
	echo "ADCM_USERNAME env. variable is not set"
	exit 1
fi
if [[ -z "$ADCM_PASSWORD" ]]; then
	echo "ADCM_PASSWORD env. variable is not set"
	exit 1
fi
if [[ -z "$ANSIBLE_USERNAME" ]]; then
	echo "ANSIBLE_USERNAME env. variable is not set"
	exit 1
fi
if [[ -z "$ANSIBLE_PASSWORD" ]]; then
	echo "ANSIBLE_PASSWORD env. variable is not set"
	exit 1
fi

printf "Waiting for ADCM / Gettting auth. token (%s)...\n" $ADCM_ADDRESS
while true
do
	token=$(curl --silent --header "Content-Type:application/json" \
		--header "Accept:application/json" \
	 	-X POST \
	 	--data '{"username":"'$ADCM_USERNAME'","password":"'$ADCM_PASSWORD'"}' \
	 	"$ADCM_ADDRESS/api/v1/rbac/token/" \
	 	| jq -r '.token')
	if [[ -n "$token" && "$token" != "null" ]]; then
		break
	else
		echo "."
		sleep 5 
	fi
done

#######################
# 1. ADCM Configuration part
echo "[phase 1] ADCM configuration"
######################

printf "Applying configuration file %s...\n" $ADCM_SETTINGS_FILE
curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "@$ADCM_SETTINGS_FILE" \
	"$ADCM_ADDRESS/api/v1/adcm/1/config/history/" 2>&1 1>/dev/null

printf "Preparing bundles from %s \n" $BUNDLES_LOCATION
WORK_DIR=`mktemp -d`
cp $BUNDLES_LOCATION/* $WORK_DIR
rename 's/[ @\$]/_/g' $WORK_DIR/*
find $WORK_DIR -type f -print0 | while IFS="" read -r -d "" fullFileName
do
	printf "uploading bundle \"%s\"\n" $fullFileName
	curl \
		--header "Authorization: Token $token" \
		--header "Accept: application/json, text/plain, */*" \
		--header "Connection: keep-alive" \
		--header "Content-Type: multipart/form-data" \
		-F file=@"$fullFileName" \
		-X POST \
		"$ADCM_ADDRESS/api/v1/stack/upload/" 
	baseFileName="$(basename -- $fullFileName)"
	printf "\nloading bundle \"%s\"\n" $baseFileName
	curl \
		--header "Content-Type:application/json" \
		--header "application/json, text/plain, */*" \
		--header "Authorization: Token $token" \
		-X POST \
		--data "{\"bundle_file\" : \"$baseFileName\" }" \
		"$ADCM_ADDRESS/api/v1/stack/load/"
done
rm -rf $WORK_DIR

echo "\nAccepting bundle license"
ids=$(curl --silent \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/bundle/?offset=0" \
	 	| jq -r '.results[] | select(.license=="unaccepted") | .id')
for id in $ids;
do
	curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X PUT \
	"$ADCM_ADDRESS/api/v1/stack/bundle/$id/license/accept/"
done


#######################
# 2. Host/Hostprovider Configuration part
echo "[phase 2] Hostprovider and hosts configuration"
######################

# Getting host provider prototype (bundle version-related) id
hostProviderPrototypeId=$(curl --silent \
		--header "Accept: application/json, text/plain, */*" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/provider/?page=0&limit=500" \
	 	| jq -r '.results[0] | .id')

sshBundleId=$(curl --silent \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/bundle/?offset=0" \
	 	| jq --arg name "$BUNDLE_NAME_SSH_COMMON" -r \
	 		'.results[] | select(.name==$name) | .id')

# Creating hostprovider
echo "Creating host provider"
hostProviderJson="{ \
	\"prototype_id\":	\"$hostProviderPrototypeId\", \
	\"name\": 			\"$HOSTPROVIDER_NAME\", \
	\"display_name\": 	\"$BUNDLE_NAME_SSH_COMMON\", \
	\"bundle_id\": 		\"$sshBundleId\" \
}"
echo "Json:"
echo $hostProviderJson
curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "$hostProviderJson" \
	"$ADCM_ADDRESS/api/v1/provider/?view=interface" 2>&1 1>/dev/null

# Getting host provider id
hostProviderId=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
 	"$ADCM_ADDRESS/api/v1/provider/?limit=10&offset=0" \
 	| jq --arg name "$HOSTPROVIDER_NAME" -r \
 		'.results[] | select(.name==$name) | .id')
printf "Host provider ready, id=%s\n" $hostProviderId

# Creating hosts
for host in ${HOSTS[@]};
do
	printf "Creating host \"%s\"\n" $host
	hostJson="{\"fqdn\": \"$host\"}"
	hostId=$(curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
		-X POST \
		--data "$hostJson" \
		"$ADCM_ADDRESS/api/v1/provider/$hostProviderId/host/" \
		| jq -r '.id')
	if [[ "$hostId" == "null" ]]; then
		printf "\nError: host %s already defined, please delete host and restart installation" $hostId
		exit 1
	fi	
	printf "Changing host \"%s\" id=%s configuration\n" $host $hostId	
	hostConfigJson="{ \
		\"config\":{ \
			\"ansible_user\"					:\"$ANSIBLE_USERNAME\", \
			\"ansible_ssh_pass\"				:\"$ANSIBLE_PASSWORD\", \
			\"ansible_ssh_private_key_file\"	:null, \
			\"ansible_host\"					:\"$host\", \
			\"ansible_ssh_port\"				:\"22\", \
			\"ansible_ssh_common_args\"			:\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\", \
			\"ansible_become\"					:true, \
			\"ansible_become_pass\"				:null \
		}, \
		\"attr\":{}
	}"
	curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
		-X POST \
		--data "$hostConfigJson" \
		"$ADCM_ADDRESS/api/v1/host/$hostId/config/history/" 2>&1 1>/dev/null
	echo "Installing health checker"
	actionId=$(curl --silent \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/host/$hostId/action/" \
	 	| jq  -r '.[] | select(.name=="statuschecker") | .id')
	 taskId=$(curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
		-X POST \
		--data "{\"verbose\":false}" \
		"$ADCM_ADDRESS/api/v1/host/$hostId/action/$actionId/run/" \
		| jq -r '.id')
		printf "Status checker installation started, task id=%s...\n" $taskId
	 	while true
		do
			status=$(curl --silent \
			--header "Content-Type:application/json" \
			--header "Accept:application/json" \
			--header "Authorization: Token $token" \
			-X GET \
			"$ADCM_ADDRESS/api/v1/task/$taskId/" \
			| jq -r '.status')
			if [[ -n "$status" && "$status" == "success" ]]; then
				break
			elif [[ -n "$status" && "$status" == "failed" ]]; then
				printf "\nError: host %s health checker installation failed. Task id=%s" $hostId $taskId
				exit 1
			else
				echo "."
				sleep 10 
			fi
		done
done

############
#  3 . Cluster Configuration
echo "[phase 3] Cluster Configuration"
############

# Creating cluster
echo "Installing health checker"
adqmJson=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
 	"$ADCM_ADDRESS/api/v1/stack/cluster/?page=0&limit=500&ordering=-version&display_name=$BUNDLE_NAME_ADQM")
adqmBundleId=$(echo $adqmJson | jq -r '.results[0] | .bundle_id')
adqmPrototypeId=$(echo $adqmJson | jq -r '.results[0] | .id')
# Creating hostprovider
echo "Creating cluster"
hostProviderJson="{ \
	\"prototype_id\":	\"$adqmPrototypeId\", \
	\"name\": 			\"$CLUSTER_NAME\", \
	\"display_name\": 	\"$BUNDLE_NAME_ADQM\", \
	\"bundle_id\": 		\"$adqmBundleId\" \
}"
clusterId=$(curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "$hostProviderJson" \
	"$ADCM_ADDRESS/api/v1/cluster/" \
	| jq -r '.id')
if [[ "$clusterId" == "null" ]]; then
	printf "\nError: cluster %s already defined. Please delete the cluster and restart installation" $clusterId
	exit 1
else
	printf "Cluster created id=%s\n" $clusterId		
fi		

# Assign Services to Cluster
echo "Assigning services to the cluster..."
servicesJson=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/serviceprototype/")
for serviceName in ${SERVICE_NAMES[@]};
do  
	servicePrototypeId=$(echo $servicesJson | jq --arg name "$serviceName" -r '.[] | select(.name==$name) | .id')
	curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "{\"prototype_id\":$servicePrototypeId}" \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/service/" 2>&1 1>/dev/null
done
echo "Configuring ADQMDB cluster service"

adqmdbClusterServiceId=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
 	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/service/?limit=10&offset=0" \
 	| jq  -r '.results[] | select(.name=="adqmdb") | .id')
printf "Applying configuration file %s to cluster service id=%s\n" $ADQMDB_SETTINGS_FILE $adqmdbClusterServiceId
curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "@$ADQMDB_SETTINGS_FILE" \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/service/$adqmdbClusterServiceId/config/history/" 2>&1 1>/dev/null
echo "Adding hosts to the cluster"
hostIds=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
	"$ADCM_ADDRESS/api/v1/host/?limit=10&page=0&cluster_is_null=true&offset=0&status=" \
 	| jq -r '.results[] | .id')
for hostId in ${hostIds[@]};
do
	printf "Adding host with id=%s to cluster $clusterId\n" $hostId
	curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "{\"host_id\":$hostId}" \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/host/" 2>&1 1>/dev/null
done
echo "Mapping components to cluster hosts"
sleep 1
hostComponentJson=$(curl --silent \
	--header "Accept:application/json, text/plain, */*" \
	--header "Authorization: Token $token" \
 	-X GET \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/hostcomponent/?view=interface")
componentIds=($(echo $hostComponentJson | jq -r '.component | .[].id'))
serviceIds=($(echo $hostComponentJson | jq -r '.component | .[].service_id'))
hostIds=($(echo $hostComponentJson | jq -r '.host | .[].id'))
hcJsonObjectsArray=()
for i in 0 1 2
do
	componentId=${componentIds[i]}
	serviceId=${serviceIds[i]}
	for hostId in ${hostIds[@]};
	do
		hcJsonObjectsArray+=("{\"host_id\":$hostId, \"service_id\":$serviceId, \"component_id\":$componentId}")
	done
done
hcJsonObjectsString=$(IFS=,\n;printf  "%s" "${hcJsonObjectsArray[*]}")
mappingJson="{
  \"cluster_id\": ${clusterId},
  \"hc\": [
   	${hcJsonObjectsString}
  ]
}"
curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "$mappingJson" \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/hostcomponent/" 2>&1 1>/dev/null

############
#  4 . Cluster Installation
echo "[phase 4] Cluster Installation"
############
actionId=$(curl --silent \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
 	-X GET \
 	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/action/" \
 	| jq  -r '.[] | select(.name=="install") | .id')
taskId=$(curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "{\"verbose\":false}" \
	"$ADCM_ADDRESS/api/v1/cluster/$clusterId/action/$actionId/run/" \
	| jq -r '.id')
	echo "Cluster installation started, task id=$taskId"	
 	while true
	do
		status=$(curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
		-X GET \
		"$ADCM_ADDRESS/api/v1/task/$taskId/" \
		| jq -r '.status')
		if [[ -n "$status" && "$status" == "success" ]]; then
			echo "Installation Completed"
			exit 0
		elif [[ -n "$status" && "$status" == "failed" ]]; then
			echo "Installation Failed"
			exit 1
		else
			echo "."
			sleep 10 
		fi
	done