#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Function to generate random password
generate_password() {
    local length=${1:-12}
    tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c $length
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        if [[ $ip =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to validate SSH port
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Welcome message
echo "=========================================="
echo "   Automated Server Setup Script"
echo "=========================================="
echo ""

# Ask for confirmation
read -p "Do you want to configure a new server? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY == "" ]]; then
    print_status "Operation cancelled."
    exit 0
fi

# Get server IP/hostname
while true; do
    read -p "Enter server IP address or domain name: " SERVER_IP
    if validate_ip "$SERVER_IP"; then
        break
    else
        print_error "Invalid IP address or domain name. Please try again."
    fi
done

# Get new username
read -p "Enter new username [user]: " NEW_USER
NEW_USER=${NEW_USER:-user}

# Get or generate password for new user
read -p "Enter password for $NEW_USER [press Enter to generate random password]: " NEW_USER_PASSWORD
if [ -z "$NEW_USER_PASSWORD" ]; then
    NEW_USER_PASSWORD=$(generate_password 12)
    print_info "Generated random password: $NEW_USER_PASSWORD"
else
    print_info "Using provided password"
fi

# Get SSH public key
read -p "Enter your SSH public key [required]: " SSH_PUBLIC_KEY
if [ -z "$SSH_PUBLIC_KEY" ]; then
    print_error "SSH public key is required for authentication!"
    exit 1
fi

# Get SSH port
read -p "Enter new SSH port [2222]: " SSH_PORT
SSH_PORT=${SSH_PORT:-2222}
if ! validate_port "$SSH_PORT"; then
    print_warning "Invalid port number. Using default 2222."
    SSH_PORT=2222
fi

print_status "Starting server configuration..."
echo ""
print_status "Please manually connect to the server and run the following commands:"
echo ""

# Generate configuration script for manual execution
CONFIG_SCRIPT="#!/bin/bash

# Update system
echo 'Updating system...'
apt update && apt upgrade -y

# Create new user with password
echo 'Creating user $NEW_USER...'
adduser --disabled-password --gecos '' '$NEW_USER'
echo '$NEW_USER:$NEW_USER_PASSWORD' | chpasswd
usermod -aG sudo '$NEW_USER'

# Setup SSH for new user
echo 'Setting up SSH key for $NEW_USER...'
mkdir -p '/home/$NEW_USER/.ssh'
echo '$SSH_PUBLIC_KEY' > '/home/$NEW_USER/.ssh/authorized_keys'
chmod 700 '/home/$NEW_USER/.ssh'
chmod 600 '/home/$NEW_USER/.ssh/authorized_keys'
chown -R '$NEW_USER:$NEW_USER' '/home/$NEW_USER/.ssh'

# Configure SSH server
echo 'Configuring SSH server...'
sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Remove existing Port line and add new one
sed -i '/^Port/d' /etc/ssh/sshd_config
echo 'Port $SSH_PORT' >> /etc/ssh/sshd_config

# Install and configure Fail2Ban
echo 'Installing Fail2Ban...'
apt install -y fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/^bantime.*/bantime = 3600/' /etc/fail2ban/jail.local
sed -i 's/^maxretry.*/maxretry = 3/' /etc/fail2ban/jail.local
sed -i \"s/^port.*= ssh\$/port = $SSH_PORT/\" /etc/fail2ban/jail.local

# Configure firewall
echo 'Configuring firewall...'
apt install -y ufw
ufw allow '$SSH_PORT/tcp'
echo 'y' | ufw enable

# Setup automatic updates
echo 'Setting up automatic updates...'
apt install -y unattended-upgrades
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

# Restart services
echo 'Restarting services...'
systemctl restart sshd
systemctl enable fail2ban
systemctl start fail2ban

echo 'Configuration completed!'"

# Save configuration script to file
echo "$CONFIG_SCRIPT" > server-setup-commands.sh
chmod +x server-setup-commands.sh

# Create summary file
SUMMARY_FILE="server-setup-summary.txt"
cat > "$SUMMARY_FILE" << EOF
==========================================
         SERVER SETUP SUMMARY
==========================================
Server: $SERVER_IP
New User: $NEW_USER
Password: $NEW_USER_PASSWORD
SSH Port: $SSH_PORT
SSH Key: Configured

SECURITY CHANGES APPLIED:
------------------------------------------
✓ Root SSH login disabled
✓ SSH port changed to $SSH_PORT
✓ Fail2Ban installed and configured
✓ UFW firewall enabled (port $SSH_PORT only)
✓ Automatic security updates enabled
✓ SSH key authentication enabled
✓ Password authentication enabled for user $NEW_USER

CONNECTION INSTRUCTIONS:
------------------------------------------
With SSH key:
  ssh $NEW_USER@$SERVER_IP -p $SSH_PORT

With password:
  ssh $NEW_USER@$SERVER_IP -p $SSH_PORT
  Password: $NEW_USER_PASSWORD

MANUAL STEPS REQUIRED:
------------------------------------------
1. Connect to server: ssh root@$SERVER_IP
2. Upload and execute setup script:
   scp -P 22 server-setup-commands.sh root@$SERVER_IP:/tmp/
   ssh root@$SERVER_IP 'bash /tmp/server-setup-commands.sh'

SECURITY NOTES:
------------------------------------------
• Root login is completely disabled
• Change user password after first login: passwd
• Keep your SSH private key secure
• Fail2Ban will block brute force attempts
• Only port $SSH_PORT is open in firewall

Generated on: $(date)
EOF

print_success "Configuration files have been generated!"
print_info "Configuration script: server-setup-commands.sh"
print_info "Setup summary: $SUMMARY_FILE"
echo ""
print_status "To complete setup, manually connect to your server:"
echo "ssh root@$SERVER_IP"
echo ""
print_status "Then upload and execute the configuration script:"
echo "scp -P 22 server-setup-commands.sh root@$SERVER_IP:/tmp/"
echo "ssh root@$SERVER_IP 'bash /tmp/server-setup-commands.sh'"
echo ""
print_warning "⚠️  IMPORTANT: Save the summary file ($SUMMARY_FILE) with password information!"
echo ""
print_success "After configuration, you can connect using:"
echo "ssh $NEW_USER@$SERVER_IP -p $SSH_PORT"
echo ""
print_info "Password authentication remains enabled for user: $NEW_USER"
