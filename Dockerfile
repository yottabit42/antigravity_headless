FROM debian:testing

# Set environment variables for unattended installations, UTF-8 encoding, and remote simulation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    SSH_CONNECTION="127.0.0.1 0 127.0.0.1 22"

# Install minimal base tools, cron, and tmux
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    ca-certificates \
    curl \
    wget \
    gnupg \
    cron \
    sudo \
    procps \
    git \
    nano \
    vim-tiny \
    jq \
    tar \
    gzip \
    locales \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Configure APT non-interactive defaults
RUN echo 'Dpkg::Options { "--force-confdef"; "--force-confold"; };' > /etc/apt/apt.conf.d/99noninteractive

# Install Google Antigravity CLI (agy) system-wide
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin \
    && chmod +x /usr/local/bin/agy

# Create dedicated non-root user 'antigravity' with passwordless sudo access
RUN groupadd -g 1000 antigravity \
    && useradd -u 1000 -g antigravity -m -s /bin/bash antigravity \
    && echo "antigravity ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/antigravity \
    && chmod 0440 /etc/sudoers.d/antigravity

# Configure cron job for @reboot and 02:00 daily maintenance
RUN cat <<'EOF' > /etc/cron.d/apt-auto-upgrade
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DEBIAN_FRONTEND=noninteractive

@reboot root apt update && apt dist-upgrade -y && apt autoremove -y && apt clean >> /var/log/apt-cron.log 2>&1
0 2 * * * root apt update && apt dist-upgrade -y && apt autoremove -y && apt clean >> /var/log/apt-cron.log 2>&1
EOF
RUN chmod 0644 /etc/cron.d/apt-auto-upgrade \
    && chown root:root /etc/cron.d/apt-auto-upgrade \
    && touch /var/log/apt-cron.log \
    && chmod 0666 /var/log/apt-cron.log

# Configure workspace directory
WORKDIR /workspace
RUN chown -R antigravity:antigravity /workspace

# Configure tmux globally: dynamic auto-resizing, mouse support, and 256color
RUN cat <<'EOF' > /etc/tmux.conf
set -g default-terminal "xterm-256color"
set -g mouse on
set -g window-size latest
set -g aggressive-resize on
set -g history-limit 50000
set -s escape-time 10
EOF

# Convenient attach helper script & instructions banner in .bashrc
RUN printf '#!/bin/bash\nexec tmux attach -t agy -d\n' > /usr/local/bin/agy-attach \
    && chmod +x /usr/local/bin/agy-attach \
    && echo 'echo -e "\n=== Antigravity Instance is running in background ==="' >> /root/.bashrc \
    && echo 'echo -e "To attach and control it, run: \033[1;32magy-attach\033[0m (or \033[1;32mtmux attach -d\033[0m)"' >> /root/.bashrc \
    && echo 'echo -e "To detach without stopping it, press: \033[1;33mCtrl+b\033[0m then \033[1;33md\033[0m\n"' >> /root/.bashrc

# Create entrypoint script managing cron and the persistent dynamic tmux session for agy
RUN cat <<'EOF' > /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# Remove stale pid files
rm -f /var/run/crond.pid /run/crond.pid /var/run/cron.pid /run/cron.pid

# Ensure cron log exists
touch /var/log/apt-cron.log
chmod 0666 /var/log/apt-cron.log

# 1. Start the cron daemon
if [ "$(id -u)" -eq 0 ]; then
    cron
else
    sudo cron || sudo service cron start || true
fi

# 2. Start agy --remote-control in a background tmux session named 'agy'
tmux new-session -d -s agy "agy --remote-control"

echo "===================================================================="
echo "Google Antigravity CLI started in tmux session 'agy'"
echo "Attach via: 'docker exec -it antigravity-remote agy-attach'"
echo "Or in Dockge web terminal by running: 'agy-attach' or 'tmux attach -d'"
echo "===================================================================="

# Keep container running and stream logs
exec "$@"
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["tail", "-f", "/var/log/apt-cron.log"]
