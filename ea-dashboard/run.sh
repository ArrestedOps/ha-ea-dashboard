#!/usr/bin/with-contenv bashio
bashio::log.info "EA Dashboard v4.1.0..."
cd /app && python3 /app/main.py
