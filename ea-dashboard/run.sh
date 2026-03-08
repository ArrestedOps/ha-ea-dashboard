#!/usr/bin/with-contenv bashio

# Get config values
export DATABASE_PATH=$(bashio::config 'database_path')
export LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.info "Starting EA Trading Dashboard v5.0..."
bashio::log.info "Database: ${DATABASE_PATH}"
bashio::log.info "Log Level: ${LOG_LEVEL}"

# Start FastAPI
cd /app
exec uvicorn main:app \
    --host 0.0.0.0 \
    --port 8099 \
    --log-level "${LOG_LEVEL}"
