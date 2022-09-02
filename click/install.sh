#!/bin/sh

ADCM_ADDRESS="http://localhost:8000"
ADCM_ID=1
ADCM_SETTINGS_FILE=adcmconfig.json
BUNDLE_NAME_SSH_COMMON="SSH Common"
HOSTPROVIDER_NAME="HostProvider0"
HOSTS=("ch1" "ch2" "ch3") # host name == host id

#####################
# Prepare containers and get access token
#####################

#echo "stopping ADCM ..."
#docker compose stop
#docker compose rm -f
#echo "ADCM stopped"

#echo "Building node images..."
#docker build -t keks51-centos7 -f Dockerfile .
#echo "ADCM node images ready"

#docker compose up -d

echo "Gettting auth. token"
echo "make sure you specified env variable 'ADCM_USERNAME' and 'ADCM_PASSWORD' without quotes"
while true
do
	token=$(curl --silent --header "Content-Type:application/json" \
		--header "Accept:application/json" \
	 	-X POST \
	 	--data '{"username":"'$ADCM_USERNAME'","password":"'$ADCM_PASSWORD'"}' \
	 	"$ADCM_ADDRESS/api/v1/rbac/token/" \
	 	| jq -r ".token")
	if [[ -n "$token" && "$token" != "null" ]]; then
		break
	else
		echo "."
		sleep 1 
	fi
done
printf "ADCM ( %s ) is UP and token received\n" $ADCM_ADDRESS


#######################
# Configuration part
######################
echo "ADCM configuration..."
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
    	$ADCM_ADDRESS/api/v1/stack/upload/?view=interface 
    curl  --silent \
    	--header "Content-Type:application/json" \
    	--header "application/json, text/plain, */*" \
    	--header "Authorization: Token $token" \
    	-X POST \
    	--data '{"bundle_file":"'$f'"}' \
    	"$ADCM_ADDRESS/api/v1/stack/load/"
done

# Bundles license acceptance
echo "\nAccepting bundle license"
ids=$(curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/bundle/?offset=0" \
	 	| jq -r '.results[] | select(.license=="unaccepted") | .id')
for id in $ids;
do
	#http://localhost:8000/api/v1/stack/bundle/20/license/accept/?view=interface
	curl --silent \
	--header "Content-Type:application/json" \
	--header "Accept:application/json" \
	--header "Authorization: Token $token" \
	-X PUT \
	$ADCM_ADDRESS/api/v1/stack/bundle/$id/license/accept/?view=interface
done
echo "Licenses accepted"

# Getting SSH Common bundle id
sshBundleId=$(curl --silent \
		--header "Content-Type:application/json" \
		--header "Accept:application/json" \
		--header "Authorization: Token $token" \
	 	-X GET \
	 	"$ADCM_ADDRESS/api/v1/stack/bundle/?offset=0" \
	 	| jq --arg name "$BUNDLE_NAME_SSH_COMMON" -r \
	 		'.results[] | select(.name==$name) | .id')

printf "SSH Common bundle id=%s\n" $sshBundleId

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
	--header "Content-Type:application/json" \
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
		"$ADCM_ADDRESS/api/v1/provider/5/host/" \
		| jq -r '.id')
	if [[ "$hostId" == "null" ]]; then
		echo "\nWarning: HOST ALREADY DEFINED, SKIPPING FURTHER HOST CONFIGURATION"
		break
	fi	
	printf "DONE, id=%s\nChanging host configuration..." $hostId	
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
	#echo "DONE\nInstalling health checker"

done