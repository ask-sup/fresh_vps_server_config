#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        # Check if it's a valid domain name
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if sshpass is installed
if ! command_exists sshpass; then
    print_error "sshpass is not installed. Please install it first."
    echo "For Ubuntu/Debian: sudo apt install sshpass"
    echo "For macOS: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

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

# Get root password
read -s -p "Enter root password: " ROOT_PASSWORD
echo ""

# Get new username
read -p "Enter new username [user]: " NEW_USER
NEW_USER=${NEW_USER:-user}

# Get SSH public key
read -p "Enter your SSH public key [leave empty to skip]: " SSH_PUBLIC_KEY

# Get SSH port
read -p "Enter new SSH port [2222]: " SSH_PORT
SSH_PORT=${SSH_PORT:-2222}
if ! validate_port "$SSH_PORT"; then
    print_warning "Invalid port number. Using default 2222."
    SSH_PORT=2222
fi

print_status "Starting server configuration..."
echo ""

# Test SSH connection
print_status "Testing SSH connection to $SERVER_IP..."
if ! sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$SERVER_IP" "echo 'SSH connection successful'"; then
    print_error "Failed to connect to server. Please check credentials and network connectivity."
    exit 1
fi

# Execute configuration commands on remote server
print_status "Configuring server $SERVER_IP..."

sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@"$SERVER_IP" << EOF
    # Update system
    echo "Updating system..."
    apt update && apt upgrade -y
    
    # Create new user
    echo "Creating user $NEW_USER..."
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    
    # Setup SSH for new user
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "Setting up SSH key for $NEW_USER..."
        mkdir -p "/home/$NEW_USER/.ssh"
        echo "$SSH_PUBLIC_KEY" > "/home/$NEW_USER/.ssh/authorized_keys"
        chmod 700 "/home/$NEW_USER/.ssh"
        chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
        chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
    fi
    
    # Configure SSH server
    echo "Configuring SSH server..."
    sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Remove existing Port line and add new one
    sed -i '/^Port/d' /etc/ssh/sshd_config
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    
    # Install and configure Fail2Ban
    echo "Installing Fail2Ban..."
    apt install -y fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i 's/^bantime.*/bantime = 3600/' /etc/fail2ban/jail.local
    sed -i 's/^maxretry.*/maxretry = 3/' /etc/fail2ban/jail.local
    sed -i "s/^port.*= ssh\$/port = $SSH_PORT/" /etc/fail2ban/jail.local
    
    # Configure firewall
    echo "Configuring firewall..."
    apt install -y ufw
    ufw allow "$SSH_PORT/tcp"
    echo "y" | ufw enable
    
    # Setup automatic updates
    echo "Setting up automatic updates..."
    apt install -y unattended-upgrades
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades
    
    # Restart services
    echo "Restarting services..."
    systemctl restart sshd
    systemctl enable fail2ban
    systemctl start fail2ban
    
    echo "Configuration completed on server side."
EOF

# Check if configuration was successful
if [ $? -eq 0 ]; then
    echo ""
    print_success "Your new server has been successfully configured!"
    echo ""
    echo "=========================================="
    echo "           CONFIGURATION SUMMARY"
    echo "=========================================="
    echo "Server: $SERVER_IP"
    echo "Username: $NEW_USER"
    echo "SSH Port: $SSH_PORT"
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "SSH Key: ✅ Configured"
    else
        echo "SSH Key: ❌ Not configured"
    fi
    echo "Firewall: ✅ Enabled (port $SSH_PORT only)"
    echo "Fail2Ban: ✅ Installed and configured"
    echo "Automatic updates: ✅ Enabled"
    echo ""
    echo "Don't forget to reconnect using the new SSH port:"
    echo "ssh $NEW_USER@$SERVER_IP -p $SSH_PORT"
    echo ""
    print_warning "Note: Root login and password authentication are now disabled."
else
    print_error "Server configuration failed. Please check the error messages above."
    exit 1
fi
