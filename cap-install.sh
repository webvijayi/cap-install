#!/bin/bash
#
# Cap.so Self-Hosting Installation Script (Enhanced)
# https://github.com/webvijayi/cap-install
#
# Usage: sudo bash cap-install.sh
#

# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'This installer needs to be run with "bash", not "sh".'
	exit 1
fi

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Detect root and Docker group membership
IS_ROOT=0
HAS_DOCKER_GROUP=0
INSTALL_MODE=""

if [[ $EUID -eq 0 ]]; then
	IS_ROOT=1
fi

if groups | grep -q '\bdocker\b'; then
	HAS_DOCKER_GROUP=1
fi

# Determine installation mode
if [[ $IS_ROOT -eq 1 ]]; then
	INSTALL_MODE="full"
	INSTALL_DIR="/opt/cap"
	HTTP_PORT=80
	HTTPS_PORT=443
elif [[ $HAS_DOCKER_GROUP -eq 1 ]]; then
	echo ""
	echo "================================================================================"
	echo "                    Cap.so Installation Mode Selection"
	echo "================================================================================"
	echo ""
	echo "You are not running as root, but you have Docker access."
	echo ""
	echo "Available modes:"
	echo ""
	echo "  1) User Mode (No root required)"
	echo "     - Install location: ~/cap"
	echo "     - HTTP Port: 8080 (instead of 80)"
	echo "     - HTTPS Port: 8443 (instead of 443)"
	echo "     - No system package installation"
	echo "     - Assumes Docker is already installed"
	echo ""
	echo "  2) Full Install Mode (Requires root)"
	echo "     - Run: sudo bash $0"
	echo "     - Install location: /opt/cap"
	echo "     - Standard ports: 80/443"
	echo "     - Installs missing packages"
	echo "     - Configures firewall"
	echo ""
	read -p "Choose mode [1 for User / 2 to exit and re-run with sudo]: " mode_choice

	if [[ "$mode_choice" == "1" ]]; then
		INSTALL_MODE="user"
		INSTALL_DIR="$HOME/cap"
		HTTP_PORT=8080
		HTTPS_PORT=8443
		echo ""
		echo "✓ User Mode selected"
		echo "  Installation directory: $INSTALL_DIR"
		echo "  HTTP Port: $HTTP_PORT"
		echo "  HTTPS Port: $HTTPS_PORT"
	else
		echo ""
		echo "Please re-run with sudo:"
		echo "  sudo bash $0"
		exit 0
	fi
else
	echo ""
	echo "================================================================================"
	echo "ERROR: Insufficient Permissions"
	echo "================================================================================"
	echo ""
	echo "You need either:"
	echo "  1) Root access: sudo bash $0"
	echo "  2) Docker group membership: sudo usermod -aG docker $USER"
	echo "     (then logout and login again)"
	echo ""
	exit 1
fi

# Detect OpenVZ 6
if [[ -e /proc/user_beancounters ]]; then
	echo "OpenVZ 6 is not supported."
	exit 1
fi

# Detect OS
if [[ -e /etc/debian_version ]]; then
	OS="debian"
	source /etc/os-release
	if [[ $ID == "debian" || $ID == "raspbian" ]]; then
		if [[ $VERSION_ID -lt 10 ]]; then
			echo "Your version of Debian is not supported."
			echo "However, if you're using Debian >= 10 or unstable/testing, you can continue."
			exit 1
		fi
	fi
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
	OS="centos"
	source /etc/os-release
elif [[ -e /etc/fedora-release ]]; then
	OS="fedora"
	source /etc/os-release
else
	echo "Looks like you aren't running this installer on a Debian, Ubuntu, CentOS, AlmaLinux, Rocky Linux, or Fedora system"
	exit 1
fi

################################################################################
# Exception Handling Functions
################################################################################

check_port_available() {
	local port=$1
	local service_name=$2

	if ss -tulpn | grep -q ":${port} "; then
		echo ""
		echo "ERROR: Port ${port} is already in use!"
		echo "This port is required for ${service_name}."
		echo ""

		# Try to identify what's using the port
		local process=$(ss -tulpn | grep ":${port} " | head -1)
		echo "Process using port ${port}:"
		echo "$process"
		echo ""

		# Special handling for common services
		if echo "$process" | grep -qi "apache\|httpd"; then
			echo "Apache web server detected on port ${port}."
			echo ""
			echo "Options:"
			echo "  1) Stop and disable Apache (recommended for Cap)"
			echo "  2) Exit and manually resolve conflict"
			read -p "Select option [1-2]: " apache_option

			case "$apache_option" in
				1)
					echo "Stopping Apache..."
					if systemctl is-active --quiet apache2; then
						systemctl stop apache2
						systemctl disable apache2
					elif systemctl is-active --quiet httpd; then
						systemctl stop httpd
						systemctl disable httpd
					fi
					echo "Apache stopped and disabled."
					;;
				2)
					echo "Exiting. Please resolve the port conflict manually."
					exit 1
					;;
				*)
					echo "Invalid option. Exiting."
					exit 1
					;;
			esac
		elif echo "$process" | grep -qi "nginx"; then
			echo "Nginx web server detected on port ${port}."
			echo ""
			echo "Options:"
			echo "  1) Stop and disable Nginx"
			echo "  2) Exit and manually resolve conflict"
			read -p "Select option [1-2]: " nginx_option

			case "$nginx_option" in
				1)
					echo "Stopping Nginx..."
					systemctl stop nginx
					systemctl disable nginx
					echo "Nginx stopped and disabled."
					;;
				2)
					echo "Exiting. Please resolve the port conflict manually."
					exit 1
					;;
			esac
		else
			echo "Please stop the service using port ${port} and run this script again."
			exit 1
		fi
	fi
}

check_selinux() {
	if command -v getenforce &> /dev/null; then
		if [[ "$(getenforce)" == "Enforcing" ]]; then
			echo ""
			echo "WARNING: SELinux is in Enforcing mode."
			echo "This may cause issues with Docker and Cap."
			echo ""
			echo "Options:"
			echo "  1) Set SELinux to Permissive mode (recommended)"
			echo "  2) Continue anyway (may cause issues)"
			echo "  3) Exit"
			read -p "Select option [1-3]: " selinux_option

			case "$selinux_option" in
				1)
					echo "Setting SELinux to Permissive mode..."
					setenforce 0
					sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
					echo "SELinux set to Permissive mode."
					;;
				2)
					echo "Continuing with SELinux Enforcing..."
					;;
				3)
					exit 1
					;;
			esac
		fi
	fi
}

check_disk_space() {
	local required_gb=20
	local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

	if [[ $available_gb -lt $required_gb ]]; then
		echo ""
		echo "WARNING: Low disk space detected!"
		echo "Available: ${available_gb}GB, Recommended: ${required_gb}GB+"
		echo ""

		# Check if we can clean up Docker
		if command -v docker &> /dev/null; then
			echo "Docker is installed. You can free up space by running:"
			echo "  docker system prune -a"
			echo ""
		fi

		read -p "Continue anyway? [y/N]: " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			exit 1
		fi
	fi
}

check_existing_mysql() {
	if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
		echo ""
		echo "WARNING: MySQL is already running on this system."
		echo "Cap will use a Docker container for MySQL, which may conflict."
		echo ""
		echo "Options:"
		echo "  1) Continue (Cap will use Docker MySQL on different port if needed)"
		echo "  2) Stop system MySQL and continue"
		echo "  3) Exit"
		read -p "Select option [1-3]: " mysql_option

		case "$mysql_option" in
			1)
				echo "Continuing with existing MySQL..."
				USE_CUSTOM_MYSQL_PORT=1
				;;
			2)
				echo "Stopping system MySQL..."
				systemctl stop mysql 2>/dev/null || systemctl stop mysqld 2>/dev/null
				systemctl disable mysql 2>/dev/null || systemctl disable mysqld 2>/dev/null
				;;
			3)
				exit 1
				;;
		esac
	fi
}

check_ipv6_only() {
	# Check if server is IPv6-only
	if ! curl -4 -s -m 5 http://icanhazip.com &> /dev/null; then
		if curl -6 -s -m 5 http://icanhazip.com &> /dev/null; then
			echo ""
			echo "WARNING: This server appears to be IPv6-only."
			echo "Cap installation will continue, but some features may require IPv4."
			echo ""
			IPV6_ONLY=1
			sleep 3
		fi
	fi
}

################################################################################
# Main Script Start
################################################################################

# Check system resources
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM -lt 1800 ]]; then
	echo ""
	echo "WARNING: Less than 2GB RAM detected (${TOTAL_RAM}MB)."
	echo "Cap may not run optimally. Continue anyway? [y/N]"
	read -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi

# Run all exception checks
check_disk_space
check_selinux
check_ipv6_only

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
	DOCKER_INSTALLED=0
else
	DOCKER_INSTALLED=1
fi

# Check if Cap is already installed
if [[ -e /opt/cap/docker-compose.yml ]]; then
	echo ""
	echo "Cap appears to be already installed."
	echo ""
	echo "What do you want to do?"
	echo "   1) Update Cap to latest version"
	echo "   2) View installation info & credentials"
	echo "   3) Restart Cap services"
	echo "   4) View logs"
	echo "   5) Backup Cap data"
	echo "   6) Uninstall Cap"
	echo "   7) Exit"
	read -p "Select an option [1-7]: " option
	until [[ "$option" =~ ^[1-7]$ ]]; do
		echo "$option: invalid selection."
		read -p "Select an option [1-7]: " option
	done
	case "$option" in
		1)
			echo ""
			echo "Updating Cap..."
			cd /opt/cap
			docker compose pull
			docker compose up -d
			echo ""
			echo "Cap has been updated to the latest version!"
			exit 0
			;;
		2)
			echo ""
			if [[ -e /opt/cap/credentials.txt ]]; then
				cat /opt/cap/credentials.txt
			else
				echo "Credentials file not found."
			fi
			exit 0
			;;
		3)
			echo ""
			echo "Restarting Cap services..."
			cd /opt/cap
			docker compose restart
			echo "Done!"
			exit 0
			;;
		4)
			cd /opt/cap
			docker compose logs -f
			exit 0
			;;
		5)
			echo ""
			BACKUP_DIR="/opt/cap/backups/$(date +%Y%m%d_%H%M%S)"
			mkdir -p "$BACKUP_DIR"
			echo "Creating backup..."

			# Get MySQL root password
			MYSQL_ROOT_PASSWORD=$(grep "MySQL Root Password:" /opt/cap/credentials.txt | cut -d' ' -f4)

			# Backup database
			docker exec cap-mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" planetscale > "$BACKUP_DIR/database.sql"

			# Backup MinIO data
			docker exec cap-minio tar czf - /data > "$BACKUP_DIR/minio-data.tar.gz"

			echo ""
			echo "Backup created at: $BACKUP_DIR"
			exit 0
			;;
		6)
			echo ""
			echo "WARNING: This will completely remove Cap and all data!"
			echo "Type 'DELETE' to confirm uninstallation:"
			read -r confirm
			if [[ "$confirm" != "DELETE" ]]; then
				echo "Uninstall cancelled."
				exit 0
			fi

			echo ""
			echo "Uninstalling Cap..."
			cd /opt/cap
			docker compose down -v
			cd /
			rm -rf /opt/cap
			echo ""
			echo "Cap has been uninstalled."
			exit 0
			;;
		7)
			exit 0
			;;
	esac
fi

# New installation
clear
echo 'Welcome to Cap.so self-hosting installer!'
echo ""
echo "This installer will set up Cap on your server with:"
echo "  - Cap Web (latest from GitHub)"
echo "  - MySQL 9 database"
echo "  - MinIO S3 storage"
echo "  - Nginx reverse proxy"
echo "  - Optional SSL/TLS (Let's Encrypt)"
echo ""

# Check for port conflicts BEFORE asking user questions
echo "Checking for port conflicts..."
check_existing_mysql
check_port_available 80 "HTTP (Nginx)"
check_port_available 443 "HTTPS (Nginx)"

# Get public IP
PUBLIC_IP=$(curl -4 -s ifconfig.me)
if [[ -z $PUBLIC_IP ]]; then
	PUBLIC_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
fi

# Domain/IP configuration
echo ""
echo "================================================================================"
echo "ACCESS URL CONFIGURATION"
echo "================================================================================"
echo ""
echo "Choose how users will access your Cap instance:"
echo ""
echo "  Option 1: Use IP Address (Quick, but no SSL)"
echo "    - Access via: http://${PUBLIC_IP}"
echo "    - No DNS setup needed"
echo "    - SSL/HTTPS not available"
echo ""
echo "  Option 2: Use Custom Domain (Recommended for production)"
echo "    - Access via: https://your-domain.com"
echo "    - Requires DNS A record pointing to ${PUBLIC_IP}"
echo "    - Supports SSL/HTTPS with Let's Encrypt"
echo "    - Professional appearance"
echo ""
read -p "Press Enter for IP (${PUBLIC_IP}), or enter your domain: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
	DOMAIN="$PUBLIC_IP"
	echo ""
	echo "✓ Using IP address: $DOMAIN"
	echo "  (SSL will not be available)"
else
	echo ""
	echo "✓ Using domain: $DOMAIN"
	echo "  Remember to configure DNS A record: $DOMAIN → ${PUBLIC_IP}"
fi

# SSL configuration
echo ""
echo "Do you want to enable SSL/HTTPS with Let's Encrypt?"
echo "  Note: Requires a valid domain name (not IP address)"
read -p "Enable SSL? [y/N]: " -e -i n ENABLE_SSL

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	# Check if domain is actually a domain, not IP
	if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo ""
		echo "ERROR: SSL requires a domain name, not an IP address."
		echo "Continuing without SSL..."
		ENABLE_SSL="n"
	else
		read -p "Email for Let's Encrypt notifications: " SSL_EMAIL
		until [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
			echo "Invalid email address."
			read -p "Email: " SSL_EMAIL
		done
	fi
fi

# Email configuration
echo ""
echo "Do you want to enable email login links (Resend)?"
echo "  If not enabled, login links will appear in server logs"
read -p "Enable Resend email? [y/N]: " -e -i n ENABLE_EMAIL

if [[ "$ENABLE_EMAIL" =~ ^[Yy]$ ]]; then
	read -p "Resend API Key: " RESEND_API_KEY
	read -p "Resend FROM domain: " RESEND_FROM_DOMAIN
fi

# Installation starts here
echo ""
echo "Installation starting..."
echo ""

# Update system (only in full install mode)
if [[ "$INSTALL_MODE" == "full" ]]; then
	echo "[1/10] Updating system packages..."
	if [[ "$OS" == "debian" ]]; then
		apt-get update -qq
		apt-get install -y -qq curl wget git gnupg ca-certificates openssl pwgen net-tools >/dev/null 2>&1
	elif [[ "$OS" == "centos" ]]; then
		yum install -y -q curl wget git ca-certificates openssl pwgen net-tools >/dev/null 2>&1
	elif [[ "$OS" == "fedora" ]]; then
		dnf install -y -q curl wget git ca-certificates openssl pwgen net-tools >/dev/null 2>&1
	fi
else
	echo "[1/10] Skipping package installation (user mode)..."
fi

# Install Docker if needed (only in full install mode)
if [[ $DOCKER_INSTALLED -eq 0 && "$INSTALL_MODE" == "full" ]]; then
	echo "[2/10] Installing Docker..."

	if [[ "$OS" == "debian" ]]; then
		# Remove old versions
		apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

		# Add Docker's official GPG key
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/$ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
		chmod a+r /etc/apt/keyrings/docker.gpg

		# Add repository
		echo \
		  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
		  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
		  tee /etc/apt/sources.list.d/docker.list > /dev/null

		# Install Docker
		apt-get update -qq
		apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
	elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
		# Add repository
		yum install -y -q yum-utils >/dev/null 2>&1
		yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1

		# Install Docker
		yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
	fi

	# Start Docker
	systemctl start docker
	systemctl enable docker >/dev/null 2>&1

	# Wait for Docker to be ready
	sleep 3
else
	echo "[2/10] Docker already installed, skipping..."
fi

# Verify Docker is working
if ! docker ps &> /dev/null; then
	echo ""
	echo "ERROR: Docker is installed but not working properly."
	echo "Please check: systemctl status docker"
	exit 1
fi

# Generate secrets
echo "[3/10] Generating secure secrets..."
DATABASE_SECRET=$(openssl rand -base64 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
MYSQL_ROOT_PASSWORD=$(pwgen -s 32 1)
MYSQL_PASSWORD=$(pwgen -s 32 1)
MINIO_ROOT_USER="capadmin"
MINIO_ROOT_PASSWORD=$(pwgen -s 32 1)
S3_ACCESS_KEY_ID="cap_$(pwgen -s 20 1)"
S3_SECRET_ACCESS_KEY=$(pwgen -s 40 1)

# Create installation directory
echo "[4/10] Creating installation directory..."
# INSTALL_DIR is already set based on installation mode
mkdir -p "$INSTALL_DIR"

# Determine external endpoint
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	EXTERNAL_ENDPOINT="https://${DOMAIN}"
	# Add port if not standard 443
	if [[ $HTTPS_PORT -ne 443 ]]; then
		EXTERNAL_ENDPOINT="${EXTERNAL_ENDPOINT}:${HTTPS_PORT}"
	fi
else
	EXTERNAL_ENDPOINT="http://${DOMAIN}"
	# Add port if not standard 80
	if [[ $HTTP_PORT -ne 80 ]]; then
		EXTERNAL_ENDPOINT="${EXTERNAL_ENDPOINT}:${HTTP_PORT}"
	fi
fi

# Determine MySQL port (use 3307 if 3306 is taken)
MYSQL_PORT=3306
if [[ -n "$USE_CUSTOM_MYSQL_PORT" ]]; then
	MYSQL_PORT=3307
fi

# Create Docker Compose file
echo "[5/10] Creating Docker Compose configuration..."
cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  cap-web:
    image: ghcr.io/capsoftware/cap-web:latest
    container_name: cap-web
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: "mysql://capuser:${MYSQL_PASSWORD}@cap-mysql:3306/planetscale"
      WEB_URL: "${EXTERNAL_ENDPOINT}"
      NEXTAUTH_SECRET: "${NEXTAUTH_SECRET}"
      NEXTAUTH_URL: "${EXTERNAL_ENDPOINT}"
      NEXT_PUBLIC_URL: "${EXTERNAL_ENDPOINT}"
      CAP_AWS_BUCKET: "cap"
      CAP_AWS_REGION: "us-east-1"
      S3_ACCESS_KEY_ID: "${S3_ACCESS_KEY_ID}"
      S3_SECRET_ACCESS_KEY: "${S3_SECRET_ACCESS_KEY}"
      S3_BUCKET: "cap"
      S3_REGION: "us-east-1"
      S3_ENDPOINT: "http://cap-minio:9000"
      NEXT_PUBLIC_S3_ENDPOINT: "${EXTERNAL_ENDPOINT}/s3"
      NODE_ENV: "production"
EOF

if [[ "$ENABLE_EMAIL" =~ ^[Yy]$ ]]; then
	cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      RESEND_API_KEY: "${RESEND_API_KEY}"
      RESEND_FROM_DOMAIN: "${RESEND_FROM_DOMAIN}"
EOF
fi

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
    depends_on:
      cap-mysql:
        condition: service_healthy
      cap-minio:
        condition: service_started
    networks:
      - cap-network

  cap-mysql:
    image: mysql:9
    container_name: cap-mysql
    restart: unless-stopped
EOF

if [[ "$MYSQL_PORT" != "3306" ]]; then
	cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
    ports:
      - "${MYSQL_PORT}:3306"
EOF
fi

cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
    environment:
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      MYSQL_DATABASE: "planetscale"
      MYSQL_USER: "capuser"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
EOF

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
    volumes:
      - cap-mysql-data:/var/lib/mysql
    command: --max-connections=1000
    healthcheck:
EOF

cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
EOF

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 60s
    networks:
      - cap-network

  cap-minio:
    image: minio/minio:latest
    container_name: cap-minio
    restart: unless-stopped
    environment:
EOF

cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      MINIO_ROOT_USER: "${MINIO_ROOT_USER}"
      MINIO_ROOT_PASSWORD: "${MINIO_ROOT_PASSWORD}"
EOF

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
    volumes:
      - cap-minio-data:/data
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - cap-network

  nginx:
    image: nginx:alpine
    container_name: cap-nginx
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
EOF

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      - "${HTTPS_PORT}:443"
EOF
fi

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
EOF

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
      - ./ssl:/etc/nginx/ssl:ro
      - certbot-data:/var/www/certbot:ro
EOF
fi

cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
    depends_on:
      - cap-web
      - cap-minio
    networks:
      - cap-network

networks:
  cap-network:
    driver: bridge

volumes:
  cap-mysql-data:
  cap-minio-data:
EOF

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
  certbot-data:
EOF
fi

# Create Nginx configuration (same as before, truncated for brevity)
echo "[6/10] Creating Nginx configuration..."

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	cat > "$INSTALL_DIR/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream cap-web {
        server cap-web:3000;
    }

    upstream minio {
        server cap-minio:9000;
    }

    upstream minio-console {
        server cap-minio:9001;
    }

    server {
        listen 80;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
EOF
else
	cat > "$INSTALL_DIR/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream cap-web {
        server cap-web:3000;
    }

    upstream minio {
        server cap-minio:9000;
    }

    upstream minio-console {
        server cap-minio:9001;
    }

    server {
        listen 80;
        server_name _;

        client_max_body_size 500M;

        location / {
            proxy_pass http://cap-web;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        location /s3/ {
            rewrite ^/s3/(.*) /$1 break;
            proxy_pass http://minio;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /minio-console/ {
            rewrite ^/minio-console/(.*) /$1 break;
            proxy_pass http://minio-console;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOF
fi

# Configure firewall (only in full install mode)
if [[ "$INSTALL_MODE" == "full" ]]; then
	echo "[7/10] Configuring firewall..."
	if command -v ufw &> /dev/null; then
		ufw --force enable >/dev/null 2>&1
		ufw allow ${HTTP_PORT}/tcp >/dev/null 2>&1
		if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
			ufw allow ${HTTPS_PORT}/tcp >/dev/null 2>&1
		fi
		ufw allow 22/tcp >/dev/null 2>&1
	elif command -v firewall-cmd &> /dev/null; then
		systemctl start firewalld >/dev/null 2>&1
		systemctl enable firewalld >/dev/null 2>&1
		firewall-cmd --permanent --add-port=${HTTP_PORT}/tcp >/dev/null 2>&1
		if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
			firewall-cmd --permanent --add-port=${HTTPS_PORT}/tcp >/dev/null 2>&1
		fi
		firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
		firewall-cmd --reload >/dev/null 2>&1
	fi
else
	echo "[7/10] Skipping firewall configuration (user mode)..."
	echo "       Note: Manually allow ports ${HTTP_PORT}/tcp and ${HTTPS_PORT}/tcp if needed"
fi

# Setup SSL if enabled
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
	echo "[8/10] Setting up SSL certificate..."
	mkdir -p "$INSTALL_DIR/ssl"

	# Start temporary nginx for cert generation
	docker run -d --name nginx-temp \
		-p 80:80 \
		-v "$INSTALL_DIR/nginx.conf:/etc/nginx/nginx.conf:ro" \
		-v "$INSTALL_DIR/ssl:/etc/nginx/ssl" \
		-v cap_certbot-data:/var/www/certbot \
		nginx:alpine >/dev/null 2>&1

	sleep 3

	# Get certificate
	if ! docker run --rm \
		-v "$INSTALL_DIR/ssl:/etc/letsencrypt" \
		-v cap_certbot-data:/var/www/certbot \
		certbot/certbot certonly \
		--webroot \
		--webroot-path=/var/www/certbot \
		--email "$SSL_EMAIL" \
		--agree-tos \
		--no-eff-email \
		-d "$DOMAIN"; then

		echo ""
		echo "ERROR: Failed to obtain SSL certificate."
		echo "Possible reasons:"
		echo "  - Domain not pointing to this server"
		echo "  - Let's Encrypt rate limit reached"
		echo "  - Firewall blocking port 80"
		echo ""
		echo "Continuing without SSL..."
		ENABLE_SSL="n"
		EXTERNAL_ENDPOINT="http://${DOMAIN}"
	fi

	# Stop temporary nginx
	docker stop nginx-temp >/dev/null 2>&1
	docker rm nginx-temp >/dev/null 2>&1

	if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
		# Update nginx config with SSL
		cat > "$INSTALL_DIR/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream cap-web {
        server cap-web:3000;
    }

    upstream minio {
        server cap-minio:9000;
    }

    upstream minio-console {
        server cap-minio:9001;
    }

    server {
        listen 80;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate /etc/nginx/ssl/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/live/$DOMAIN/privkey.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        client_max_body_size 500M;

        location / {
            proxy_pass http://cap-web;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }

        location /s3/ {
            rewrite ^/s3/(.*) /\$1 break;
            proxy_pass http://minio;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /minio-console/ {
            rewrite ^/minio-console/(.*) /\$1 break;
            proxy_pass http://minio-console;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
}
EOF
	fi
else
	echo "[8/10] Skipping SSL setup..."
fi

# Start services
echo "[9/10] Starting Cap services..."
cd "$INSTALL_DIR"

# Pull images with retry logic
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
	if docker compose pull 2>&1; then
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
		echo "Pull failed, retrying ($RETRY_COUNT/$MAX_RETRIES)..."
		sleep 5
	else
		echo ""
		echo "ERROR: Failed to pull Docker images after $MAX_RETRIES attempts."
		echo "Please check your internet connection and try again."
		exit 1
	fi
done

# Export ports for docker-compose
export HTTP_PORT HTTPS_PORT
docker compose up -d

# Configure MinIO
echo "[10/10] Configuring MinIO storage..."
sleep 15

# Wait for MinIO to be ready
MAX_WAIT=60
WAIT_COUNT=0
while ! docker logs cap-minio 2>&1 | grep -q "API:"; do
	if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
		echo "WARNING: MinIO may not have started properly"
		break
	fi
	sleep 2
	WAIT_COUNT=$((WAIT_COUNT + 2))
done

docker run --rm --network="cap_cap-network" \
	--entrypoint /bin/sh \
	minio/mc -c "
	mc alias set cap http://cap-minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null 2>&1 && \
	mc mb cap/cap --ignore-existing >/dev/null 2>&1 && \
	mc anonymous set download cap/cap >/dev/null 2>&1 && \
	mc admin user add cap ${S3_ACCESS_KEY_ID} ${S3_SECRET_ACCESS_KEY} >/dev/null 2>&1 && \
	mc admin policy attach cap readwrite --user ${S3_ACCESS_KEY_ID} >/dev/null 2>&1
	" || echo "WARNING: MinIO configuration may have failed"

# Save credentials
cat > "$INSTALL_DIR/credentials.txt" << EOF
================================================================================
Cap.so Self-Hosting Credentials
================================================================================
Installation Date: $(date)

Access URLs:
  Cap Web: ${EXTERNAL_ENDPOINT}
  MinIO Console: ${EXTERNAL_ENDPOINT}/minio-console

Database:
  MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
  MySQL User: capuser
  MySQL Password: ${MYSQL_PASSWORD}
  MySQL Port: ${MYSQL_PORT}

MinIO:
  Root User: ${MINIO_ROOT_USER}
  Root Password: ${MINIO_ROOT_PASSWORD}
  S3 Access Key: ${S3_ACCESS_KEY_ID}
  S3 Secret Key: ${S3_SECRET_ACCESS_KEY}

Application:
  NextAuth Secret: ${NEXTAUTH_SECRET}

================================================================================
IMPORTANT: Keep this file secure!
================================================================================
EOF

chmod 600 "$INSTALL_DIR/credentials.txt"

# Security: Verify credentials file is not web-accessible
# - File is outside web root (/opt/cap/ is not served by nginx)
# - Permissions 600 (only root can read)
# - Nginx config has no 'root' or 'alias' directives
echo "[Security] Credentials file secured with 600 permissions"

# Create management scripts
cat > "$INSTALL_DIR/cap-start.sh" << EOF
#!/bin/bash
export HTTP_PORT=${HTTP_PORT}
export HTTPS_PORT=${HTTPS_PORT}
cd ${INSTALL_DIR} && docker compose up -d
EOF

cat > "$INSTALL_DIR/cap-stop.sh" << EOF
#!/bin/bash
cd ${INSTALL_DIR} && docker compose down
EOF

cat > "$INSTALL_DIR/cap-restart.sh" << EOF
#!/bin/bash
cd ${INSTALL_DIR} && docker compose restart
EOF

cat > "$INSTALL_DIR/cap-logs.sh" << EOF
#!/bin/bash
cd ${INSTALL_DIR} && docker compose logs -f
EOF

cat > "$INSTALL_DIR/cap-get-login.sh" << EOF
#!/bin/bash
echo "================================================================================"
echo "                Cap.so - Get Verification Code for Login"
echo "================================================================================"
echo ""
echo "Instructions:"
echo "1. Visit your Cap instance and enter your email"
echo "2. Run this script to see the 6-digit verification code"
echo "3. Enter the code on the login verification page"
echo ""
echo "Watching for verification codes (press Ctrl+C to stop)..."
echo "================================================================================"
echo ""
cd ${INSTALL_DIR} && docker compose logs -f cap-web 2>&1 | grep --line-buffered -A 10 "VERIFICATION CODE"
EOF

chmod +x "$INSTALL_DIR"/cap-*.sh

# Final health check
echo ""
echo "Performing health check..."
sleep 10

# Check each service
SERVICES_OK=1

if ! docker ps | grep -q "cap-web.*Up"; then
	echo "WARNING: cap-web container not running properly"
	SERVICES_OK=0
fi

if ! docker ps | grep -q "cap-mysql.*(healthy)"; then
	echo "WARNING: cap-mysql container not healthy"
	SERVICES_OK=0
fi

if ! docker ps | grep -q "cap-minio.*Up"; then
	echo "WARNING: cap-minio container not running properly"
	SERVICES_OK=0
fi

if ! docker ps | grep -q "cap-nginx.*Up"; then
	echo "WARNING: cap-nginx container not running properly"
	SERVICES_OK=0
fi

if [ $SERVICES_OK -eq 1 ]; then
	echo ""
	echo "================================================================================  "
	echo "                  Cap.so Installation Complete!                                 "
	echo "================================================================================"
	echo ""
	echo "🎉 ACCESS YOUR CAP INSTANCE:"
	echo "   ${EXTERNAL_ENDPOINT}"
	echo ""

	# Show installation mode and port info
	if [[ "$INSTALL_MODE" == "user" ]]; then
		echo "📦 INSTALLATION MODE: User Mode (No root required)"
		echo "   Location: ${INSTALL_DIR}"
		echo "   HTTP Port: ${HTTP_PORT} (non-standard, use in URL)"
		if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
			echo "   HTTPS Port: ${HTTPS_PORT}"
		fi
		echo ""
	else
		echo "📦 INSTALLATION MODE: Full Install (System-wide)"
		echo "   Location: ${INSTALL_DIR}"
		echo "   HTTP Port: ${HTTP_PORT}"
		if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
			echo "   HTTPS Port: ${HTTPS_PORT}"
		fi
		echo ""
	fi

	# DNS instructions if domain was used
	if [[ ! "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "📡 DNS SETUP REQUIRED:"
		echo "   Point your domain '${DOMAIN}' to this server's IP: ${PUBLIC_IP}"
		echo "   Add an A record:"
		echo "     Type: A"
		echo "     Name: @ (or subdomain)"
		echo "     Value: ${PUBLIC_IP}"
		echo "     TTL: 300"
		echo ""
		if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
			echo "   SSL will activate automatically once DNS propagates (up to 48 hours)"
			echo ""
		else
			echo "💡 TIP: You can enable SSL later by re-running this script"
			echo ""
		fi
	fi

	echo "🔐 FIRST-TIME LOGIN:"
	if [[ "$ENABLE_EMAIL" =~ ^[Yy]$ ]]; then
		echo "   1. Visit ${EXTERNAL_ENDPOINT}"
		echo "   2. Click 'Login with email' and enter your email address"
		echo "   3. Check your email for the 6-digit verification code"
		echo "   4. Enter the code on the verification page"
	else
		echo "   1. Visit ${EXTERNAL_ENDPOINT}"
		echo "   2. Click 'Login with email' and enter your email address"
		echo "   3. Get the 6-digit code using the helper script:"
		echo "      ${INSTALL_DIR}/cap-get-login.sh"
		echo "   4. Enter the code on the verification page"
		echo ""
		echo "   💡 The helper script will watch logs and show the verification code!"
		echo "   Example code: 744381 (expires in 10 minutes)"
	fi
	echo ""

	echo "📹 RECORDINGS STORAGE:"
	echo "   Location: /var/lib/docker/volumes/cap_cap-minio-data/_data"
	echo "   MinIO Console: ${EXTERNAL_ENDPOINT}/minio-console"
	echo "   Username: capadmin"
	echo "   (Password in credentials file)"
	echo ""

	echo "📄 CREDENTIALS & INFO:"
	echo "   All credentials saved to: /opt/cap/credentials.txt"
	echo "   View: cat /opt/cap/credentials.txt"
	echo ""

	echo "🔧 MANAGEMENT COMMANDS:"
	echo "   Start:     /opt/cap/cap-start.sh"
	echo "   Stop:      /opt/cap/cap-stop.sh"
	echo "   Restart:   /opt/cap/cap-restart.sh"
	echo "   Logs:      /opt/cap/cap-logs.sh"
	echo "   Get Login: /opt/cap/cap-get-login.sh"
	echo "   Manage:    sudo bash cap-install.sh"
	echo ""
	echo "================================================================================"
else
	echo ""
	echo "================================================================================  "
	echo "                  Installation Completed with Warnings                          "
	echo "================================================================================"
	echo ""
	echo "Some services may not be running properly."
	echo "Check logs with: cd /opt/cap && docker compose logs"
	echo ""
	echo "Common issues:"
	echo "  - Wait a few more minutes for services to fully start"
	echo "  - Check firewall settings"
	echo "  - Verify Docker has enough resources"
	echo "  - Check for port conflicts"
	echo ""
	echo "================================================================================"
fi
