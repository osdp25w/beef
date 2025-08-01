# RabbitMQ 部署指南

安全優化的RabbitMQ部署方案，僅暴露MQTTS加密連接給外部，MQTT和AMQP僅限集群內部使用。

## 🏗️ 架構概覽

| 服務 | 類型 | 端口 | 訪問範圍 | 用途 |
|------|------|------|----------|------|
| **AMQP** | ClusterIP | 5672 | 🏠 集群內部 | 後端服務通信 |
| **MQTT** | NodePort | 31883 | 🌐 外部TCP | IoT設備連接 |
| **MQTTS** | NodePort | 31884 | 🌐 外部TCP+mTLS | IoT設備安全連接 |

**外部訪問地址**: `broker.osdp25w.xyz`

## 📁 文件說明

### 🔧 部署腳本
- `generate-certs.sh` - 生成SSL證書（雙向認證）
- `create-tls-secret.sh` - 建立Kubernetes TLS Secret
- `create-mqtt-user.sh` - 手動創建MQTT用戶

### 🧪 測試腳本  
- `test-connection.sh` - 一鍵測試腳本（安裝依賴+執行測試）
- `test-mqtts-connection.py` - MQTTS雙向認證連線測試
- `requirements.txt` - Python測試依賴

## 🚀 完整部署流程

### 1. 準備工作
```bash
# 進入rabbitmq目錄
cd rabbitmq/

# 確保secrets配置已準備好
ls secrets/staging.yaml
```

### 2. 生成SSL證書（雙向認證）
```bash
bash scripts/generate-certs.sh
```

### 3. 建立TLS Secret
```bash
bash scripts/create-tls-secret.sh
```

### 4. 部署RabbitMQ
```bash
# 回到項目根目錄
cd ..

# 首次部署
helm install rabbitmq ./rabbitmq -f ./rabbitmq/values/staging.yaml -n koala

# 或更新部署
helm upgrade rabbitmq ./rabbitmq -f ./rabbitmq/values/staging.yaml -n koala
```

### 5. 創建MQTT用戶（首次部署後）
```bash
cd rabbitmq/
bash scripts/create-mqtt-user.sh
```

### 6. 測試連線
```bash
bash scripts/test-connection.sh
```

## 🎯 後續部署

重新部署時，用戶數據會自動保留（持久化存儲），只需執行：
```bash
helm upgrade rabbitmq ./rabbitmq -f ./rabbitmq/values/staging.yaml -n koala
```

**無需重新創建用戶** - 管理員和MQTT用戶都會保留！

## 📊 訪問方式

### 📡 MQTT連接
```bash
# 基本MQTT (僅集群內部)
mqtt_host="rabbitmq.koala.svc.cluster.local"
mqtt_port=1883

# 安全MQTTS (外部訪問，雙向認證)
mqtts_host="broker.osdp25w.xyz"
mqtts_port=31884
```

### 🏠 集群內部訪問
```bash
# AMQP連接（koala服務內部使用）
amqp_host="rabbitmq.koala.svc.cluster.local"
amqp_port=5672

# MQTT連接（僅集群內部）
mqtt_host="rabbitmq.koala.svc.cluster.local"
mqtt_port=1883

# Management UI（僅集群內部，無外部訪問）
# 可通過kubectl port-forward訪問：
# kubectl port-forward svc/rabbitmq 15672:15672 -n koala
# 然後訪問: http://localhost:15672
```

## 🔧 證書文件說明

### 📂 生成的證書 (rabbitmq/certs/)

**服務器證書**：
- `ca.pem` - CA根證書
- `server-cert.pem` - 服務器證書
- `server-key.pem` - 服務器私鑰

**客戶端證書（雙向認證）**：
- `client-cert.pem` - 客戶端證書
- `client-key.pem` - 客戶端私鑰

**支援域名/IP**：
- `broker.osdp25w.xyz`
- `rabbitmq.koala.svc.cluster.local`
- `rabbitmq`

### 🧹 清理建議
所有證書文件都是必需的（雙向認證），建議保留全部文件。

## 💻 客戶端範例

### Python MQTT客戶端 (基本連接)
```python
import paho.mqtt.client as mqtt

client = mqtt.Client()
client.username_pw_set("osdp25wmqtt", "YOUR_MQTT_PASSWORD")
client.connect("broker.osdp25w.xyz", 31883, 60)

# 發布消息
client.publish("test/topic", "Hello MQTT!")
```

### Python MQTTS客戶端 (雙向認證)
```python
import paho.mqtt.client as mqtt
import ssl

client = mqtt.Client()
client.username_pw_set("osdp25wmqtt", "YOUR_MQTT_PASSWORD")

# 配置雙向TLS
context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
context.load_verify_locations("rabbitmq/certs/ca.pem")
context.load_cert_chain("rabbitmq/certs/client-cert.pem",
                       "rabbitmq/certs/client-key.pem")
context.check_hostname = False
context.verify_mode = ssl.CERT_REQUIRED

client.tls_set_context(context)
client.connect("broker.osdp25w.xyz", 31884, 60)

# 發布加密消息
client.publish("secure/topic", "Hello MQTTS!")
```

### Python AMQP客戶端 (集群內部)
```python
import pika

# 集群內部連接
credentials = pika.PlainCredentials('admin_user', 'admin_password')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='rabbitmq.koala.svc.cluster.local',
        port=5672,
        credentials=credentials
    )
)

channel = connection.channel()
```

## 🔍 維護指令

### 檢查服務狀態
```bash
kubectl get pods -n koala | grep rabbitmq
kubectl get svc -n koala | grep rabbitmq
```

### 查看用戶列表
```bash
kubectl exec rabbitmq-0 -n koala -- rabbitmqctl list_users
```

### 查看插件狀態
```bash
kubectl exec rabbitmq-0 -n koala -- rabbitmq-plugins list
```

### 檢查日誌
```bash
kubectl logs rabbitmq-0 -n koala --tail=50
```

## ⚠️ 重要注意事項

1. **持久化存儲**: 用戶數據和消息隊列持久化在PersistentVolume中
2. **自動用戶管理**: 管理員用戶通過環境變數自動創建
3. **安全配置**: MQTTS使用雙向認證，提供最高安全級別
4. **內部通信**: AMQP和Management UI僅限集群內部使用，提高安全性
5. **外部訪問**: 僅MQTT/MQTTS對外開放，符合IoT使用場景
6. **證書有效期**: SSL證書有效期365天，需定期更新

## 🆘 故障排除

### MQTT連接失敗
1. 檢查AWS Security Group是否開放31883/31884端口
2. 確認DNS解析：`nslookup broker.osdp25w.xyz`
3. 檢查MQTT插件狀態：`kubectl exec rabbitmq-0 -n koala -- rabbitmq-plugins list | grep mqtt`

### MQTTS證書錯誤
1. 重新生成證書：刪除`certs/`目錄後重新執行證書生成流程
2. 檢查證書掛載：`kubectl describe pod rabbitmq-0 -n koala`

### 用戶認證失敗
1. 檢查用戶是否存在：`kubectl exec rabbitmq-0 -n koala -- rabbitmqctl list_users`
2. 重新創建用戶：`bash scripts/create-mqtt-user.sh` 