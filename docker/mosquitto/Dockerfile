# mosquitto/Dockerfile
FROM eclipse-mosquitto:2.0

###############################################################################
# 1) 先切回 root，才有權限做 chown / chmod / passwd 相關動作
###############################################################################
USER root

ARG MQTT_USER
ARG MQTT_PASS

# 設定檔 & ACL 先用 root 複製進去，稍後再調權限
COPY mosquitto.conf /mosquitto/config/mosquitto.conf
COPY acl            /mosquitto/config/acl

RUN set -eux; \
    # 建立帳密檔
    mosquitto_passwd -c -b /mosquitto/config/passwd "$MQTT_USER" "$MQTT_PASS"; \
    # 把敏感檔交給 mosquitto 使用者並收緊權限
    chown mosquitto:mosquitto /mosquitto/config/acl /mosquitto/config/passwd; \
    chmod 640                /mosquitto/config/acl /mosquitto/config/passwd

###############################################################################
# 2) 切回非特權使用者執行 broker
###############################################################################
USER mosquitto
