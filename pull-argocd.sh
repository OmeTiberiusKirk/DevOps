#!/bin/bash

RUNNER_IP=192.168.122.167
ARGOCD_VERSION="v3.3.4"
ARGOCD_IMAGE="quay.io/argoproj/argocd:$ARGOCD_VERSION"
DEX_VERSION="v2.45.1"
DEX_IMAGE="ghcr.io/dexidp/dex:$DEX_VERSION"
REDIS_VERSION="8.8.0-alpine"
REDIS_IMAGE="redis:$REDIS_VERSION"

echo "Login Docker ที่ $RUNNER_IP"
docker login https://$RUNNER_IP -u admin

echo "ตรวจสอบ Docker Images"
# Argocd
if [ -n "$(docker images -q "$ARGOCD_IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $ARGOCD_IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $ARGOCD_IMAGE ในเครื่องนี้"
	docker pull $ARGOCD_IMAGE
	docker tag $ARGOCD_IMAGE 192.168.122.167/argocd/argocd:$ARGOCD_VERSION
	docker push 192.168.122.167/argocd/argocd:$ARGOCD_VERSION
fi

# Redis
if [ -n "$(docker images -q "$REDIS_IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $REDIS_IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $REDIS_IMAGE ในเครื่องนี้"
	docker pull $REDIS_IMAGE
	docker tag $REDIS_IMAGE 192.168.122.167/argocd/redis:$REDIS_VERSION
	docker push 192.168.122.167/argocd/redis:$REDIS_VERSION
fi

# Dex
if [ -n "$(docker images -q "$DEX_IMAGE" 2>/dev/null)" ]; then
	echo "✅ [SUCCESS] พบ Docker Image: $DEX_IMAGE อยู่บนระบบเรียบร้อยแล้ว!"
else
	echo "❌ [WARNING] ไม่พบ Docker Image: $DEX_IMAGE ในเครื่องนี้"
	docker pull $DEX_IMAGE
	docker tag $DEX_IMAGE 192.168.122.167/argocd/dex:$DEX_VERSION
	docker push 192.168.122.167/argocd/dex:$DEX_VERSION
fi
