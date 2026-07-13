#!/bin/bash

RUNNER_IP=192.168.122.167

echo "Login Docker ที่ $RUNNER_IP"
docker login https://$RUNNER_IP -u admin

echo "ตรวจสอบ Docker Images"
# Argocd
VERSION="v3.4.5"
IMAGE="quay.io/argoproj/argocd:$VERSION"
echo $IMAGE
if [ -n "$(docker images -q "$IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $IMAGE ในเครื่องนี้"
	docker pull $IMAGE
	docker tag $IMAGE $RUNNER_IP/argocd/argocd:$VERSION
	docker push $RUNNER_IP/argocd/argocd:$VERSION
fi

# Dex
VERSION="v2.45.0"
IMAGE="ghcr.io/dexidp/dex:$VERSION"
if [ -n "$(docker images -q "$IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $IMAGE ในเครื่องนี้"
	docker pull $IMAGE
	docker tag $IMAGE $RUNNER_IP/argocd/dex:$VERSION
	docker push $RUNNER_IP/argocd/dex:$VERSION
fi


# Redis
VERSION="8.2.3-alpine"
IMAGE="public.ecr.aws/docker/library/redis:$VERSION"
if [ -n "$(docker images -q "$IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $IMAGE ในเครื่องนี้"
	docker pull $IMAGE
	docker tag $IMAGE $RUNNER_IP/argocd/redis:$VERSION
	docker push $RUNNER_IP/argocd/redis:$VERSION
fi