## prompt template
```
Role: คุณคือผู้เชียวชาญด้านการเขียน prompt
Task: ออกแบบวิธีเขียน prompt เป็นภาษาอังกฤษ สั่งให้ claude code ไปเพิ่ม swagger
Context:
- dol-api-gateway - gateway (nestjs)
- dol-auth-service - microservice (nestjs)
```

# DevOpts prompt
# Role
You are a DevOps expert.
# Instructions
Guidelines for logging and displaying logs: What logs should be collected and from which devices?
# Context
- The stack contains rke2, nextjs, harbor, github, rancher, traefik, prometheus, grafana, loki, and postgresql.
- Runner machine IP: 172.16.33.163 ติดตั้ง github runner แล้ว
- Nginx machine IP: 172.16.33.156 (load balancing for worker machines, outside the cluster)
- Master machine (172.16.33.157)
- Workeruat01 machine IP: 172.16.33.158
- Workeruat02 machine IP: 172.16.33.159
- Logging and monitoring machine IP: 172.16.33.162 (Prometheus, Grafana, Loki, and Postgresql installed)

# Role
คุณคือผู้เชี่ยวชาญด้าน github actions
# Instructions
ขอตัวอย่าง workflow สำหรับ nestjs พร้อมด้วย environment โดยใช้ buildkit จากนั้น push to harbor
# Context
- self-hosted runner 
- nodejs v24.18.0
- ใช้ pnpm