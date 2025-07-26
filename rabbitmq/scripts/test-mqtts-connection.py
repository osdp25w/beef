#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
RabbitMQ MQTTS 連線測試
專門測試雙向認證MQTTS外部連接
"""

import time
import ssl
import os
import yaml
from datetime import datetime
try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("❌ 需要安裝 paho-mqtt: pip install paho-mqtt")
    exit(1)

def load_secrets_config():
    """從secrets/staging.yaml讀取配置"""
    secrets_file = "../secrets/staging.yaml"
    try:
        with open(secrets_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        secret_env = config.get('rabbitmq', {}).get('secretEnv', {})
        
        return {
            'mqtt_user': secret_env.get('MQTT_USERNAME'),
            'mqtt_pass': secret_env.get('MQTT_PASSWORD'),
            'admin_user': secret_env.get('RABBITMQ_DEFAULT_USER'),
            'admin_pass': secret_env.get('RABBITMQ_DEFAULT_PASS')
        }
    except Exception as e:
        print(f"❌ 讀取配置失敗: {e}")
        print(f"💡 請確保 {secrets_file} 文件存在且格式正確")
        return None

# 載入配置
print("📖 讀取配置...")
secrets = load_secrets_config()
if not secrets:
    print("❌ 無法載入配置，退出測試")
    exit(1)

# 驗證必要的配置值
required_keys = ['mqtt_user', 'mqtt_pass', 'admin_user', 'admin_pass']
missing_keys = [key for key in required_keys if not secrets.get(key)]

if missing_keys:
    print(f"❌ 缺少必要配置: {missing_keys}")
    print("💡 請檢查 secrets/staging.yaml 中的配置")
    exit(1)

print("✅ 配置載入成功")

# 配置信息（從secrets讀取）
MQTT_USER = secrets['mqtt_user']
MQTT_PASS = secrets['mqtt_pass']
ADMIN_USER = secrets['admin_user']
ADMIN_PASS = secrets['admin_pass']

EXTERNAL_HOST = "broker.osdp25w.xyz"
MQTTS_PORT = 31884     # NodePort (雙向認證)

def log_message(message):
    """記錄帶時間戳的消息"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def test_mqtt_basic():
    """測試基本MQTT連接（已禁用 - 僅限集群內部）"""
    print("🔌 測試 MQTT 基本連接...")
    print("⚠️  MQTT已改為集群內部訪問，跳過外部測試")
    print("💡 集群內部可使用: rabbitmq.koala.svc.cluster.local:1883")
    return True

def test_mqtts_mutual_auth():
    """測試MQTTS雙向認證連接"""
    print("\n🔐 測試 MQTTS 雙向認證連接...")
    
    # 檢查證書文件
    cert_files = [
        "../certs/ca.pem",
        "../certs/client-cert.pem",
        "../certs/client-key.pem"
    ]
    
    for cert_file in cert_files:
        if not os.path.exists(cert_file):
            log_message(f"❌ 證書文件不存在: {cert_file}")
            return False
    
    log_message("✅ 證書文件檢查通過")
    
    received_messages = []
    connection_success = False
    
    def on_connect(client, userdata, flags, rc):
        nonlocal connection_success
        if rc == 0:
            connection_success = True
            log_message("✅ MQTTS雙向認證連接成功!")
            client.subscribe("test/ssl", qos=1)
        else:
            log_message(f"❌ MQTTS連接失敗，返回碼: {rc}")
            
    def on_message(client, userdata, msg):
        message = msg.payload.decode('utf-8')
        received_messages.append(message)
        log_message(f"📨 收到SSL消息: {message}")
        
    try:
        client = mqtt.Client(client_id=f"test_ssl_{int(time.time())}")
        client.username_pw_set(MQTT_USER, MQTT_PASS)
        client.on_connect = on_connect
        client.on_message = on_message
        
        # 配置雙向TLS
        log_message("🔧 配置雙向TLS認證...")
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        context.load_verify_locations("../certs/ca.pem")
        context.load_cert_chain("../certs/client-cert.pem",
                               "../certs/client-key.pem")
        context.check_hostname = False  # 自簽名證書
        context.verify_mode = ssl.CERT_REQUIRED
        client.tls_set_context(context)
        
        log_message(f"連接到 {EXTERNAL_HOST}:{MQTTS_PORT} (SSL)")
        client.connect(EXTERNAL_HOST, MQTTS_PORT, 60)
        client.loop_start()
        
        # 等待連接
        time.sleep(3)
        
        if connection_success:
            # 發送測試消息
            test_message = f"MQTTS mutual auth test at {datetime.now()}"
            result = client.publish("test/ssl", test_message, qos=1)
            log_message(f"📤 發送SSL消息: {test_message}")
            
            # 等待消息接收
            time.sleep(3)
            
            if received_messages:
                log_message("✅ MQTTS雙向認證測試成功!")
                return True
            else:
                log_message("⚠️  未收到發送的消息")
                return False
        else:
            return False
            
    except Exception as e:
        log_message(f"❌ MQTTS測試失敗: {e}")
        return False
    finally:
        try:
            client.loop_stop()
            client.disconnect()
        except:
            pass

def main():
    print("🐰 RabbitMQ MQTTS 專項測試")
    print("=" * 50)
    print("📋 測試範圍: MQTTS雙向認證外部連接")
    print("⚠️  僅測試MQTTS，MQTT已改為集群內部訪問")
    print("=" * 50)
    
    # 測試MQTTS雙向認證
    log_message("🚀 開始測試...")
    success = test_mqtts_mutual_auth()
    
    # 顯示結果
    print("\n" + "=" * 50)
    log_message("📊 測試結果摘要:")
    print("=" * 50)
    
    status = "✅ 成功" if success else "❌ 失敗"
    print(f"{status} MQTTS雙向認證")
    
    print("=" * 50)
    print(f"📈 成功: {1 if success else 0}/1 個測試")
    
    if success:
        print("🎉 MQTTS測試通過！雙向認證配置正確！")
    else:
        print("🚨 MQTTS測試失敗，請檢查證書配置和網路連接")

if __name__ == "__main__":
    main() 