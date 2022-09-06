#!/bin/sh

ADCM_ADDRESS="http://localhost:8000"
ADCM_ID=1
ADCM_SETTINGS_FILE=adcmconfig.json
BUNDLE_NAME_SSH_COMMON="SSH Common"
BUNDLE_NAME_ADQM="ADQM"
HOSTPROVIDER_NAME="HostProvider0"
CLUSTER_NAME="Cluster0"
HOSTS=("ch1" "ch2" "ch3") # host name == host id
SERVICE_NAMES=("adqmdb" "zookeeper")
ADQMDB_SETTINGS_FILE="adqmdbconfig.json"

# #####################
# 1. Prepare containers and get access token
echo "[phase 1] System restart, waiting for token"
# #####################

echo "stopping ADCM and nodes ..."
docker compose stop
docker compose rm -f
echo "ADCM and nodes stopped"

echo "Building node images..."
docker build -t keks51-centos7 -f Dockerfile .
echo "ADCM node images ready"

docker compose up -d

echo "Gettting auth. token"
echo "make sure you specified env variable 'ADCM_USERNAME' and 'ADCM_PASSWORD' without quotes"
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
		sleep 1 
	fi
done
printf "ADCM ( %s ) is UP and token received\n" $ADCM_ADDRESS

#######################
# 2. ADCM Configuration part
echo "[phase 2] ADCM configuration"
######################
printf "Applying configuration file %s\n" $ADCM_SETTINGS_FILE
curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X POST \
	--data "@$ADCM_SETTINGS_FILE" \
	"$ADCM_ADDRESS/api/v1/adcm/$ADCM_ID/config/history/" 2>&1 1>/dev/null
echo "Setting updated"

# Bundles upload

cd bundles

for f in *;
do
    printf "uploading bundle ( %s )\n" $f
    curl  --silent \
    	--header "Authorization: Token $token" \
    	--header "Accept-Encoding: gzip,deflate" \
    	--header "Accept: application/json, text/plain, */*" \
    	--header "Connection: keep-alive" \
    	-F file=@$f \
    	-X POST \
    	"$ADCM_ADDRESS/api/v1/stack/upload/" 2>&1 1>/dev/null
    curl  --silent \
    	--header "Content-Type:application/json" \
    	--header "application/json, text/plain, */*" \
    	--header "Authorization: Token $token" \
    	-X POST \
    	--data '{"bundle_file":"'$f'"}' \
    	"$ADCM_ADDRESS/api/v1/stack/load/" 2>&1 1>/dev/null
done

# Bundles license acceptance
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

# Getting SSH Common bundle id
sshBundleId=$(curl --silent \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/bundle/?offset=0" \
	 	| jq --arg name "$BUNDLE_NAME_SSH_COMMON" -r \
	 		'.results[] | select(.name==$name) | .id')

printf "SSH Common bundle id=%s\n" $sshBundleId


#######################
# 2. Host/Hostprovider Configuration part
echo "[phase 3] Hostprovider and hosts configuration"
######################

# Getting host provider prototype (bundle version-related) id
hostProviderPrototypeId=$(curl --silent \
		--header "Accept: application/json, text/plain, */*" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/provider/?page=0&limit=500" \
	 	| jq -r '.results[] | select(.id=98) | .id')
printf "Prototype id=%s)\n" $hostProviderPrototypeId

# Creating hostprovider
echo "Creating host provider"
hostProviderJson="{ \
	\"prototype_id\":	\"$hostProviderPrototypeId\", \
	\"name\": 			\"$HOSTPROVIDER_NAME\", \
	\"display_name\": 	\"$BUNDLE_NAME_SSH_COMMON\", \
	\"bundle_id\": 		\"$sshBundleId\" \
}"
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
echo "make sure you specified env variable 'ANSIBLE_USERNAME' and 'ANSIBLE_PASSWORD' without quotes"
for host in ${HOSTS[@]};
do
	printf "Creating host, name/hostname=%s... " $host
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
		# if hostId is null, other host-related actions are non-functional
		# possible solution is to get host list and not rely on hostId from method above
		echo "\nWarning: HOST ALREADY DEFINED, delete host and restart"
		break
	fi	
	printf "Host created with id=%s\nChanging host configuration..." $hostId	
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
		echo "Status checker installation started, task id=$taskId"	
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
			else
				echo "."
				sleep 10 
			fi
		done
done

############
#  4 . Cluster Configuration
echo "[phase 4] Cluster Configuration"
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
	# if clusterId is null, other host-related actions are non-functional
	# possible solution is to get host list and not rely on clusterId from method above
	echo "\nWarning: Cluster ALREADY DEFINED, please delete cluster and restart"
 		break
else
	printf "Cluster created id=%s)\n" $clusterId		
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

cd ..

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
#  5 . Cluster Installation
echo "[phase 5] Cluster Installation"
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
			break
		elif [[ -n "$status" && "$status" == "failed" ]]; then
			echo "Installation Failed"
			break
		else
			echo "."
			sleep 10 
		fi
	done