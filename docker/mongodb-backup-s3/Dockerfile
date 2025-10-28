# MongoDB Backup/Restore Container
# Provides backup and restore functionality for MongoDB to S3-compatible storage
ARG MONGODB_VERSION=8.0
FROM mongo:${MONGODB_VERSION}

LABEL maintainer="rarup1"
LABEL description="MongoDB backup and restore to S3-compatible storage"
LABEL version="0.1.0"

# Install AWS CLI and other required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        ca-certificates \
        curl \
        jq \
    && pip3 install --no-cache-dir awscli --break-system-packages \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY src/env.sh /usr/local/bin/env.sh
COPY src/backup.sh /usr/local/bin/backup.sh
COPY src/restore.sh /usr/local/bin/restore.sh
COPY src/run.sh /usr/local/bin/run.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/*.sh

# Create working directory
WORKDIR /backup

# Set default mode to backup
ENV MODE=backup

# Run as non-root user for security (MongoDB user from base image)
USER mongodb

# Entrypoint
ENTRYPOINT ["/usr/local/bin/run.sh"]
