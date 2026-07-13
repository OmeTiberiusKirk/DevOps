หลังจากที่คุณเข้าหน้าเว็บ **ArgoCD** ได้เรียบร้อยแล้ว ขั้นตอนต่อไปคือการเซ็ตอัปให้ ArgoCD รู้จักกับ Git Repository (คลังเก็บ Manifest/YAML) และสั่งให้มันไปคุม Cluster เพื่อ Deploy แอปพลิเคชัน Next.js ครับ

นี่คือ 4 ขั้นตอนหลักที่คุณต้องทำต่อเพื่อให้ระบบ GitOps ทำงานได้สมบูรณ์:

---

## 🔑 ขั้นตอนที่ 1: เข้าสู่ระบบ (Login) ครั้งแรก

หากคุณยังไม่ได้เอารหัสผ่านเริ่มต้น ให้รันคำสั่งนี้ที่เครื่อง **Master Node** เพื่อดึงรหัสผ่านของ `admin`:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

```

* **Username:** `admin`
* **Password:** รหัสที่ได้จากคำสั่งด้านบน (แนะนำให้เปลี่ยนทันทีหลังจากเข้าสู่ระบบที่เมนู User Info)

---

## 📦 ขั้นตอนที่ 2: เตรียม Kubernetes Manifest (ใน Git)

ก่อนจะไปตั้งค่าใน ArgoCD คุณต้องมี **Git Repository** (เช่น GitHub หรือ GitLab) ที่เก็บไฟล์โครงสร้าง (YAML) ของแอป Next.js ไว้ก่อน โดยโครงสร้างพื้นฐานควรมีอย่างน้อย 3 ไฟล์นี้:

1. **Deployment.yaml:** กำหนดให้ดึง Image จาก **Harbor** (เช่น `172.16.33.163/my-project/nextjs:latest`) และตั้งค่า `imagePullSecrets` (เพราะ Harbor เป็น Private Registry)
2. **Service.yaml:** เปิดพอร์ตภายใน Cluster
3. **Ingress.yaml:** กำหนด Routing ให้ **Traefik** รู้จัก

---

## 🔒 ขั้นตอนที่ 3: ผูกสิทธิ์ให้ Cluster ดึง Image จาก Harbor ได้

เนื่องจากเครื่อง Worker Node ออกเน็ตไม่ได้ และต้องดึง Image จาก Harbor (`172.16.33.163`) ที่อยู่ในเครื่อง Runner คุณต้องสร้าง **Secret** ไว้ใน Namespace ที่จะลงแอปพลิเคชัน เพื่อให้ Kubernetes มีสิทธิ์ล็อกอินเข้า Harbor:

รันคำสั่งนี้ที่เครื่อง **Master Node** (เปลี่ยน user/password ให้ตรงกับของ Harbor):

```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=172.16.33.163 \
  --docker-username=<HARBOR_USER> \
  --docker-password=<HARBOR_PASSWORD> \
  -n default

```

*(ในไฟล์ `Deployment.yaml` ของ Next.js อย่าลืมใส่ `imagePullSecrets: [{name: harbor-registry-secret}]`)*

---

## 🚀 ขั้นตอนที่ 4: สร้าง "Application" บนหน้าเว็บ ArgoCD

กลับมาที่หน้าเว็บ ArgoCD เพื่อเชื่อมต่อ Git เข้ากับ Cluster:

1. คลิกปุ่ม **"+ New App"** ที่มุมซ้ายบน
2. ตั้งค่าตามหัวข้อหลักๆ ดังนี้:
* **General**
* `Application Name`: `nextjs-app`
* `Project Name`: `default`
* `Sync Policy`: เลือก `Automatic` (ถ้าต้องการให้โค้ดเปลี่ยนแล้วแอปเปลี่ยนทันที) หรือ `Manual` (กดคลิก Deploy เองมือ)


* **Source**
* `Repository URL`: ใส่ URL ของ Git Repository ที่เก็บไฟล์ YAML
* `Revision`: `HEAD` (หรือระบุ branch เช่น `main`)
* `Path`: ใส่โฟลเดอร์ที่เก็บไฟล์ YAML (เช่น `./k8s` หรือ `.` ถ้าอยู่หน้าแรก)


* **Destination**
* `Cluster URL`: เลือก `https://kubernetes.default.svc` (หมายถึง Cluster ตัวมันเองที่ ArgoCD ฝังอยู่)
* `Namespace`: `default` (หรือ Namespace ที่คุณเตรียมไว้ลงแอป)




3. กดปุ่ม **"Create"** ที่ด้านบน

---

### 🎉 สิ่งที่จะเกิดขึ้นหลังจากนี้

* ArgoCD จะขึ้นสถานะ **OutOfSync** แป๊บหนึ่ง แล้วจะเปลี่ยนเป็น **Synced (สีเขียว)**
* มันจะสั่งให้ Worker Node (`...158`, `...159`) วิ่งไปดึง Image จาก Harbor (`...163`) มาสร้างเป็น Pod
* คุณสามารถทดสอบยิง URL ผ่าน **Nginx LB** (`...156`) เพื่อเข้าชมหน้าเว็บ Next.js ได้ทันทีครับ

มีติดขัดในขั้นตอนการผูก Git หรือการเขียนไฟล์ YAML สำหรับ Next.js ในส่วนไหนเพิ่มเติมไหมครับ?