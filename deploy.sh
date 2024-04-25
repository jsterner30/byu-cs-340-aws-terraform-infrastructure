#!/bin/bash
current_dir=$(pwd)

cd ./tweeter-shared/
npm i
npm run build
cd "$current_dir"

cd ./tweeter-server/
npm i
npm run build
cd "$current_dir"

rm -rf ./lambda/

mkdir -p ./lambda/layers/deps/nodejs/node_modules/
mkdir -p ./lambda/layers/lambda/

cp -rL ./tweeter-server/node_modules/ ./lambda/layers/deps/nodejs/node_modules/
cp -r ./tweeter-server/dist/ ./lambda/layers/lambda/

mkdir -p ./lambda/zip/deps/
mkdir -p ./lambda/zip/lambda/

cd ./lambda/layers/deps/ && zip -r ../../zip/deps/nodejs.zip ./*
cd "$current_dir"
cd ./lambda/layers/lambda/ && zip -r ../../zip/lambda/nodejs.zip ./*
cd "$current_dir"

cd ./iac/ && terraform init && terraform apply -auto-approve
cd "$current_dir"