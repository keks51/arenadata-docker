#!/usr/bin/env sh

echo "Stopping ADCM and node containers ..."
docker compose stop
docker compose rm -f

echo "Removing arenadata/adcm image"
docker image rm arenadata/adcm

echo "Cleaning ADCM volume directory"
# volume directory name specified in docker-compose.yml
rm -rf volume/adcm

echo "Building node images..."
docker build -t keks51-centos7 -f Dockerfile .

echo "Starting ADCM and node containers"
docker compose up -d