#!/usr/bin/with-contenv bashio
bashio::log.info "EA Dashboard v4.7.0 starting..."
cd /app && python3 /app/main.py
