## prompt template
```
Role: คุณคือผู้เชียวชาญด้านการเขียน prompt
Task: ออกแบบวิธีเขียน prompt เป็นภาษาอังกฤษ สั่งให้ claude code ไปเพิ่ม swagger
Context:
- dol-api-gateway - gateway (nestjs)
- dol-auth-service - microservice (nestjs)
```

## DevOpts prompt
```
Role: คุณคือผู้เชียวชาญด้านการเขียน DevOps
Task: แนวทางการทำ logging ต้องเก็บ log อะไรบ้าง (best practices) เครื่อง 172.16.33.162 ติดตั้ง postgresql, prometheus, grafana, loki  อยากให้พยายามใช้ในสิ่งที่มีอยู่แล้ว ไม่ต้องลงอะไรเพิ่มโดยไม่จำเป็น
Context:
- stack มี rke2, nextjs, harbor, github, rancher, traefik, prometheus, grafana, loki
- เครื่อง runner (172.16.33.163) สามารถออกเน็ตได้เครื่องนี้เครื่องเดียว
- เครื่อง nginx (172.16.33.156) load balance เฉพาะเครื่อง workers อยู่นอก cluster
- เครื่อง master (172.16.33.157)
- เครื่อง workeruat01 (172.16.33.158)
- เครื่อง workeruat02 (172.16.33.159) 
- เครื่อง logging, monitoring (172.16.33.162)
```

# Role
You are a DevOps expert.
# Instructions
จากขั้นตอนการทำ ci อยากได้วิธีเขียน workflow และการจัดการเวอร์ชั่น พวกไฟล์ deployment.yaml, value.yaml OCI Helm Charts บน Harbor 
# Context
- The stack has rke2, nextjs, harbor, github, traefik, rancher, prometheus, grafana, loki.
- เครื่อง runner ip 172.16.33.163
- เครื่อง nginx ip 172.16.33.156 load balance เฉพาะเครื่อง workers อยู่นอก cluster
- เครื่อง master ip 172.16.33.157
- เครื่อง workeruat01 ip 172.16.33.158
- เครื่อง workeruat02 ip 172.16.33.159
- เครื่อง logging, monitoring ip 172.16.33.162
- 


## Linux prompt
```
Role: คุณคือผู้เชี่ยวชาญด้าน bash script
Task: อยากได้ตัวอย่างเช็คว่ามี docker image นี้อยู่ไหม ถ้ามีให้ echo ข้อความ
Context:
- ubuntu server 24.04

Role: You are a Ubuntu linux expert.
Task: การสร้าง whitelist สำหรับ Outbound
Context:
- ubuntu server 24.04

```
