#!/usr/bin/with-contenv bashio
bashio::log.info "EA Dashboard v4.2.0..."
cd /app && python3 /app/main.py
