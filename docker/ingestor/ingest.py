#!/usr/bin/env python3
"""
ingest.py - 將 MQTT 訊息寫入 TimescaleDB
──────────────────────────────────────
環境變數：
  PG_DSN      = postgresql://user:pass@host:port/dbname
  MQTT_HOST   = mqtt-broker
  MQTT_PORT   = 1883
  MQTT_USER   = iot
  MQTT_PASS   = secretpass
  TOPIC_ROOT  = bike/#             # 可選，不給就預設 bike/#
"""

import asyncio, json, os, asyncpg, paho.mqtt.client as mqtt

# ────────────────────────────────
# 讀設定
# ────────────────────────────────
PG_DSN     = os.getenv("PG_DSN")                       # PostgreSQL 連線字串
MQTT_HOST  = os.getenv("MQTT_HOST", "mqtt-broker")
MQTT_PORT  = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USER  = os.getenv("MQTT_USER")
MQTT_PASS  = os.getenv("MQTT_PASS")
TOPIC_ROOT = os.getenv("TOPIC_ROOT", "bike/#")         # 要訂閱的 topic

# ────────────────────────────────
# 程式主體
# ────────────────────────────────
async def main() -> None:
    pool = await asyncpg.create_pool(PG_DSN)
    loop = asyncio.get_event_loop()

    cli = mqtt.Client(client_id="ingestor")
    cli.username_pw_set(MQTT_USER, MQTT_PASS)

    # 1️⃣ 拿到 CONNACK 之後再 subscribe，避免訂閱被丟掉
    def on_connect(_cli, _ud, _flags, rc, _props=None):
        if rc == 0:
            print("✅ MQTT connected, subscribing…", flush=True)
            cli.subscribe(TOPIC_ROOT, qos=0)
        else:
            print(f"❌ MQTT connect failed rc={rc}", flush=True)

    # 2️⃣ 每收到一筆就寫 DB，並即時列印
    def on_message(_cli, _ud, msg):
        payload = msg.payload.decode() or "{}"
        print(f"📥 {msg.topic} {payload}", flush=True)

        # 非同步寫 DB；失敗只印錯，不讓 callback 垮掉
        async def write():
            try:
                await pool.execute(
                    "INSERT INTO raw_mqtt_messages (received_at, topic, payload) "
                    "VALUES (now(), $1, $2::jsonb)",
                    msg.topic, payload
                )
            except Exception as exc:
                print(f"⚠️  DB insert error: {exc}", flush=True)

        loop.create_task(write())

    cli.on_connect = on_connect
    cli.on_message = on_message

    cli.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    print("🚀 Ingestor started, waiting for CONNACK…", flush=True)
    cli.loop_forever()            # 阻塞執行緒，所有 callback 跑在這條 thread

# ────────────────────────────────
# 進入點
# ────────────────────────────────
if __name__ == "__main__":
    asyncio.run(main())
