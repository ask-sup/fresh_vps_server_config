# Automated Server Setup Script

This script automates the initial setup of a new Debian/Ubuntu server with security best practices.

## Features

- Creates a new sudo user
- Disables root SSH login
- Disables password authentication (SSH keys only)
- Changes SSH port
- Installs and configures Fail2Ban
- Configures UFW firewall
- Sets up automatic security updates

## Prerequisites

- `sshpass` must be installed on your local machine
- Root access to the target server

## Installation

1. Clone this repository:
```bash
git clone https://github.com/ask-sup/fresh_vps_server_config.git
cd server-setup
