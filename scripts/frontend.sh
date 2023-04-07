#!/bin/bash

DOCKER_IMAGE_NAME="beprayed-app-react"
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="238277034186"
AWS_REPOSITORY_NAME="beprayed-app-react"
AWS_ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${AWS_REPOSITORY_NAME}"

echo "login in erc"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}

echo "pulling newest beprayed-app-react docker image"
docker pull ${AWS_ECR_URI}:latest

echo "stopping docker container"
docker rm -f beprayed-app-react

echo "starting the container with new image"
docker run -p 80:80 --name beprayed-app-react -d ${AWS_ECR_URI}

echo "done"