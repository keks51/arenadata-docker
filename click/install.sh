#!/bin/sh

ADCM_ADDRESS="http://localhost:8000"
ADCM_ID=1
ADCM_SETTINGS_FILE=adcmconfig.json

#####################
# Prepare containers and get access token
#####################

echo "stopping ADCM ..."
docker compose stop
docker compose rm -f
echo "ADCM stopped"

echo "Building node images..."
docker build -t keks51-centos7 -f Dockerfile .
echo "ADCM node images ready"

docker compose up -d

echo "Gettting auth. token"
echo "make sure you specified env variable 'ADCM_USERNAME' and 'ADCM_PASSWORD' without quotes"
while true
do
	token=$(curl --silent --header "Content-Type:application/json" --header "Accept:application/json" -X POST --data '{"username":"'$ADCM_USERNAME'","password":"'$ADCM_PASSWORD'"}' $ADCM_ADDRESS/api/v1/rbac/token/ | jq -r ".token")
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
curl --header "Content-Type:application/json" --header "Accept:application/json" --header "Authorization: Token $token" -X POST --data "$(cat $ADCM_SETTINGS_FILE)" $ADCM_ADDRESS/api/v1/adcm/$ADCM_ID/config/history/\?view\=interface
echo "Setting updated"

cd bundles
for f in *;
do
    printf "uploading bundle ( %s )\n" $f
    curl --header "Authorization: Token $token" --header "Accept-Encoding: gzip,deflate" --header "Accept: application/json, text/plain, */*" --header "Connection: keep-alive" -F file=@$f -X POST $ADCM_ADDRESS/api/v1/stack/upload/?view=interface
    curl --header "Content-Type:application/json" --header "application/json, text/plain, */*" --header "Authorization: Token $token" -X POST --data '{"bundle_file":"'$f'"}' $ADCM_ADDRESS/api/v1/stack/load/?view=interface	    
	
done

