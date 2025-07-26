#!/bin/bash

# 建立RabbitMQ雙向認證TLS Secret (使用kubectl create secret)

if [ ! -d "certs" ]; then
    echo "❌ 證書目錄不存在，請先運行 bash scripts/generate-certs.sh"
    exit 1
fi

echo "🔧 建立RabbitMQ TLS Secret (雙向認證)..."

# 檢查是否已存在secret，如果存在就刪除
kubectl get secret rabbitmq-tls -n koala >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "🗑️  刪除已存在的secret..."
    kubectl delete secret rabbitmq-tls -n koala
fi

# 建立新的TLS secret（匹配Release名稱: rabbitmq-tls）
# 包含服務器證書和客戶端證書 (雙向認證)
kubectl create secret generic rabbitmq-tls \
    --from-file=tls.crt=certs/server-cert.pem \
    --from-file=tls.key=certs/server-key.pem \
    --from-file=ca.crt=certs/ca.pem \
    --from-file=client.crt=certs/client-cert.pem \
    --from-file=client.key=certs/client-key.pem \
    -n koala

if [ $? -eq 0 ]; then
    echo "✅ RabbitMQ TLS Secret 建立成功！"
    echo ""
    echo "📋 Secret 內容:"
    kubectl describe secret rabbitmq-tls -n koala
    echo ""
    echo "🔧 下一步:"
    echo "   1. 確認 StatefulSet 已正確配置引用此Secret"
    echo "   2. 執行部署: helm upgrade rabbitmq ./rabbitmq -f ./rabbitmq/values/staging.yaml -n koala"
else
    echo "❌ Secret 建立失敗！"
    exit 1
fi 