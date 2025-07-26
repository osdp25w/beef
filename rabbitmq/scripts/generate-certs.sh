#!/bin/bash
# RabbitMQ MQTT SSL 自簽名證書生成腳本

echo "🔒 生成RabbitMQ MQTT SSL證書..."

# 創建證書目錄
mkdir -p certs
cd certs

# 1. 生成CA私鑰
openssl genrsa -out ca-key.pem 4096

# 2. 生成CA證書
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/C=TW/ST=Taiwan/L=Taipei/O=OSDP25W/OU=IT/CN=OSDP25W-CA"

# 3. 生成服務器私鑰
openssl genrsa -out server-key.pem 4096

# 4. 生成服務器證書請求
openssl req -subj "/C=TW/ST=Taiwan/L=Taipei/O=OSDP25W/OU=IT/CN=broker.osdp25w.xyz" -sha256 -new -key server-key.pem -out server.csr

# 5. 創建擴展文件 (支援域名和IP)
cat > server-extfile.cnf <<EOF
subjectAltName = DNS:broker.osdp25w.xyz,DNS:rabbitmq,DNS:rabbitmq.koala.svc.cluster.local,IP:172.31.19.107
extendedKeyUsage = serverAuth
EOF

# 6. 生成服務器證書
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca-key.pem -out server-cert.pem -extfile server-extfile.cnf -CAcreateserial

# 7. 生成客戶端私鑰
openssl genrsa -out client-key.pem 4096

# 8. 生成客戶端證書請求
openssl req -subj "/C=TW/ST=Taiwan/L=Taipei/O=OSDP25W/OU=IT/CN=mqtt-client" -new -key client-key.pem -out client.csr

# 9. 創建客戶端擴展文件
echo extendedKeyUsage = clientAuth > client-extfile.cnf

# 10. 生成客戶端證書
openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca-key.pem -out client-cert.pem -extfile client-extfile.cnf -CAcreateserial

# 清理臨時文件
rm -f server.csr client.csr server-extfile.cnf client-extfile.cnf

echo "✅ 證書生成完成！"

# 清理不必要的中間文件
echo "🧹 清理中間文件..."
rm -f ca.srl

echo "📁 證書文件位置:"
echo "   CA證書: $(pwd)/ca.pem"
echo "   服務器證書: $(pwd)/server-cert.pem"
echo "   服務器私鑰: $(pwd)/server-key.pem"
echo "   客戶端證書: $(pwd)/client-cert.pem"
echo "   客戶端私鑰: $(pwd)/client-key.pem"

echo ""
echo "🔧 下一步: 運行以下命令建立TLS Secret:"
echo "   bash scripts/create-tls-secret.sh" 