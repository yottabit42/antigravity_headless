# Google Antigravity Remote Control Docker Environment
A lightweight Debian Testing (`debian:testing`) Docker container for running the [Google Antigravity](https://antigravity.google) CLI (`agy`) with Remote Control enabled 24/7, full `apt` package management capabilities, persistent `tmux` session control, and automated cron maintenance.
---
## Features
- **Base Image**: Debian Testing (`debian:testing`) with modern `glibc`, system libraries, and standard tools.
- **Google Antigravity CLI (`agy`)**: Pre-installed system-wide in `/usr/local/bin/agy`.
- **Persistent `tmux` Session**:
  - `agy --remote-control` runs continuously in a dedicated background `tmux` session named `agy`.
  - Attach at any time to control, view prompts, or run slash commands.
  - Safe detaching (<kbd>Ctrl+b</kbd> then <kbd>d</kbd>) leaves the agent and Remote Control running uninterrupted in the background.
  - Auto-adapts to terminal sizes with `window-size latest` and mouse navigation enabled.
- **Package Management via `apt`**:
  - Full access to Debian package repositories.
  - Pre-configured `DEBIAN_FRONTEND=noninteractive` and non-interactive `dpkg` defaults to prevent stalls during automated package installations.
  - Full `root` access and passwordless `sudo` configured for the `antigravity` user.
- **Automated Cron Maintenance**:
  - Pre-configured in `/etc/cron.d/apt-auto-upgrade`:
    ```bash
    apt update && apt dist-upgrade -y && apt autoremove -y && apt clean
    ```
  - Runs **on every reboot / container startup** (`@reboot`) and **at 02:00 overnight every day** (`0 2 * * *`).
  - Output is logged to `/var/log/apt-cron.log`.
- **Dockge & NAS Optimized**:
  - Fully self-contained `Dockerfile` (requires no separate auxiliary host scripts).
  - Designed for bind-mounting persistent host paths (e.g. `/mnt/vol1/docker/...`).
---
## Directory & File Structure
```text
antigravity-docker/
├── compose.yaml          # Docker Compose service definition
├── Dockerfile            # Self-contained build definition
├── README.md             # Documentation
└── workspace/            # Default project files mount (or your host workspace path)
```
---
## Configuration (`compose.yaml`)

```yaml
services:
  antigravity:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: antigravity-remote
    restart: unless-stopped
    working_dir: /workspace
    volumes:
      # Mount host workspace for project files
      - ${WORKSPACE}:/workspace
      # Persist Antigravity authentication credentials, tokens, and agent sessions
      - ${GEMINI}:/root/.gemini
      # Persist Antigravity configuration
      - ${CONFIG}:/root/.config
    environment:
      - DEBIAN_FRONTEND=noninteractive
      - TZ=${TZ}
networks: {}
```
> [!IMPORTANT]
> Ensure the mapped host directories exist on your host server before starting, e.g. (replace these paths with the variables in `compose.yaml`):
> ```bash
> mkdir -p /mnt/vol1/docker/data/antigravity_workspaces \
>          /mnt/vol1/docker/config/antigravity/gemini \
>          /mnt/vol1/docker/config/antigravity/config
> ```
---
## Deployment
### In Dockge
1. Create a new stack named `antigravity` in Dockge.
2. Paste the `compose.yaml` content into the Dockge editor.
3. Save the `Dockerfile` in the stack's folder (typically `/opt/stacks/antigravity/Dockerfile` or your custom Dockge stacks directory).
4. Click **Deploy**.
### Via Command Line / SSH
```bash
docker compose up -d --build
```
---
## How to Attach and Control the Running Session
Because `agy` runs inside a background `tmux` session, you can attach to it at any time without creating conflicting second instances.
### Option 1: From Host Terminal via SSH (Recommended - Full Screen)
Connecting via standard SSH gives you a true full-screen terminal with native scrolling, mouse support, and arrow key navigation:
```bash
docker exec -it antigravity-remote agy-attach
```
*(Or directly: `docker exec -it antigravity-remote tmux attach -d`)*
> [!NOTE]
> Using `docker exec` works from **any directory** on your server. Unlike `docker compose exec`, it does not require you to be in the folder containing `compose.yaml`.
### Option 2: From Dockge Web Console
1. In the Dockge UI, click the **Terminal** / **Bash** button on the `antigravity-remote` container.
2. *(Optional)* If the Dockge terminal window looks cramped, expand its column size:
   ```bash
   stty cols 120 rows 35
   ```
3. Attach to the running session:
   ```bash
   agy-attach
   ```
### How to Detach Safely
To disconnect from the session without stopping the agent or the container:
- Press <kbd>Ctrl+b</kbd>, release both keys, then press <kbd>d</kbd>.
- The Antigravity agent and Remote Control remain active 24/7 in the background.
---

## Authentication & Remote Control
To use the Remote Control web dashboard at **[https://antigravity.google.com](https://antigravity.google.com)**, the instance must be linked to a personal Google Account (`@gmail.com`). API keys (`GEMINI_API_KEY`) allow model inference but do not provision a cloud reverse-tunnel proxy.
### Initial Sign-In Options:
#### Authenticate Directly Inside the Container
1. Attach to the container:
   ```bash
   docker exec -it antigravity-remote agy-attach
   ```
2. In the terminal, type:
   ```bash
   tmux attach
   ```
   and press **Enter**.
3. The application will prompt you to set the terminal scheme, and then login.
4. Copy and paste the URL into your browser, sign in, and approve permissions.
5. Detach safely with <kbd>Ctrl+b</kbd> then <kbd>d</kbd>.

Then visit **[https://antigravity.google.com](https://antigravity.google.com)** to manage and interact with your agents from any browser or mobile device.
---

## Installing Utilities via `apt`
You can install any packages or compilers required for your projects at any time. You can also ask Antigravity to install necessary tools itself.
### From Host Terminal:
```bash
docker exec -it antigravity-remote apt update
docker exec -it antigravity-remote apt install -y python3-pip build-essential htop
```
### From Inside Container Shell:
```bash
docker exec -it antigravity-remote bash
apt update && apt install -y <package-name>
```
---
## Automated Cron Maintenance
The reboot and daily upgrade cron job is located at `/etc/cron.d/apt-auto-upgrade`:
```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DEBIAN_FRONTEND=noninteractive
@reboot root apt update && apt dist-upgrade -y && apt autoremove -y && apt clean >> /var/log/apt-cron.log 2>&1
0 2 * * * root apt update && apt dist-upgrade -y && apt autoremove -y && apt clean >> /var/log/apt-cron.log 2>&1
```
- **Reboot Maintenance**: When the container boots up, `cron` initializes and immediately executes the `@reboot` job.
- **Daily Maintenance**: Automatically runs every morning at 02:00.
- **View Maintenance Logs**:
  ```bash
  docker exec -it antigravity-remote tail -f /var/log/apt-cron.log
  ```
