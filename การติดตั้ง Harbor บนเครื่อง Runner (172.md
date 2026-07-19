การติดตั้ง Harbor บนเครื่อง Runner (172.16.33.163) เพื่อทำหน้าที่เป็น **OCI Registry** ในวง Private Network วิธีที่ง่าย เสถียร และดูแลรักษาง่ายที่สุดคือการใช้ **Harbor Docker Compose** ครับ

เนื่องจากเครื่อง Runner ออกเน็ตได้เครื่องเดียว เราจะใช้เครื่องนี้ดาวน์โหลดไฟล์และรันระบบขึ้นมาได้เลยตามขั้นตอน Best Practices ด้านล่างนี้ครับ:

---

## 📋 สิ่งที่ต้องเตรียมก่อนติดตั้ง (Prerequisites)

1. **Docker & Docker Compose:** ตรวจสอบว่าเครื่อง Runner ติดตั้ง Docker เรียบร้อยแล้ว
2. **Domain/Host Name:** ในวง Private แนะนำให้ตั้ง Domain หลอกขึ้นมา (เช่น `registry.local` หรือ `registry.internal`) แล้วนำไปแอดลง `/etc/hosts` ของทุกเครื่อง (Runner, Master, Workers) ให้ชี้มาที่ `172.16.33.163`
3. **Open Ports:** เปิด Port `80` (HTTP) และ `443` (HTTPS) ที่เครื่อง Runner

---

## 🛠️ ขั้นตอนการติดตั้ง Harbor (Step-by-Step)

### Step 1: ดาวน์โหลด Harbor Online Installer

ดาวน์โหลดเวอร์ชันล่าสุด (แนะนำ v2.10.x หรือ v2.11.x ขึ้นไปเพื่อให้รองรับ OCI และเสถียรที่สุด)

```bash
# ดาวน์โหลด Harbor Installer
wget https://github.com/goharbor/harbor/releases/download/v2.15.2/harbor-offline-installer-v2.15.2.tgz

# แตกไฟล์
tar -xvf harbor-offline-installer-v2.15.2.tgz
cd harbor

```

### Step 2: สร้าง SSL Certificate (จำเป็นมากสำหรับ OCI & Production)

Docker และ Kubernetes (RKE2) จะไม่ยอมให้ดึง Image/OCI Artifacts จาก Registry ที่ไม่มี HTTPS (ยกเว้นจะไปตั้งค่า Insecure Registry ซึ่งไม่แนะนำตามหลัก Best Practice)

ให้สร้าง Self-Signed Certificate ขึ้นมาใช้งานภายในวงดังนี้:

```bash
# 1. กำหนดตัวแปรระบบ (ปรับเปลี่ยนโดเมนและ IP ตามจริงของคุณ)
DOMAIN="registry.local"
IP="172.16.33.163"

# 2. สร้างโฟลเดอร์แยกเก็บอย่างเป็นระเบียบ
sudo mkdir -p /data/cert/ca
sudo mkdir -p /data/cert/services
cd /data/cert

# 3. สร้าง Root CA ขององค์กร (สำหรับแจกจ่ายให้เครื่องอื่น)
# คีย์ส่วนตัวของ CA
sudo openssl genrsa -out ca/company-internal-ca.key 4096

# ใบรับรองของ CA (ใส่ข้อมูล CN เพื่อบอกว่าเป็น CA ของบริษัท)
sudo openssl req -x509 -new -nodes -sha256 -days 3650 \
  -key ca/company-internal-ca.key \
  -out ca/company-internal-ca.crt \
  -subj "/CN=Company Internal CA"

# 4. สร้าง Certificate สำหรับบริการ Harbor (เซ็นโดย CA ด้านบน)
# คีย์ส่วนตัวของ Harbor
sudo openssl genrsa -out services/$DOMAIN.key 4096

# สร้างคำขอใบรับรอง (CSR)
sudo openssl req -sha256 -new \
  -key services/$DOMAIN.key \
  -out services/$DOMAIN.csr \
  -subj "/CN=$DOMAIN"

# 5. สร้าง x509 v3 extension เพื่อผูกกับ Domain และ IP
sudo tee v3.ext > /dev/null <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1=$DOMAIN
IP.1=$IP
EOF

# 6. ใช้ Root CA เซ็นออกใบ Certificate จริงให้ Harbor
sudo openssl x509 -req -sha256 -days 3650 \
  -extfile v3.ext \
  -in services/$DOMAIN.csr \
  -CA ca/company-internal-ca.crt -CAkey ca/company-internal-ca.key -CAcreateserial \
  -out services/$DOMAIN.crt
```

### Step 3: คอนฟิกไฟล์ `harbor.yml`

กลับมาที่โฟลเดอร์ `harbor` แล้วก๊อปปี้ไฟล์ Template เพื่อแก้ไข:

```bash
cd ~/harbor
cp harbor.yml.tmpl harbor.yml
nano harbor.yml

```

แก้ไขจุดสำคัญดังนี้ (เน้นเรื่อง Domain, SSL Path และ Password):

```yaml
# Domain ที่เราตั้งไว้ หรือจะใช้ IP (172.16.33.163) ก็ได้ แต่แนะนำ Domain ครับ
hostname: registry.local

# คอนฟิก HTTP & HTTPS (ชี้ไปที่ Cert ที่เราสร้างเมื่อครู่)
http:
  port: 80

https:
  port: 443
  certificate: /data/cert/services/registry.local.crt
  private_key: /data/cert/services/registry.local.key

# รหัสผ่านสำหรับ Admin หน้าเว็บ (แนะนำให้เปลี่ยนจาก default)
harbor_admin_password: P@ssw0rd

# ที่เก็บข้อมูลของ Harbor (Image, Database, Logs)
data_volume: /data/harbor
```

### Step 4: สั่งรันคำสั่ง ติดตั้ง

Harbor มีฟีเจอร์เด่นคือ **Trivy (Vulnerability Scanner)** คอยสแกนช่องโหว่ของ Image และ OCI แนะนำให้ติดตั้งพ่วงไปด้วยเลยด้วยคำสั่งนี้ครับ:

```bash
# รัน Script ติดตั้งพร้อมติดตั้ง Trivy Scanner
./install.sh --with-trivy
```

ถ้าระบบรันเสร็จสิ้น จะขึ้นข้อความว่า `----Harbor has been installed and started successfully.----` คุณจะสามารถเข้าหน้าเว็บผ่าน `https://172.16.33.163` หรือ `https://registry.local` ด้วยสิทธิ์ `admin` ได้ทันที

---

## 🔒 ขั้นตอนสำคัญหลังติดตั้งเพื่อให้ RKE2 และ Runner คุยกับ Harbor ได้

เนื่องจากเราใช้ Self-Signed Certificate เครื่องอื่นๆ ในวงจะไม่รู้จักและจะบล็อกการเชื่อมต่อ เราต้องนำไฟล์ `ca.crt` ไปติดตั้งให้เครื่องเหล่านั้นยอมรับครับ

### 1. ตั้งค่าที่เครื่อง Runner ตัวเอง (เพื่อให้ Docker Push ได้)

```bash
# สำหรับ docker
sudo mkdir -p /etc/docker/certs.d/registry.local/ && \
sudo cp /data/cert/services/registry.local.crt /etc/docker/certs.d/registry.local/ && \
sudo systemctl restart docker

# เครื่อง master
sudo cp /data/cert/ca/company-internal-ca.crt /usr/local/share/ca-certificates/ && \
sudo update-ca-certificates
```

*ทดสอบ:* รันคำสั่ง `docker login registry.local` บนเครื่อง Runner ต้อง Login ผ่าน

### 2. ตั้งค่าที่เครื่อง RKE2 (Master 157, Workers 158, 159)

เนื่องจาก RKE2 ไม่ได้ใช้ Docker แต่ใช้ **containerd** เราต้องเอาใบ Cert CA ไปวางไว้ในระบบของเครื่องเหล่านี้ทุกเครื่อง:

```bash
# รันคำสั่งนี้บนเครื่อง Master และ Worker ทุกเครื่อง
sudo mkdir -p /usr/local/share/ca-certificates/

# ก๊อปปี้ไฟล์ ca.crt จากเครื่อง runner มาวางที่นี่ (ใช้ scp ย้ายมา)
sudo cp company-internal-ca.crt /usr/local/share/ca-certificates/company-internal-ca.crt

# อัปเดตเพื่อให้ OS รู้จัก Cert นี้
sudo update-ca-certificates

# รีสตาร์ทเซอร์วิสของ RKE2 เพื่อโหลดค่า Cert ใหม่
# (ถ้าเป็นเครื่อง Master ให้เปลี่ยนเป็น rke2-server)
sudo systemctl restart rke2-agent
```

เพียงเท่านี้ เครื่อง Runner ก็จะมี Harbor OCI Registry ที่พร้อมรันยาวๆ และปลอดภัย พร้อมให้ GitHub Actions และ ArgoCD เข้ามาดึงไปใช้งานแล้วครับ