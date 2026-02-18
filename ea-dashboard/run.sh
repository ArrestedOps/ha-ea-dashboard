#!/usr/bin/with-contenv bashio
bashio::log.info "EA Dashboard v4.7.2 starting..."
cd /app && python3 /app/main.py
