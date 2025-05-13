FROM python:3.11-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    docker.io \
    curl \
    bc \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Flask
RUN pip install flask

# Create directory for scripts
WORKDIR /app

# Copy monitoring script and dashboard
COPY monitor_container.sh /app/monitor_container.sh
COPY logrotate.sh /app/logrotate.sh
COPY dashboard.py /app/
COPY crontab.txt /etc/crontabs/root

# Make scripts executable
RUN chmod +x monitor_container.sh dashboard.py logrotate.sh

# Create log directory
RUN mkdir -p /var/log

# Default command - run both dashboard and monitor
CMD ["sh", "crond", "-f", "-l", "8", "-c", "python3 dashboard.py & ./monitor_container.sh live"]
