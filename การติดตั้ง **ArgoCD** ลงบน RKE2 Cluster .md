การติดตั้ง **ArgoCD** ลงบน RKE2 Cluster (Master Node) ในสภาพแวดล้อมที่เป็น **Air-Gapped / Private Network** (ออกอินเทอร์เน็ตไม่ได้) จะต้องใช้วิธีดาวน์โหลดไฟล์ Manifest (YAML) หรือ Helm Chart เตรียมไว้ล่วงหน้าจากเครื่อง Runner แล้วค่อยส่งเข้ามาติดตั้งภายใน Cluster ครับ

นี่คือวิธีติดตั้งตามแนวทาง Best Practices แยกเป็น 2 วิธีหลัก (เลือกวิธีที่สะดวกได้เลยครับ):

---

## วิธีที่ 1: ติดตั้งผ่าน Manifest YAML (แนะนำสำหรับความง่ายและตรงไปตรงมา)

เนื่องจากเครื่อง Master ออกเน็ตไม่ได้ เราจะใช้เครื่อง **Runner (`172.16.33.163`)** เป็นตัวดาวน์โหลดไฟล์ก่อน

### ขั้นตอนที่ 1: เตรียมไฟล์บนเครื่อง Runner

1. เอ็กพอร์ตหรือดาวน์โหลด Manifest ของ ArgoCD เวอร์ชันที่ต้องการ (ตัวอย่างนี้ใช้ v2.11.0 สามารถเปลี่ยนเป็นเวอร์ชันล่าสุดที่ต้องการได้)
```bash
curl -sSL -o argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

```


2. ส่งไฟล์ `argocd-install.yaml` ข้ามไปยังเครื่อง **Master Node (`172.16.33.157`)** ด้วย `scp`:
```bash
scp argocd-install.yaml mastereserviceplus@192.168.2.71:/tmp/
```



### ขั้นตอนที่ 2: ดึง Docker Images ไปเก็บที่ Harbor

เนื่องจากในไฟล์ YAML จะมี Image ของ ArgoCD ที่ชี้ไปยัง Docker Hub/GitHub Registry ให้ทำการ Pull, Tag และ Push ไปที่ **Harbor** ของคุณก่อน:

1. ดูรายการ Image ที่ต้องใช้ในไฟล์ (เช่น `quay.io/argoproj/argocd:...`)
2. ใช้เครื่อง Runner ดึงมาแล้ว Push เข้า Harbor:
```bash
docker pull quay.io/argoproj/argocd:v2.11.0
docker tag quay.io/argoproj/argocd:v2.11.0 harbor.yourdomain.local/repository/argocd:v2.11.0
docker push harbor.yourdomain.local/repository/argocd:v2.11.0

```


*(ทำแบบนี้กับทุก Image ที่ตรวจเจอในไฟล์ เช่น redis, dex, repo-server)*
3. แก้ไขไฟล์ `argocd-install.yaml` บนเครื่อง Master ให้ชี้ไปที่ IP/Domain ของ **Harbor** แทนที่ของเดิม

### ขั้นตอนที่ 3: สั่งติดตั้งบนเครื่อง Master Node (`172.16.33.157`)

1. SSH เข้าเครื่อง Master
2. สร้าง Namespace สำหรับ ArgoCD:
```bash
kubectl create namespace argocd

```


3. สั่ง Deploy ไฟล์ Manifest:
```bash
kubectl apply -n argocd -f /tmp/argocd-install.yaml

```



---

## วิธีที่ 2: ติดตั้งผ่าน Helm Chart (แนะนำสำหรับการจัดการในระยะยาว)

วิธีนี้เหมาะสำหรับกรณีที่คุณต้องการปรับแต่ง Config ได้ง่ายผ่าน `values.yaml`

### ขั้นตอนที่ 1: ดาวน์โหลด Helm Chart บนเครื่อง Runner

1. เพิ่ม Repo ของ ArgoCD บนเครื่อง Runner:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

```


2. ดาวน์โหลด Chart ออกมาเป็นไฟล์ตระกูลสากล (.tgz):
```bash
helm pull argo/argo-cd --version 5.46.0 --untar

```


3. จัดการเรื่อง Docker Images (Pull จากเน็ตภายนอก -> Push เข้า Harbor ภายในของคุณ เหมือนวิธีที่ 1)
4. แก้ไขไฟล์ `values.yaml` ในโฟลเดอร์ที่แตกออกมา โดยเปลี่ยน `global.image.repository` ให้ชี้ไปที่ Harbor ของคุณ
5. บีบอัดโฟลเดอร์กลับ หรือส่งโฟลเดอร์นั้นไปยังเครื่อง Master:
```bash
scp -r argo-cd user@172.16.33.157:/tmp/

```



### ขั้นตอนที่ 2: สั่งติดตั้งบนเครื่อง Master Node

1. SSH เข้าเครื่อง Master
2. สั่งติดตั้งด้วยคำสั่ง Helm (RKE2 มี Helm มาให้ในตัว หรือระบุ path ไปที่ `/var/lib/rancher/rke2/bin/helm`):
```bash
kubectl create namespace argocd
helm install argocd /tmp/argo-cd -n argocd

```



---

## 🔐 ขั้นตอนหลังการติดตั้ง (Post-Installation)

หลังจากติดตั้งเสร็จแล้ว (ไม่ว่าจะใช้วิธีใด) ให้ทำตามขั้นตอนต่อไปนี้เพื่อเข้าใช้งาน:

### 1. ดึงรหัสผ่านแรกเริ่ม (Initial Admin Password)

รหัสผ่านของ User `admin` จะถูกเก็บไว้ใน Kubernetes Secret ให้รันคำสั่งนี้บนเครื่อง Master เพื่อดูรหัสผ่าน:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

```

### 2. การเปิดให้ภายนอกเข้าถึง (Port-Forward หรือ Ingress)

ตามสถาปัตยกรรมของคุณ คุณมี **Traefik Ingress** อยู่ที่เครื่อง Workers และ **Nginx LB** อยู่ด้านหน้าสุด แนะนำให้สร้าง **Ingress Route** เพื่อให้วิ่งผ่านหน้าด่านเข้ามาครับ:

สร้างไฟล์ `argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: argocd.yourdomain.local  # เปลี่ยนเป็น Domain ที่คุณต้องการ
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443

```

สั่งรัน: `kubectl apply -f argocd-ingress.yaml`

> 💡 **Tip สำหรับการทดสอบเบื้องต้น:** หากยังไม่ยากตั้งค่า Ingress สามารถใช้คำสั่ง Port-Forward จากเครื่อง Master เพื่อเช็คสถานะก่อนได้:
> `kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0` (แล้วเข้าผ่าน `http://172.16.33.157:8080`)