# 🚀 Automated Server Setup Script

![Bash](https://img.shields.io/badge/bash-v5.0+-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20(Git%20Bash)-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

## 📖 Overview

A powerful interactive bash script for automated provisioning of new Debian/Ubuntu servers with enterprise-grade security settings. The script guides you through the setup process with interactive prompts, generates all necessary configuration commands, and provides a detailed summary with connection instructions.

## ✨ Features

- 🔐 **Security Hardening**: Disables root SSH access, configures firewall
- 🔑 **Dual Authentication**: Supports both SSH keys and password authentication
- 🛡️ **Brute Force Protection**: Fail2Ban with optimized settings
- 🌐 **Firewall Setup**: UFW configured to allow only specified SSH port
- 📦 **Automatic Updates**: Unattended security updates enabled
- 👤 **User Management**: Creates sudo user with secure password
- 🎨 **Interactive Interface**: Color-coded prompts and status messages
- 📋 **Detailed Reporting**: Generates comprehensive setup summary

### Clone this repository
```bash
git clone https://github.com/ask-sup/fresh_vps_server_config.git
cd server-setup
chmod +x setup-server.sh
./setup-server.sh
```

### Script Logic Flow
```mermaid
graph TD
    A[Start Script] --> B{User Confirmation}
    B -->|Yes| C[Collect Server Details]
    B -->|No| D[Exit]
    
    C --> E[Validate Inputs]
    E --> F[Generate Password if needed]
    F --> G[Create Configuration Script]
    G --> H[Generate Summary Report]
    H --> I[Display Instructions]
    
    I --> J[User Executes Commands on Server]
    J --> K[Server Configuration Applied]
    K --> L[Secure Server Ready]
```
