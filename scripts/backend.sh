#!/bin/bash

# Set variables
AWS_ACCOUNT_ID="238277034186"
CONTAINER_NAME="beprayed-app-go"
POSTGRES_SECRET_NAME="prod/postgres"
NEO4J_SECRET_NAME="prod/neo4j"
CRYPTOR_SECRET_NAME="prod/cryptor-key"
AWS_REGION="us-west-2"
AWS_ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CONTAINER_NAME}"
GOOGLE_CLIENT_ID="1069269020210-ugrjd7pb46q89ipljo65brfn6hma60l7.apps.googleusercontent.com"
NEO4J_HOST="bolt://10.0.2.167:7687"
NATS_HOST="nats://10.0.2.167:4222"
REDIS_HOST="10.0.2.167:6379"

echo "login in erc"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}

echo "pulling newest beprayed-app-go docker image"
docker pull ${AWS_ECR_URI}:latest

echo "stopping docker container"
docker rm -f "${CONTAINER_NAME}"

POSTGRES_INFO=$(aws secretsmanager get-secret-value --secret-id "${POSTGRES_SECRET_NAME}" --region "${AWS_REGION}" --query SecretString --output text)
DB_PASS=$(echo ${POSTGRES_INFO} | jq -r '.password')
DB_HOST=$(echo ${POSTGRES_INFO} | jq -r '.host')
NEO4J_PASS=$(aws secretsmanager get-secret-value --secret-id "${NEO4J_SECRET_NAME}" --region "${AWS_REGION}" --query SecretString --output text | jq -r '."prod-neo4j-password"')

echo ${POSTGRES_INFO}
echo ${DB_HOST}
echo ${NEO4J_PASS}

FILE_PATH="/home/ubuntu/beprayed.log"

if [ ! -f "$FILE_PATH" ]; then
  touch "$FILE_PATH"
  chmod 664 "$FILE_PATH"
fi

echo "starting the container with new image"
docker run -p 9000:9000 -p 8080:8080 \
  --name "${CONTAINER_NAME}" \
  -e "DB_PASS=${DB_PASS}" \
  -e "DB_HOST=${DB_HOST}" \
  -e "NEO4J_HOST=${NEO4J_HOST}" \
  -e "NEO4J_PASS=${NEO4J_PASS}" \
  -e "NATS_HOST=${NATS_HOST}" \
  -e "REDIS_HOST=${REDIS_HOST}" \
  -e "GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}" \
  -e "CRYPTOR_SECRET_NAME=${CRYPTOR_SECRET_NAME}" \
  -e "AWS_REGION=${AWS_REGION}" \
  -v ~/.aws:/root/.aws \
  -v ~/beprayed.log:/root/beprayed.log \
  -d "${AWS_ECR_URI}:latest"

echo "done"