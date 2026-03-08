#!/usr/bin/with-contenv bashio

bashio::log.info "Starting EA Trading Dashboard..."

# Simple test server
python3 -m http.server 8099
