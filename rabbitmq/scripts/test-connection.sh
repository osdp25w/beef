#!/bin/bash

# RabbitMQ MQTTS 連線測試腳本
# 使用方法: bash test-connection.sh

set -e

echo "🐰 RabbitMQ MQTTS 連線測試"
echo "=================================================="

# 檢查Python3是否安裝
if ! command -v python3 &> /dev/null; then
    echo "❌ 錯誤: python3 未安裝，請先安裝Python 3"
    exit 1
fi

# 檢查pip3是否安裝
if ! command -v pip3 &> /dev/null; then
    echo "❌ 錯誤: pip3 未安裝，請先安裝pip3"
    exit 1
fi

# 進入腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📍 當前目錄: $SCRIPT_DIR"

# 檢查requirements.txt是否存在
if [ ! -f "requirements.txt" ]; then
    echo "❌ 錯誤: requirements.txt 不存在"
    exit 1
fi

# 檢查測試腳本是否存在
if [ ! -f "test-mqtts-connection.py" ]; then
    echo "❌ 錯誤: test-mqtts-connection.py 不存在"
    exit 1
fi

# 檢查證書是否存在
if [ ! -d "../certs" ]; then
    echo "⚠️  警告: 證書目錄不存在，MQTTS測試可能失敗"
    echo "💡 請先運行: bash generate-certs.sh && bash create-tls-secret.sh"
fi

# 安裝Python依賴
echo "📦 安裝Python依賴..."
pip3 install -r requirements.txt --quiet

if [ $? -ne 0 ]; then
    echo "❌ 錯誤: 依賴安裝失敗"
    exit 1
fi

echo "✅ 依賴安裝完成"

# 執行測試
echo ""
echo "🚀 開始執行連線測試..."
echo "=================================================="

python3 test-mqtts-connection.py

if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "🎉 測試執行完成！"
else
    echo ""
    echo "=================================================="
    echo "❌ 測試執行失敗！"
    exit 1
fi 