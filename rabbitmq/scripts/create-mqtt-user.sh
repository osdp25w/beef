#!/bin/bash

# 手動創建RabbitMQ MQTT用戶腳本
# 使用方法: bash create-mqtt-user.sh

set -e

echo "🐰 手動創建RabbitMQ MQTT用戶"
echo "=================================================="

# 進入腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 讀取配置
echo "📖 讀取配置..."
if [ ! -f "../secrets/staging.yaml" ]; then
    echo "❌ 錯誤: secrets/staging.yaml 不存在"
    exit 1
fi

# 使用Python來解析YAML（因為bash不原生支持YAML）
python3 -c '
import yaml
import sys

try:
    with open("../secrets/staging.yaml", "r") as f:
        config = yaml.safe_load(f)
    
    secret_env = config.get("rabbitmq", {}).get("secretEnv", {})
    
    mqtt_user = secret_env.get("MQTT_USERNAME", "")
    mqtt_pass = secret_env.get("MQTT_PASSWORD", "")
    admin_user = secret_env.get("RABBITMQ_DEFAULT_USER", "")
    admin_pass = secret_env.get("RABBITMQ_DEFAULT_PASS", "")
    
    print(f"MQTT_USERNAME={mqtt_user}")
    print(f"MQTT_PASSWORD={mqtt_pass}")
    print(f"ADMIN_USER={admin_user}")
    print(f"ADMIN_PASS={admin_pass}")
    
except Exception as e:
    print(f"❌ 讀取配置失敗: {e}", file=sys.stderr)
    sys.exit(1)
' > /tmp/rabbitmq_config.env

# 載入配置變數
source /tmp/rabbitmq_config.env
rm -f /tmp/rabbitmq_config.env

# 驗證配置
if [ -z "$MQTT_USERNAME" ] || [ -z "$MQTT_PASSWORD" ] || [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASS" ]; then
    echo "❌ 配置不完整，請檢查 secrets/staging.yaml"
    exit 1
fi

echo "✅ 配置載入成功"
echo "📋 將創建MQTT用戶: $MQTT_USERNAME"
echo "💡 管理員用戶會通過環境變數自動創建"

# 檢查RabbitMQ pod是否運行
echo ""
echo "🔍 檢查RabbitMQ狀態..."
if ! kubectl get pod rabbitmq-0 -n koala --no-headers 2>/dev/null | grep -q "Running"; then
    echo "❌ RabbitMQ pod未運行，請先部署RabbitMQ"
    exit 1
fi

echo "✅ RabbitMQ正在運行"

echo ""
echo "🚀 開始創建MQTT用戶..."
echo "=================================================="

# 創建MQTT用戶（如果不存在）
echo "📡 創建MQTT用戶: $MQTT_USERNAME"
kubectl exec rabbitmq-0 -n koala -- bash -c "
    # 檢查用戶是否已存在
    if rabbitmqctl list_users | grep -q '^$MQTT_USERNAME'; then
        echo '✅ MQTT用戶已存在: $MQTT_USERNAME'
    else
        echo '📝 創建MQTT用戶: $MQTT_USERNAME'
        rabbitmqctl add_user '$MQTT_USERNAME' '$MQTT_PASSWORD'
        rabbitmqctl set_permissions '$MQTT_USERNAME' '.*' '.*' '.*'
        echo '✅ MQTT用戶創建成功: $MQTT_USERNAME'
    fi
"

echo ""
echo "=================================================="
echo "📊 當前用戶列表:"
kubectl exec rabbitmq-0 -n koala -- rabbitmqctl list_users

echo ""
echo "🎉 MQTT用戶創建完成！"
echo ""
echo "💡 提示:"
echo "   - 用戶數據已持久化，重啟不會丟失"  
echo "   - 管理員用戶由環境變數自動創建"
echo "   - 通過 https://broker.osdp25w.xyz 登入管理界面" 