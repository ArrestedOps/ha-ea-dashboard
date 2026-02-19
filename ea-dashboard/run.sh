#!/usr/bin/with-contenv bashio
LOG_LEVEL=$(bashio::config 'log_level')
bashio::log.info "EA Dashboard v4.12.0 starting (log_level: ${LOG_LEVEL})..."
export LOG_LEVEL
cd /app && python3 /app/main.py
