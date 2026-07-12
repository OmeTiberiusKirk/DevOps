การติดตั้ง **Squid Proxy** บนเครื่อง Runner (`172.16.33.163`) เพื่อทำหน้าที่เป็น **Forward Proxy** ให้เครื่อง Master และ Workers ภายในสามารถวิ่งผ่านเพื่อไปดาวน์โหลด Patch หรือ RKE2 Artifacts ได้ มีขั้นตอนการติดตั้งและตั้งค่าตามหลัก Best Practices ดังนี้ครับ

---

## 🛠️ ขั้นตอนที่ 1: การติดตั้ง Squid Proxy

สมมติว่าเครื่อง Runner ของคุณใช้ระบบปฏิบัติการตระกูล Linux (Ubuntu/Debian หรือ RHEL/Rocky Linux) ให้เลือกใช้คำสั่งตาม OS นั้นๆ ครับ:

### สำหรับ Ubuntu / Debian

```bash
sudo apt update
sudo apt install squid -y

```

### สำหรับ RHEL / Rocky Linux / AlmaLinux

```bash
sudo dnf install squid -y

```

---

## ⚙️ ขั้นตอนที่ 2: การตั้งค่า (Configuration)

ไฟล์คอนฟิกหลักของ Squid จะอยู่ที่ `/etc/squid/squid.conf` เราจำเป็นต้องตั้งค่าให้ยอมรับ Traffic เฉพาะจากวงเน็ตเวิร์กภายในของคุณ (`172.16.33.0/24`) เพื่อความปลอดภัย

1. เปิดไฟล์คอนฟิกขึ้นมาแก้ไข:
```bash
sudo nano /etc/squid/squid.conf

```


2. ค้นหาโซนการตั้งค่า **ACL (Access Control List)** แล้วเพิ่มวง IP ภายในของคุณเข้าไป (แนะนำให้ใส่ไว้ด้านบนสุดของไฟล์ หรือแถวๆ กลุ่ม `acl` เดิม):
```text
# กำหนดสิทธิ์ให้วง Network ภายในบริษัท
acl local_network src 172.16.33.0/24

# อนุญาตให้เฉพาะ local_network และเครื่องตัวเองใช้งาน proxy ได้
http_access allow localhost
http_access allow local_network

# ปฏิเสธการเชื่อมต่ออื่นๆ ทั้งหมด (ปกติมีอยู่แล้วที่ท้ายไฟล์)
http_access deny all

```


3. *(Optional)* ตรวจสอบพอร์ตการทำงาน (ค่าเริ่มต้นคือพอร์ต `3128` สามารถเปลี่ยนได้ถ้าต้องการ):
```text
http_port 3128

```


4. บันทึกไฟล์และปิดโปรแกรมแก้ไข (หากใช้ nano ให้กด `Ctrl+O`, `Enter` และ `Ctrl+X`)

---

## 🚀 ขั้นตอนที่ 3: เปิดใช้งานและตั้งค่า Firewall

1. สั่งเปิดใช้งาน (Enable) และเริ่มทำงาน (Start) บริการ Squid:
```bash
sudo systemctl enable squid
sudo systemctl start squid

```


2. ตรวจสอบสถานะว่ารันอยู่ปกติหรือไม่:
```bash
sudo systemctl status squid

```


3. **ตั้งค่า Firewall** บนเครื่อง Runner เพื่อเปิดพอร์ต `3128` ให้เครื่องอื่นๆ ในวงมองเห็น:
* **สำหรับ UFW (Ubuntu):**
```bash
sudo ufw allow from 172.16.33.0/24 to any port 3128 proto tcp
sudo ufw reload

```


* **สำหรับ Firewalld (RHEL/Rocky):**
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.33.0/24" port port="3128" protocol="tcp" accept'
sudo firewall-cmd --reload

```





---

## 💻 ขั้นตอนที่ 4: วิธีนำไปใช้งานบนเครื่อง Master / Workers

เมื่อเปิด Proxy บนเครื่อง Runner เรียบร้อยแล้ว เครื่องอื่นๆ ในเน็ตเวิร์กภายใน (`172.16.33.157`, `.158`, `.159`) สามารถเรียกใช้อินเทอร์เน็ตผ่าน Proxy นี้ได้ชั่วคราวโดยการประกาศค่า **Environment Variables** ดังนี้:

### 1. ใช้งานแบบชั่วคราว (สำหรับรันคำสั่ง curl, wget หรือ apt/dnf ณ ตอนนั้น)

รันคำสั่งนี้บน Terminal ของเครื่อง Master/Worker:

```bash
export http_proxy=http://172.16.33.163:3128
export https_proxy=http://172.16.33.163:3128
export no_proxy=localhost,127.0.0.1,172.16.33.0/24,cluster.local

```

*(หมายเหตุ: ต้องใส่ `no_proxy` ไว้ด้วยเพื่อป้องกันไม่ให้ Traffic ที่คุยกันเองภายใน Cluster วิ่งออกไปหา Proxy)*

### 2. ทดสอบว่าใช้งานได้จริงไหม

ลองใช้คำสั่ง `curl` ทดสอบดึงข้อมูลจากภายนอกผ่านเครื่อง Master/Worker:

```bash
curl -I https://www.google.com

```

หากสำเร็จ จะได้รับ HTTP Status `200 OK` กลับมา และหากไปดู Log ที่เครื่อง Runner (`/var/log/squid/access.log`) จะเห็น Log การขอเชื่อมต่อจาก IP ของเครื่อง Master/Worker ครับ