ARG BUILD_FROM
FROM $BUILD_FROM

# Install requirements
RUN apk add --no-cache \
    python3 \
    py3-pip

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
