การเก็บ `PAT_TOKEN` (Personal Access Token) ให้ปลอดภัยบนเครื่อง Linux Runner (172.16.33.163) เพื่อไม่ให้หลุดไปกับ Script หรือ Log มีแนวทางปฏิบัติที่เป็นมาตรฐาน (Best Practices) ดังนี้ครับ โดยเรียงลำดับจากวิธีที่ง่ายและปลอดภัย จนถึงวิธีที่เป็นระดับ Enterprise

---

## 1. วิธีที่แนะนำที่สุด: ฝังไว้ใน Systemd Service Configuration (EnvironmentFile)

วิธีนี้ปลอดภัยกว่าการใส่ไว้ใน `~/.bashrc` หรือในตัว Script โดยตรง เพราะเราจะแยกไฟล์ Token ออกมาต่างหาก และจำกัดสิทธิ์ (Permission) ให้เฉพาะ User ที่รัน Runner หรือ root เท่านั้นที่อ่านได้

### ขั้นตอนการตั้งค่า:

1. **สร้างไฟล์เก็บ Secret แยกต่างหาก** (สมมติตั้งไว้ที่ `/etc/github-runner.env`):
```bash
sudo nano /etc/github-runner.env

```


2. **ใส่ Token ลงไปในรูปแบบ KEY=VALUE**:
```env
PAT_TOKEN=github_pat_XXXXXXXXXXXXXXXXXXXXXXXX

```


3. **ล็อคสิทธิ์การเข้าถึงไฟล์** (สำคัญมาก!):
ให้เฉพาะ `root` และ `User` ที่ใช้รัน Runner (เช่น user ชื่อ `runner`) อ่านได้เท่านั้น
```bash
sudo chown root:runner /etc/github-runner.env
sudo chmod 600 /etc/github-runner.env

```


4. **แก้ไขไฟล์ Systemd Service** (`/etc/systemd/system/github-runner.service`):
เพิ่มบรรทัด `EnvironmentFile=` เข้าไปในส่วนของ `[Service]`
```ini
[Unit]
Description=GitHub Actions Ephemeral Runner Loop
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/actions-runner
# เพิ่มบรรทัดนี้เพื่อดึงค่าจากไฟล์ env เข้ามาระหว่างรัน service
EnvironmentFile=/etc/github-runner.env 
ExecStart=/actions-runner/run-ephemeral.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

```


5. **แก้ไข Script (`run-ephemeral.sh`)**:
ให้ลบบรรทัด `PAT_TOKEN="..."` ออกไปเลย เพราะเมื่อ Systemd รันสคริปต์นี้ มันจะฉีดแปร `PAT_TOKEN` เข้าไปในระบบให้โดยอัตโนมัติ
6. **Reload Systemd**:
```bash
sudo systemctl daemon-reload
sudo systemctl restart github-runner.service

```



---

## 2. วิธีระดับ Advance: ดึงจาก Secret Manager ภายในคลาสเตอร์ RKE2

เนื่องจากคุณมี Stack ของ **RKE2** อยู่แล้ว หากต้องการยกระดับความปลอดภัยขึ้นไปอีกเพื่อไม่ให้มี Hardcoded Token อยู่บนไฟล์ของเครื่อง Runner เลย สามารถใช้แนวทางนี้ได้:

* ใช้เครื่องมืออย่าง **HashiCorp Vault** หรือ **Kubernetes Secrets** (ในกรณีที่ขยับขยายให้ Runner รันในคลาสเตอร์ หรือสร้าง API ภายในมารับสิทธิ์)
* **หลักการทำงาน**: ใน Script แทนที่จะดึงจาก `PAT_TOKEN` ตรงๆ ให้เขียนคำสั่ง `curl` หรือใช้ CLI ไปดึง Secret มาจาก Vault Server ณ จังหวะที่กำลังจะขอ Registration Token แล้วทำลายค่านั้นทิ้งใน Memory ทันทีหลังจากได้ Registration Token มาแล้ว

---

## 💡 ข้อควรระวังเพิ่มเติมเพื่อความปลอดภัย (Hardening)

* 🔴 **ห้าม** ใส่ Token ไว้ใน `run-ephemeral.sh` แล้ว Push ขึ้น Git เด็ดขาด (ต่อให้เป็น Private Git ก็ตาม)
* 🔴 **หลีกเลี่ยง** การใส่ไว้ใน `/etc/environment` หรือ `~/.bashrc` ของ User ทั่วไป เพราะหากมี User อื่นล็อกอินเข้าเครื่องนั้นมา แล้วสั่ง `printenv` จะเห็น Token ทั้งหมดทันที (การใช้ `EnvironmentFile` ใน Systemd จะปลอดภัยกว่าเพราะกระบวนการฉีดค่าจะเกิดเฉพาะตอนที่ Service ทำงานเท่านั้น)
* 🟢 **ลดสิทธิ์ PAT**: พยายามสร้าง PAT แบบ **Fine-grained** ที่เจาะจงเฉพาะสิทธิ์ `Administration: Write` ของ Repo นั้นๆ เท่านั้น อย่าใช้ Classic PAT ที่มีสิทธิ์ครอบจักรวาล (เช่น ติ๊กเลือก `repo` ทั้งหมด) เพื่อจำกัดวงความเสียหายหาก Token หลุดรอดไป