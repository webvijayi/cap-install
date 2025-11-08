# Cap.so Self-Hosting Installation Script

One-click installer for [Cap.so](https://cap.so) - the open-source Loom alternative for beautiful screen recordings.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/webvijayi/cap-install?style=social)](https://github.com/webvijayi/cap-install/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/webvijayi/cap-install?style=social)](https://github.com/webvijayi/cap-install/network/members)

**⭐ If this helped you, please star the repo!**

## 🚀 Quick Start

### One-Liner Installation (Recommended)

**Full Install (with root):**
```bash
curl -fsSL https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh | sudo bash
```

**Or download and run:**
```bash
wget https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh
sudo bash cap-install.sh
```

### User Mode (No root required)

If you already have Docker and are in the docker group:
```bash
wget https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh
bash cap-install.sh
```

The script will automatically detect your permissions and offer appropriate installation modes.

---

## 🛡️ Production Server Safety

**IMPORTANT**: This installer is designed to be **safe and non-destructive** on production servers running existing websites.

### Port Conflict Protection

If the installer detects Apache, Nginx, or other services on ports 80/443, it will:

✅ **NEVER automatically stop your web server**
✅ **Offer safe alternatives**:
  1. Run Cap on port 8080 (recommended - keeps your sites running)
  2. Provide reverse proxy config for integration
  3. Only stop services with explicit confirmation

### What Gets Checked

The installer checks for conflicts on:
- **Port 80/443**: HTTP/HTTPS (web servers)
- **Port 3306**: MySQL (if system MySQL is running)
- **Port 9000/9001**: MinIO (object storage)

### Example: Running Alongside Existing Websites

```
Server has: Apache on port 80 serving your websites
Cap installer detects: Apache conflict
Options offered:
  1) Run Cap on port 8080 ✓ SAFE - Your websites keep running
  2) Integrate Cap with Apache (shows config example)
  3) Stop Apache (requires typing "YES I UNDERSTAND")
```

**Default recommendation**: Always choose option 1 (alternative port) to keep your existing services running.

---

## 📋 Installation Modes

### 🔧 Full Install Mode (Requires Root)

**Best for:** Production servers, VPS, dedicated servers, servers with existing websites

**Features:**
- ✅ System-wide installation at `/opt/cap`
- ✅ **Smart port handling** (80/443, or 8080/8443 if conflicts detected)
- ✅ **Apache/Nginx integration** (auto-configures reverse proxy)
- ✅ **Production-safe** (never breaks existing websites)
- ✅ Automatic package installation
- ✅ Docker installation if needed
- ✅ Firewall configuration
- ✅ SSL/HTTPS with Let's Encrypt
- ✅ System service management
- ✅ WebSocket support included
- ✅ MinIO S3 storage auto-configured

**Requirements:**
- Root access (sudo)
- Ubuntu 20.04+, Debian 10+, CentOS 8+, Rocky Linux 8+, or Fedora
- 2GB RAM minimum
- 20GB disk space

**Run with:**
```bash
sudo bash cap-install.sh
```

**One-liner install:**
```bash
curl -fsSL https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh | sudo bash
```

---

### 👤 User Mode (No Root Required)

**Best for:** Development, testing, shared hosting, multi-user servers

**Features:**
- ✅ User directory installation (`~/cap`)
- ✅ Non-privileged ports (8080/8443)
- ✅ No system modifications
- ✅ SSL/HTTPS support
- ✅ No package installation needed

**Requirements:**
- Docker already installed
- User in docker group: `sudo usermod -aG docker $USER` (then logout/login)

**Run with:**
```bash
bash cap-install.sh
```

**The script will prompt you to choose User Mode automatically.**

---

## 🎯 What's Installed?

- **Cap Web** - Next.js web application (latest from GitHub)
- **MySQL 9** - Database for user data and metadata
- **MinIO** - S3-compatible object storage for recordings
- **Nginx** - Reverse proxy with optional SSL/HTTPS

---

## 📦 System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **RAM** | 2 GB minimum, 4 GB recommended |
| **Disk Space** | 10 GB minimum, 50 GB+ recommended for recordings |
| **CPU** | 2 cores minimum |
| **OS** | Ubuntu 20.04+, Debian 10+, CentOS 8+, Rocky Linux 8+, Fedora |

### Network Requirements

**Full Install Mode:**
- Ports 80/443 (HTTP/HTTPS)
- Ports 9000-9001 (MinIO - internal only)
- Port 3306 (MySQL - internal only)

**User Mode:**
- Ports 8080/8443 (HTTP/HTTPS)
- Other ports same as full install

---

## 🔐 First-Time Login

Cap uses **6-digit verification codes** for authentication (no passwords required).

### Without Email Configured

1. Visit your Cap instance URL
2. Click "Login with email" and enter your email address
3. **Get the 6-digit code from server logs:**
   ```bash
   # Full Install Mode:
   /opt/cap/cap-get-login.sh

   # User Mode:
   ~/cap/cap-get-login.sh
   ```
4. Enter the code on the verification page

**Example code output:**
```
🔐 VERIFICATION CODE (Development Mode)
📧 Email: your@email.com
🔢 Code: 744381
⏱  Expires in: 10 minutes
```

### With Email (Resend) Configured

1. Visit your Cap instance URL
2. Click "Login with email" and enter your email address
3. Check your email for the 6-digit verification code
4. Enter the code on the verification page

---

## 🎬 Recordings Storage

### Storage Location

**Full Install Mode:**
```
Physical: /var/lib/docker/volumes/cap_cap-minio-data/_data
Access via: MinIO Console
```

**User Mode:**
```
Physical: /var/lib/docker/volumes/cap_cap-minio-data/_data
Access via: MinIO Console
```

### MinIO Console Access

**Full Install:**
- URL: `http://your-server.com/minio-console`

**User Mode:**
- URL: `http://your-server.com:8080/minio-console`

**Credentials:** Found in your credentials file

---

## 🛠️ Management Commands

The installer creates helper scripts for easy management:

**Full Install Mode:**
```bash
/opt/cap/cap-start.sh      # Start all services
/opt/cap/cap-stop.sh       # Stop all services
/opt/cap/cap-restart.sh    # Restart all services
/opt/cap/cap-logs.sh       # View logs
/opt/cap/cap-get-login.sh  # Get magic login link
```

**User Mode:**
```bash
~/cap/cap-start.sh      # Start all services
~/cap/cap-stop.sh       # Stop all services
~/cap/cap-restart.sh    # Restart all services
~/cap/cap-logs.sh       # View logs
~/cap/cap-get-login.sh  # Get magic login link
```

**Re-run installer for management menu:**
```bash
# Full mode:
sudo bash cap-install.sh

# User mode:
bash cap-install.sh
```

---

## 🌐 Domain & SSL Setup

### Using a Domain (Recommended for Production)

1. **Point your domain to server:**
   - Type: `A`
   - Name: `@` (or subdomain)
   - Value: Your server IP
   - TTL: `300`

2. **Enable SSL during installation:**
   ```
   Enable SSL? [y/N]: y
   Email for Let's Encrypt: your@email.com
   ```

3. **SSL certificate renews automatically** via certbot

### Using IP Address (Quick Setup)

- No DNS setup needed
- SSL/HTTPS not available
- Access via: `http://your-ip`
- **User mode adds port:** `http://your-ip:8080`

---

## 🔒 Security

### Credentials File

All credentials are saved securely:

**Full Install:** `/opt/cap/credentials.txt`
**User Mode:** `~/cap/credentials.txt`

**Security measures:**
- ✅ Permissions: 600 (owner read/write only)
- ✅ Not web-accessible (outside web root)
- ✅ Nginx has no file serving
- ✅ Contains: Database, MinIO, and application secrets

**View credentials:**
```bash
# Full install:
sudo cat /opt/cap/credentials.txt

# User mode:
cat ~/cap/credentials.txt
```

---

## ⚙️ Configuration

### Environment Variables

The script automatically configures all required variables:

**Database:**
- `DATABASE_URL` - MySQL connection string
- Auto-generated secure passwords

**Application:**
- `WEB_URL` - Your access URL
- `NEXTAUTH_SECRET` - Authentication secret
- `NODE_ENV` - Set to production

**S3 Storage:**
- `CAP_AWS_BUCKET` - Storage bucket name
- `CAP_AWS_REGION` - Region (works with MinIO)
- `S3_ENDPOINT` - MinIO endpoint
- Auto-generated access keys

### Optional: Email Login Links (Resend)

Configure during installation or add later:

1. Create account at [resend.com](https://resend.com)
2. Get API key
3. Set environment variables:
   ```bash
   RESEND_API_KEY=your_api_key
   RESEND_FROM_DOMAIN=your-domain.com
   ```

---

## 🐛 Troubleshooting

### Services Not Starting

**Check service status:**
```bash
# Full install:
cd /opt/cap && docker compose ps

# User mode:
cd ~/cap && docker compose ps
```

**View logs:**
```bash
# Full install:
/opt/cap/cap-logs.sh

# User mode:
~/cap/cap-logs.sh
```

### MySQL Issues

**Clean restart:**
```bash
# Full install:
cd /opt/cap
docker compose down -v
docker compose up -d

# User mode:
cd ~/cap
docker compose down -v
docker compose up -d
```

### Port Conflicts

**Full Install (ports 80/443):**
- Check for Apache/nginx: `sudo systemctl status apache2 nginx`
- Stop conflicting services: `sudo systemctl stop apache2`

**User Mode (ports 8080/8443):**
- Check port usage: `ss -tulpn | grep 8080`
- Change ports in `docker-compose.yml` if needed

### Firewall Issues

**Full Install:**
- UFW: `sudo ufw status`
- Firewalld: `sudo firewall-cmd --list-all`

**User Mode:**
- Manually allow ports: `sudo ufw allow 8080/tcp`

---

## ❓ Frequently Asked Questions

**New users?** Check out the **[FAQ.md](FAQ.md)** for answers to common questions:
- What do I need before running the script?
- Where are my recordings saved?
- How do I login to Cap.so?
- Do I need email configured?
- How do I backup my recordings?
- And many more!

## 📚 Additional Resources

- **[FAQ.md](FAQ.md)** - Frequently Asked Questions
- **[QUICK_START.md](QUICK_START.md)** - Quick Reference Guide
- [Cap.so Official Documentation](https://cap.so/docs)
- [Cap.so GitHub Repository](https://github.com/CapSoftware/Cap)
- [Self-Hosting Guide](https://cap.so/docs/self-hosting)
- [Docker Documentation](https://docs.docker.com/)

---

## 🔄 Updating Cap

To update to the latest version:

```bash
# Full install:
cd /opt/cap
docker compose pull
docker compose up -d

# User mode:
cd ~/cap
docker compose pull
docker compose up -d
```

---

## 🗑️ Uninstallation

**Full Install:**
```bash
cd /opt/cap
docker compose down -v
sudo rm -rf /opt/cap
# Remove firewall rules if needed
```

**User Mode:**
```bash
cd ~/cap
docker compose down -v
rm -rf ~/cap
```

---

## 📝 Examples

### Example 1: Quick IP-Based Setup (Full Install)

```bash
# Run installer
sudo bash cap-install.sh

# Press Enter to use detected IP
# Choose no for SSL (IP addresses don't support SSL)
# Choose no for email (view links in logs)

# Access at: http://YOUR_IP
# Login link: /opt/cap/cap-get-login.sh
```

### Example 2: Production Domain Setup (Full Install)

```bash
# First, point your domain to server IP
# Then run installer
sudo bash cap-install.sh

# Enter your domain: cap.example.com
# Enable SSL: y
# Email: admin@example.com
# Enable Resend: y (optional)

# Access at: https://cap.example.com
```

### Example 3: Development Setup (User Mode)

```bash
# Ensure you're in docker group
sudo usermod -aG docker $USER
# Logout and login

# Run installer
bash cap-install.sh

# Choose mode: 1 (User Mode)
# Press Enter to use IP
# No SSL needed for development

# Access at: http://YOUR_IP:8080
# Login link: ~/cap/cap-get-login.sh
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Credits

- **Cap.so** - [CapSoftware](https://github.com/CapSoftware/Cap)
- **Inspired by** - [WireGuard Installer](https://github.com/hwdsl2/wireguard-install)

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/webvijayi/cap-install/issues)
- **Cap.so Discord**: [Join Community](https://discord.gg/cap)
- **Documentation**: [cap.so/docs](https://cap.so/docs)

---

## ⭐ Support This Project

If this installer saved you time, please consider:

- ⭐ **Star this repository** to help others discover it
- 🐛 **Report issues** to help improve the installer
- 📢 **Share** with others who might benefit
- 🤝 **Contribute** improvements via pull requests

---

**Made with ❤️ for the self-hosting community**

🔗 Repository: https://github.com/webvijayi/cap-install
