#!/bin/bash

read -p "Enter service name (with or without .service): " INPUT_NAME

# Strip .service if present
SERVICE_NAME=$(echo "$INPUT_NAME" | sed 's/\.service$//')
RESTART_SERVICE_NAME="${SERVICE_NAME}-restart"
TIMER_NAME="${SERVICE_NAME}.timer"

# Create restart service
cat <<EOF | sudo tee /etc/systemd/system/${RESTART_SERVICE_NAME}.service > /dev/null
[Unit]
Description=Restart ${SERVICE_NAME}.service

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart ${SERVICE_NAME}.service
EOF

# Create timer
cat <<EOF | sudo tee /etc/systemd/system/${TIMER_NAME} > /dev/null
[Unit]
Description=Restart ${SERVICE_NAME}.service every hour on the hour

[Timer]
OnCalendar=hourly
Persistent=true
Unit=${RESTART_SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable timer
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now ${TIMER_NAME}

# Show timer status
systemctl list-timers | grep ${SERVICE_NAME}
