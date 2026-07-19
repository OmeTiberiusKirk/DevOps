ยินดีครับ การเปลี่ยนจาก GitHub Actions มาใช้ **GitLab** (ไม่ว่าจะเป็น GitLab.com แบบ Cloud หรือ GitLab SaaS/Self-managed) ในสถาปัตยกรรมเครือข่ายแบบนี้ สามารถทำได้ง่ายและลงตัวมากครับ เพราะเครื่องมือของ GitLab ออกแบบมาให้รองรับการทำงานแบบนี้ได้อย่างมีประสิทธิภาพ

นี่คือการปรับเปลี่ยนสถาปัตยกรรมและเวิร์กโฟลว์เมื่อเปลี่ยนมาใช้ **GitLab** ครับ

---

## 🏗️ ภาพรวมการทำงานใหม่ (Conceptual Flow with GitLab)

1. **GitLab** ส่ง Job ไปยัง **GitLab Runner** (เครื่อง `172.16.33.163` ที่ออกนอกได้เครื่องเดียว)
2. **GitLab Runner** ทำการ Build Docker Image ของ Next.js แล้ว Push ไปเก็บที่ **Harbor** (ภายใน)
3. **ArgoCD** (อยู่ใน Cluster) คอยดึง Image จาก Harbor มา Deploy ลง **Workers**
4. **Nginx LB** รับ Traffic จากภายนอก แล้วกระจายไปยัง **Traefik (Ingress)** บน Cluster

---

## 🖥️ จุดที่ต้องปรับเปลี่ยนในแต่ละเครื่อง (Deployment Matrix)

โครงสร้าง IP และการติดตั้งซอฟต์แวร์ส่วนใหญ่ยังคงเหมือนเดิม แต่เปลี่ยนเฉพาะในส่วนของ Runner ดังนี้ครับ:

### 1. เครื่อง Runner (`172.16.33.163`) — *เปลี่ยนตัวควบคุม*

* **สิ่งที่ต้องติดตั้งแทนของเดิม:** * เปลี่ยนจาก GitHub Actions Runner เป็น **GitLab Runner**
* ลงทะเบียน (Register) GitLab Runner ตัวนี้เข้ากับ GitLab Project หรือ GitLab Group ของคุณ


* **Executor แนะนำ:** แนะนำให้ตั้งค่า GitLab Runner โดยใช้ **Docker Executor** หรือ **Shell Executor** (ขึ้นอยู่กับความสะดวกในการจัดการ Docker Daemon สำหรับ Build Image Next.js)

### 2. เครื่องอื่นๆ (`...156`, `...157`, `...158`, `...159`)

* **ไม่มีการเปลี่ยนแปลง:** ยังคงทำหน้าที่เป็น Nginx LB, RKE2 Master (พร้อม ArgoCD) และ RKE2 Workers ตามเดิมทุกประการครับ

---

## 🛠️ สรุปขั้นตอนการทำงานใหม่ (GitLab + GitOps Workflow)

### 1. CI Pipeline (GitLab -> GitLab Runner)

* Developer ทำการ Push code ไปยัง **GitLab**
* GitLab จะสั่งงาน (Trigger Job) มาที่ **GitLab Runner** (`172.16.33.163`) ผ่านไฟล์คอนฟิก `.gitlab-ci.yml`
* GitLab Runner ใช้คำสั่ง Docker (เช่น Docker-in-Docker หรือคอลคอนเนกชันไป Docker Host) เพื่อ Build Next.js เป็น Docker Image
* GitLab Runner ทำการ Tag และ Push Image ไปยัง **Harbor** ภายในองค์กร

### 2. CD Pipeline (ArgoCD -> Cluster)

* **ArgoCD** (ซึ่งอยู่ใน Master Node) จะคอยตรวจสอบความเปลี่ยนแปลงของ Git Repository ที่เก็บ Manifest/Helm Chart (ซึ่งตอนนี้ย้ายมาอยู่บน GitLab)
* **ข้อควรระวังเรื่อง Network:** เนื่องจาก Cluster (`...157`) ออกเน็ตไปคุยกับ GitLab.com โดยตรงไม่ได้ วิธีแก้มี 2 แบบครับ:
1. **ใช้ Squid Proxy (แนะนำ):** ให้ ArgoCD วิ่งผ่าน Squid Proxy ที่เครื่อง `172.16.33.163` เพื่อออกไปตรวจจับความเปลี่ยนแปลงบน GitLab.com
2. **Webhook Trigger:** ให้ GitLab CI ในขั้นตอนสุดท้าย ยิง Webhook ผ่านเครื่อง Runner เข้ามาบอก ArgoCD ใน Cluster ให้ทำ `Refresh/Sync` (แต่แบบแรกจะเสถียรและเป็นมาตรฐาน GitOps มากกว่าครับ)



---

## 📄 ตัวอย่างไฟล์ `.gitlab-ci.yml` (สำหรับเครื่อง Runner)

คุณสามารถใช้ไฟล์นี้วางไว้ที่ Root ของโปรเจกต์ Next.js บน GitLab เพื่อสั่งให้ Runner ทำการ Build และ Push Image ได้เลยครับ:

```yaml
stages:
  - build

variables:
  HARBOR_REGISTRY: "harbor.yourdomain.local" # เปลี่ยนเป็น IP หรือ Domain ของ Harbor
  IMAGE_NAME: "nextjs-app"

build_and_push:
  stage: build
  tags:
    - target-runner-163 # Tag ของ GitLab Runner ที่เครื่อง 172.16.33.163
  script:
    # 1. Login เข้า Harbor ภายใน
    - echo "$HARBOR_PASSWORD" | docker login $HARBOR_REGISTRY -u "$HARBOR_USER" --password-stdin
    
    # 2. Build Docker Image
    - docker build -t $HARBOR_REGISTRY/library/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA .
    - docker tag $HARBOR_REGISTRY/library/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA $HARBOR_REGISTRY/library/$IMAGE_NAME:latest
    
    # 3. Push ไปยัง Harbor
    - docker push $HARBOR_REGISTRY/library/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA
    - docker push $HARBOR_REGISTRY/library/$IMAGE_NAME:latest

```

ภาพรวมสถาปัตยกรรมยังคงความปลอดภัยในรูปแบบ **Private Network** เหมือนเดิม เพียงแค่เปลี่ยนกลไกการสั่งงานจากฝั่ง Cloud ให้มาลงที่ GitLab Runner แทนครับ