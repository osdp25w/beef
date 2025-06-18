CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS raw_mqtt_messages (
    id           BIGSERIAL,
    received_at  TIMESTAMPTZ NOT NULL,
    topic        TEXT        NOT NULL,
    payload      JSONB       NOT NULL
);

SELECT create_hypertable(
    'raw_mqtt_messages',
    'received_at',
    if_not_exists => TRUE
);
