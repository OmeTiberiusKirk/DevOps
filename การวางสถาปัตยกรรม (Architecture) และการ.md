การวางสถาปัตยกรรม (Architecture) และการติดตั้งตาม **Best Practices** สำหรับระบบที่มีข้อจำกัดเรื่องการออกอินเทอร์เน็ต (มีเพียงเครื่อง Runner ออกเน็ตได้เครื่องเดียว) จะต้องใช้แนวทางแบบ **Hybrid Air-Gapped / Private Network** ครับ

นี่คือแผนผังและการกระจายสอฟต์แวร์ลงแต่ละเครื่องเพื่อให้ระบบ ปลอดภัย, มีประสิทธิภาพ และตรงตามหลัก DevOps ครับ

---

## 🏗️ ภาพรวมการทำงาน (Conceptual Flow)

1. **GitHub** ส่ง Code ไปยัง **Runner** (เครื่องเดียวที่ออกนอกบริษัทได้)
2. **Runner** ทำการ Build Docker Image ของ Next.js แล้ว Push ไปเก็บที่ **Harbor** (ภายใน)
3. **ArgoCD** (อยู่ใน Cluster) คอยดึง Image จาก Harbor มา Deploy ลง **Workers**
4. **Nginx LB** รับ Traffic จากภายนอก แล้วกระจายไปยัง **Traefik (Ingress)** บน Cluster

---

## 🖥️ การกระจายการติดตั้งซอฟต์แวร์ในแต่ละเครื่อง (Deployment Matrix)

### 1. เครื่อง Runner (`172.16.33.163`) — *ประตูสู่โลกภายนอก*

เครื่องนี้ทำหน้าที่เป็น **Bastion/Gateway** และ **CI Build Server** * **สิ่งที่ต้องติดตั้ง:**
* **GitHub Actions Runner (หรือ GitLab Runner):** เพื่อรับ Job จาก GitHub
* **Docker / Podman:** สำหรับใช้ Build Docker Image (Next.js)
* **Harbor (OCI Registry):** แนะนำให้ติดตั้งไว้ที่เครื่องนี้ หรือสร้าง VM แยกอีกตัวที่ต่อกับเครื่องนี้ เพราะเครื่องนี้ออกเน็ตไปโหลด Base Image มาเก็บไว้ได้ และทำหน้าที่เป็นคลังส่วนตัวให้ Cluster
* **Squid Proxy (Optional แต่แนะนำ):** ทำหน้าที่เป็น Forward Proxy เพื่อให้เครื่อง Master/Worker สามารถวิ่งผ่านเครื่องนี้ไปโหลด Patch หรือดึงดาวน์โหลด RKE2 artifacts ได้ชั่วคราวตอนติดตั้ง

### 2. เครื่อง Nginx Load Balancer (`172.16.33.156`) — *หน้าด่านรับ Traffic*

เครื่องนี้อยู่นอก Cluster ทำหน้าที่กระจายโหลด (Layer 4 หรือ Layer 7) ไปยัง Ingress Controller

* **สิ่งที่ต้องติดตั้ง:**
* **Nginx Open Source หรือ HAProxy:** * **การตั้งค่า (Best Practice):** ทำการ Reverse Proxy (หรือทำ TCP Load Balancing ที่พอร์ต 80, 443) ชี้เป้าไปยัง IP ของ `workeruat01` และ `workeruat02` (พอร์ตของ Traefik)



### 3. เครื่อง Master Node (`172.16.33.157`) — *สมองของ Cluster*

ทำหน้าที่เป็น Control Plane ไม่ควรเอาแอปพลิเคชันของ User (Next.js) มาวิ่งลงเครื่องนี้

* **สิ่งที่ต้องติดตั้ง:**
* **RKE2 Server:** ติดตั้งแบบปิดสิทธิ์ไม่ให้รัน Workload ทั่วไป (`Taint: CriticalAddonsOnly=true:NoSchedule`)
* **ArgoCD:** แนะนำให้ติดตั้งไว้บน Control Plane หรือสร้าง Namespace แยกต่างหาก เพื่อใช้จัดการ GitOps ควบคุม Cluster



### 4. เครื่อง Worker Nodes (`172.16.33.158` & `172.16.33.159`) — *แรงงานรันแอป*

* **สิ่งที่ต้องติดตั้ง:**
* **RKE2 Agent:** เพื่อเข้าร่วมเป็น Worker Node
* **Traefik (Ingress Controller):** ให้รันในรูปแบบ DaemonSet หรือ Deployment บน Worker Nodes ทั้งสองเครื่อง (เพื่อให้ Nginx LB ด้านนอกยิงมาเจอ)
* **Next.js Application:** แอปพลิเคชันของคุณจะถูก ArgoCD สั่ง Deploy ลงมาที่สองเครื่องนี้ในรูปแบบ Pods



---

## 🛠️ สรุปขั้นตอนการทำงานเชิง Best Practices (CI/CD GitOps Workflow)

1. **การติดตั้ง RKE2 (Air-Gapped Setup):**
เนื่องจาก Master และ Worker ออกเน็ตไม่ได้ ให้ใช้เครื่อง Runner ดาวน์โหลด `RKE2 Artifacts` (Tarball, Images, install.sh) มาล่วงหน้า จากนั้นคัดลอก (SCP) ไปยัง Master/Worker เพื่อทำการติดตั้งแบบ Offline
2. **CI Pipeline (GitHub -> Runner):**
* Developer Push code ไป GitHub
* GitHub สั่งงานมาที่ **Self-hosted Runner** (`172.16.33.163`)
* Runner ทำการดึงโค้ด, Build Next.js เป็น Docker Image
* Runner ทำการ Tag และ Push Image ไปยัง **Harbor** (ซึ่งอยู่ภายใน Network เดียวกัน)


3. **CD Pipeline (ArgoCD -> Cluster):**
* **ArgoCD** คอยตรวจจับความเปลี่ยนแปลงของ Git Repository (โดยผ่านเครื่อง Runner หรือตั้ง Pull Mechanism)
* เมื่อมีการอัปเดตเวอร์ชันของแอป ArgoCD จะสั่งให้ RKE2 Cluster ดึง Image เวอร์ชันใหม่จาก **Harbor** มา Deploy ลงเครื่อง Worker Node 01 และ 02 แบบ Rolling Update


4. **การเข้าถึงแอปพลิเคชัน (Routing):**
* User เข้าแอปผ่าน URL -> วิ่งชน **Nginx LB** (`...156`)
* Nginx LB ส่งต่อ Traffic ไปที่ **Traefik Ingress** (พอร์ต 80/443 บน `...158` และ `...159`)
* Traefik ส่ง Traffic เข้าไปที่ **Next.js Pods** ภายใน Cluster