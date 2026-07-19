เพื่อให้สอดคล้องกับสถาปัตยกรรม **Hybrid Air-Gapped / Private Network** ที่คุณวางไว้ การตั้งค่า **Nginx Load Balancer (`172.16.33.156`)** ที่ดีที่สุดคือการทำ **Layer 4 TCP Load Balancing (Stream)** หรือ **Layer 7 HTTP Reverse Proxy** ร่วมกับ **SSL Passthrough / Offloading** ด้านล่างนี้คือโครงสร้างการตั้งค่า Nginx ตาม **Best Practices** ที่ปลอดภัย รองรับการขยายตัว (Scalable) และมีประสิทธิภาพสูงสุดสำหรับระบบของคุณครับ

---

## 🛠️ แนวทางที่ 1: Layer 4 (TCP) Load Balancing (แนะนำที่สุด)

**ทำไมถึงแนะนำ:** เนื่องจากคุณมี **Traefik** เป็น Ingress Controller อยู่ใน Cluster แล้ว การทำ TCP Load Balancing ที่ Nginx (Layer 4) จะเป็นการส่งผ่าน Traffic (เช่น Port 80, 443) ตรงไปยัง Traefik โดยไม่ต้องถอดรหัส SSL ที่ Nginx

* **ข้อดี:** ประสิทธิภาพสูงมาก (High Performance), จัดการ SSL Certificate ที่จุดเดียว (ที่ Traefik ใน Cluster), Nginx ทำหน้าที่เป็นเพียงทางผ่านที่ชาญฉลาด

### 📄 ไฟล์คอนฟิก `/etc/nginx/nginx.conf` (Layer 4)

```nginx
user nginx;
worker_processes auto; # ปรับตามจำนวน CPU Core ของเครื่อง LB
worker_rlimit_nofile 65535; # เพิ่มขีดจำกัดการเปิดไฟล์เพื่อรองรับ Concurrent Connections สูงๆ

error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 8192; # ปรับเพิ่มจากค่าปกติ (1024) เพื่อรองรับทราฟฟิก
    use epoll;
    multi_accept on;
}

# สำหรับ Layer 4 ต้องอยู่นอกบล็อก http {}
stream {
    # กำหนดกลุ่มของ Worker Nodes ที่รัน Traefik Ingress
    upstream rke2_ingress_http {
        hash $remote_addr consistent; # ใช้ IP Hash เพื่อให้ Session ยึดกับ Worker Node ตัวเดิม (ถ้าจำเป็น)
        server 172.16.33.158:80 max_fails=3 fail_timeout=10s; # Worker 1
        server 172.16.33.159:80 max_fails=3 fail_timeout=10s; # Worker 2
    }

    upstream rke2_ingress_https {
        hash $remote_addr consistent;
        server 172.16.33.158:443 max_fails=3 fail_timeout=10s; # Worker 1
        server 172.16.33.159:443 max_fails=3 fail_timeout=10s; # Worker 2
    }

    # Listen Port 80 (HTTP)
    server {
        listen 80;
        proxy_pass rke2_ingress_http;
        proxy_timeout 10m;
        proxy_connect_timeout 5s;
    }

    # Listen Port 443 (HTTPS) - ส่งผ่าน SSL (Passthrough) ไปให้ Traefik ถอดรหัส
    server {
        listen 443;
        proxy_pass rke2_ingress_https;
        proxy_timeout 10m;
        proxy_connect_timeout 5s;
    }
}

```

---

## 🛠️ แนวทางที่ 2: Layer 7 (HTTP) Load Balancing with SSL Offloading

**ทำไมถึงเลือกใช้:** หากคุณต้องการให้ **Nginx** เป็นตัวถอดรหัส SSL (SSL Termination) และจัดการ Certificate ไว้ที่เครื่องหน้าด่านนี้เลย จากนั้นค่อยส่งทราฟฟิกแบบ HTTP (Port 80) เข้าไปหา Traefik ใน Cluster

### 📄 ไฟล์คอนฟิก `/etc/nginx/conf.d/nextjs_app.conf` (Layer 7)

```nginx
# กำหนดกลุ่ม Worker Nodes
upstream nextjs_backend {
    server 172.16.33.158:80 max_fails=3 fail_timeout=10s; # Worker 1 (Traefik Port 80)
    server 172.16.33.159:80 max_fails=3 fail_timeout=10s; # Worker 2 (Traefik Port 80)
    keepalive 32; # รักษาการเชื่อมต่อระหว่าง Nginx กับ Traefik ช่วยลด Latency
}

# 1. Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com; # เปลี่ยนเป็น Domain ของคุณ

    return 301 https://$host$request_uri;
}

# 2. HTTPS Server (SSL Termination)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com;

    # --- SSL Best Practices (Modern Profile) ---
    ssl_certificate /etc/nginx/ssl/yourdomain.crt; # พาธไฟล์ Certificate
    ssl_certificate_key /etc/nginx/ssl/yourdomain.key; # พาธไฟล์ Private Key
    
    ssl_protocols TLSv1.2 TLSv1.3; # ปิด TLSv1.0 และ v1.1 ที่ไม่ปลอดภัย
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';

    # SSL Session Optimization
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Security Headers (Best Practices)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # --- Proxy Settings to Traefik ---
    location / {
        proxy_pass http://nextjs_backend;
        
        # ส่งต่อข้อมูลของ Client ที่แท้จริงเข้าไปใน Cluster (สำคัญมากสำหรับ Next.js ในการเช็ค IP)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade"; # รองรับ WebSocket (ถ้า Next.js มีการใช้)
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # เพิ่มขนาดการอัปโหลดไฟล์ (ถ้ามี)
    client_max_body_size 20M;
}

```

---

## 💡 สรุปคำแนะนำในการเลือกใช้ (Decision Guide)

1. **เลือกแนวทางที่ 1 (Layer 4)** หากต้องการให้การทำ SSL/TLS management ไปจบที่ฝั่ง Kubernetes (ให้ **Traefik** หรือ **Cert-Manager** เป็นคนคุม) เพื่อความยืดหยุ่นและลดความซับซ้อนในการอัปเดต SSL บนเครื่อง LB
2. **เลือกแนวทางที่ 2 (Layer 7)** หากทีมเน็ตเวิร์กต้องการควบคุมและตรวจสอบ (Inspect) ทราฟฟิกก่อนถึง Cluster หรือต้องการติดตั้ง SSL Certificate บนเครื่อง Nginx ที่อยู่ด้านนอกเท่านั้น และไม่ต้องการให้ Worker Node แบกรับภาระถอดรหัส SSL