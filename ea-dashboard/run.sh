#!/usr/bin/with-contenv bashio
bashio::log.info "EA Trading Dashboard v3.2.0 starting..."
cd /app
python3 /app/main.py
