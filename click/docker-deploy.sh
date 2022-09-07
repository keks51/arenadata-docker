#!/bin/sh

echo "Stopping ADCM and node containers ..."
docker compose stop
docker compose rm -f

echo "Cleaning ADCM volume directory"
rm -rf volume

echo "Building node images..."
docker build -t keks51-centos7 -f Dockerfile .

echo "Starting ADCM and node containers"
docker compose up -d