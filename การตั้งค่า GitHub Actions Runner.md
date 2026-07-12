การตั้งค่า GitHub Actions Runner แบบ `--ephemeral` (รันเสร็จแล้วทำลายตัวเองทิ้ง) ควบคู่กับการขอ Registration Token ใหม่โดยอัตโนมัติในทุก ๆ รอบ เป็นแนวคิดที่ดีมากในแง่ของ **Security** และ **Clean Environment** โดยเฉพาะในสถาปัตยกรรมแบบ Private Network ที่คุณวางไว้ (มีเครื่อง Runner 172.16.33.163 ออกเน็ตได้เครื่องเดียว)

นี่คือไกด์และ Script ในการทำระบบนี้ให้ทำงานแบบอัตโนมัติ (Automated Lifecycle) ครับ

---

## 🛠️ แนวคิดการทำงาน (Concept Workflow)

1. **GitHub App หรือ PAT**: เราต้องมีสิทธิ์ในการขอ Token ใหม่จาก GitHub API
2. **Fetch Token**: เขียน Script ไปเรียก GitHub API เพื่อเอา `Registration Token` ตัวล่าสุด
3. **Configure**: สั่ง `./config.sh` โดยใช้ Token นั้นพร้อมใส่แฟล็ก `--ephemeral`
4. **Start**: สั่ง `./run.sh` ตัว Runner จะรับงานเพียง **1 งาน** เมื่อทำเสร็จมันจะปลดตัวเองออกจาก GitHub ทันที
5. **Loop**: ใช้ systemd หรือ Script วนลูปเพื่อกลับไปเริ่มข้อ 2 ใหม่เสมอ

---

## 🔑 ขั้นตอนที่ 1: เตรียม GitHub Personal Access Token (PAT)

คุณจำเป็นต้องมี PAT (Fine-grained หรือ Classic) ที่มีสิทธิ์ในการจัดการ Runners

* **สำหรับ Repo-level runner:** ต้องการสิทธิ์ `Administration` (Read and Write) ใน Repository นั้นๆ
* **สำหรับ Org-level runner:** ต้องการสิทธิ์ `Organization Actions` (Read and Write)

---

## 📜 ขั้นตอนที่ 2: สร้าง Script จัดการ Lifecycle (`run-ephemeral.sh`)

สร้าง Script นี้ไว้ที่เครื่อง Runner (`172.16.33.163`) ในโฟลเดอร์ของ actions-runner (เช่น `/actions-runner`)

```bash
#!/bin/bash

# --- CONFIGURATION ---
GH_OWNER="your-github-username-or-org"
GH_REPO="your-repo-name" # ลบส่วนนี้ออกหากใช้ Org-level
PAT_TOKEN="github_pat_XXXXXXXXXXXXXXXXXXXXXXXX" # แนะนำให้เปลี่ยนเป็น Environment Variable หรือ Vault
RUNNER_DIR="/actions-runner" # พาธที่ติดตั้ง runner

# API URL (เลือกใช้ตามระดับของ Runner)
# สำหรับ Repository Level:
API_URL="https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/runners/registration-token"
# สำหรับ Organization Level:
# API_URL="https://api.github.com/orgs/${GH_OWNER}/actions/runners/registration-token"

echo "=== Starting Ephemeral Runner Lifecycle ==="

while true; do
    cd "$RUNNER_DIR" || exit 1

    echo "1. Requesting new registration token from GitHub..."
    # เรียก API เพื่อขอ Token ใหม่
    RESPONSE=$(curl -s -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${PAT_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$API_URL")

    REG_TOKEN=$(echo "$RESPONSE" | grep -o '"token": "[^"]*' | grep -o '[^"]*$')

    if [ -z "$REG_TOKEN" ]; then
        echo "❌ Error: Failed to fetch registration token. Response was:"
        echo "$RESPONSE"
        echo "Retrying in 30 seconds..."
        sleep 30
        continue
    fi

    echo "✅ Token obtained successfully."

    echo "2. Configuring runner with --ephemeral flag..."
    # สั่งล้างคอนฟิกเก่าก่อน (ถ้ามี)
    ./config.sh remove --token "${REG_TOKEN}" --unattended 2>/dev/null

    # คอนฟิกตัวใหม่แบบระบุชื่อไม่ให้ซ้ำกัน (ใช้ Timestamp หรือ Random)
    RUNNER_NAME="private-runner-$(date +%s)"
    
    ./config.sh --url "https://github.com/${GH_OWNER}/${GH_REPO}" \
                --token "${REG_TOKEN}" \
                --name "${RUNNER_NAME}" \
                --work "_work" \
                --labels "private-network,rke2-deployer" \
                --unattended \
                --ephemeral

    echo "3. Starting runner in --ephemeral mode..."
    echo "⚡ Runner is listening for ONE job. It will exit automatically after the job completes."
    
    # รันตัว runner (มันจะบล็อกบรรทัดนี้ไว้จนกว่าจะทำงานเสร็จ 1 จ๊อบแล้วปิดตัวเอง)
    ./run.sh

    echo "🔄 Job completed. Runner self-destructed. Restarting loop to fetch a new token..."
    sleep 5
done

```

> ⚠️ **อย่าลืม:** เปลี่ยนสิทธิ์ให้รันได้ด้วยคำสั่ง `chmod +x run-ephemeral.sh`

---

## 🔄 ขั้นตอนที่ 3: ตั้งค่าเป็น Systemd Service (เพื่อให้รันอัตโนมัติ)

เพื่อให้ Script วนลูปนี้ทำงานตลอดเวลาแม้จะปิดหน้าจอ Terminal ไป ให้ทำเป็น Linux Service

1. สร้างไฟล์ Service:
```bash
sudo nano /etc/systemd/system/github-runner.service

```


2. ใส่คอนฟิกนี้ลงไป (ปรับ `User` และ `WorkingDirectory` ให้ตรงกับเครื่องของคุณ):
```ini
[Unit]
Description=GitHub Actions Ephemeral Runner Loop
After=network.target

[Service]
Type=simple
User=runner-user
WorkingDirectory=/actions-runner
ExecStart=/actions-runner/run-ephemeral.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

```


3. สั่ง Reload และเปิดใช้งาน:
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-runner.service
sudo systemctl start github-runner.service

```



---

## 🔒 การเชื่อมโยงกับ Private Stack ของคุณ (RKE2 + ArgoCD)

เนื่องจากเครื่อง Runner (`172.16.33.163`) เป็นเครื่องเดียวที่ออกเน็ตได้ มันจะทำหน้าที่รับ Code/Image Trigger จาก GitHub จากนั้นขั้นตอนถัดไปใน CI/CD Pipeline ควรกำหนดดังนี้:

1. **Build Next.js & Push to Harbor**:
Runner ตัวนี้ทำการ Docker Build และ Push ไปที่ Harbor (ซึ่งอยู่ใน Private Network เดียวกัน สามารถวิ่งไปหา Harbor Direct IP หรือผ่าน Nginx LB ได้เลย)
2. **Update GitOps (ArgoCD)**:
ในสเต็ปสุดท้ายของ Workflow ให้ใช้ Git ทำการแก้เลข Tag ของ Image ใน Repository คอนฟิกของ ArgoCD
3. **ArgoCD Pull Sync**:
เครื่อง Master (`172.16.33.157`) และ Workers (`..158`, `..159`) ไม่จำเป็นต้องออกเน็ตภายนอก แค่ให้ ArgoCD ที่อยู่ใน RKE2 Cluster คอยดึงความเปลี่ยนแปลงจาก Git Repo (หรือผ่าน Webhook ภายใน) และสั่ง Pull image จาก Harbor ภายในเน็ตเวิร์คเดียวกันมาอัปเดตระบบ