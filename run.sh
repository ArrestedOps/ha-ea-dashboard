#!/usr/bin/with-contenv bashio
bashio::log.info "EA Trading Dashboard v2.0 starting..."
cd /app
python3 /app/main.py
