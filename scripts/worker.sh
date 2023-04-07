#!/bin/bash

# Set variables
AWS_ACCOUNT_ID="238277034186"
CONTAINER_NAME="beprayed-app-worker"
POSTGRES_SECRET_NAME="prod/postgres"
AWS_REGION="us-west-2"
AWS_ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CONTAINER_NAME}"
NATS_HOST="nats://10.0.2.167:4222"

echo "login in erc"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}

echo "pulling newest beprayed-app-worker docker image"
docker pull ${AWS_ECR_URI}:latest

echo "stopping docker container"
docker rm -f "${CONTAINER_NAME}"

POSTGRES_INFO=$(aws secretsmanager get-secret-value --secret-id "${POSTGRES_SECRET_NAME}" --region "${AWS_REGION}" --query SecretString --output text)
DB_PASS=$(echo ${POSTGRES_INFO} | jq -r '.password')
DB_HOST=$(echo ${POSTGRES_INFO} | jq -r '.host')

echo ${DB_HOST}

echo "starting the container with new image"
docker run \
  --name "${CONTAINER_NAME}" \
  -e "DB_PASS"=${DB_PASS} \
  -e "DB_HOST"=${DB_HOST} \
  -e "NATS_HOST"=${NATS_HOST} \
  -d "${AWS_ECR_URI}:latest"

echo "done"