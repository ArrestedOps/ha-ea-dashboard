ARG BUILD_FROM
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install requirements
RUN apk add --no-cache \
    python3 \
    py3-pip \
    python3-dev \
    gcc \
    musl-dev

# Copy requirements and install Python packages
COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

# Copy application
COPY rootfs /

# Make run.sh executable
RUN chmod a+x /run.sh

# Labels
LABEL \
    io.hass.name="EA Trading Dashboard" \
    io.hass.description="MetaTrader Expert Advisor Performance Tracking" \
    io.hass.version="5.0.0" \
    io.hass.type="addon" \
    io.hass.arch="armhf|aarch64|i386|amd64|armv7"

CMD ["/run.sh"]
