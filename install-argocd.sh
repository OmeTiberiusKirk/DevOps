#!/bin/bash

RUNNER_IP="192.168.122.167"
MASTER_IP="192.168.122.238"
RUNNER_SUBNET="192.168.122.0/24"
ARGOCD_VERSION="v3.3.4"
DIR_PATH="./argo-cd"

if [ ! -d "$DIR_PATH" ]; then
	echo "❌ ไม่พบ Directory: $DIR_PATH"
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm pull argo/argo-cd --untar
fi

cat <<EOF >$DIR_PATH/custom-values.yaml
global:
  # 1. ชี้เป้าให้มาดึงอิมเมจจาก Harbor วงในแทนการออกอินเทอร์เน็ต
  image:
    repository: $RUNNER_IP/argocd/argocd
    tag: "$ARGOCD_VERSION" # ปรับตามเวอร์ชันที่คุณดึงลงมา
  
  # 2. ฝังสะพานไฟ Proxy ไว้ที่นี่ที่เดียว Helm จะกระจายไปให้ repoServer และ controller เองอัตโนมัติ
  env:
    - name: HTTP_PROXY
      value: "http://<RUNNER_IP>:8080"
    - name: HTTPS_PROXY
      value: "http://<RUNNER_IP>:8080"
    - name: NO_PROXY
      # เพิ่มช่วง IP 10.42.0.0/16 และ 10.43.0.0/16 เข้าไปท้ายสุด (คั่นด้วยเครื่องหมายจุลภาค ,)
      value: "kubernetes.default.svc,localhost,127.0.0.1,10.42.0.0/16,10.43.0.0/16"

server:
  # แก้ไขจุดนี้: ใช้ extraArgs เพื่อส่งคำสั่ง --insecure ให้ตัวแอปเปลี่ยนมารันบน HTTP (พอร์ต 8080)
  extraArgs:
    - --insecure

  # การตั้งค่า Probe (ตรวจสอบย่อหน้าเยื้องด้วย Spacebar ให้ดี ห้ามใช้ Tab)
  livenessProbe:
    initialDelaySeconds: 60  # ให้เวลาแอปสตาร์ทเครื่องมากขึ้น
    periodSeconds: 10
  readinessProbe:
    initialDelaySeconds: 40  # ให้เวลาแอปเตรียมความพร้อมก่อนรับ Traffic
    periodSeconds: 10
EOF

# ส่งโฟลเดอร์ Chart ไปที่ Master
scp -r $DIR_PATH ubuntu@$MASTER_IP:/home/ubuntu/
