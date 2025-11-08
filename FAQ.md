# Cap.so Self-Hosting - Frequently Asked Questions (FAQ)

## 📋 Pre-Installation Questions

### What do I need before running the script?

#### For Full Install Mode (with sudo):
- ✅ A server running Ubuntu 20.04+, Debian 10+, CentOS 8+, Rocky Linux 8+, or Fedora
- ✅ Root/sudo access
- ✅ At least 2GB RAM (4GB recommended)
- ✅ At least 10GB free disk space (50GB+ recommended for recordings)
- ✅ Internet connection
- ❌ **Nothing else!** The script will install everything (Docker, packages, etc.)

#### For User Mode (without sudo):
- ✅ Same server requirements as above
- ✅ **Docker already installed**
- ✅ Your user account in the docker group: `sudo usermod -aG docker $USER` (then logout/login)
- ❌ No root access needed

### Do I need a domain name?

**No, a domain is optional!** You have two choices:

**Option 1: Use IP Address (Easier)**
- ✅ No domain needed
- ✅ Works immediately
- ✅ Access via: `http://YOUR_SERVER_IP`
- ❌ No SSL/HTTPS support

**Option 2: Use Custom Domain (Recommended for Production)**
- ✅ Professional appearance
- ✅ SSL/HTTPS support
- ✅ Access via: `https://cap.yourdomain.com`
- ⚠️ Requires DNS configuration (script shows you how)

### What will the script install?

**Full Install Mode:**
- Docker (if not already installed)
- Docker Compose
- Cap Web application
- MySQL 9 database
- MinIO object storage
- Nginx reverse proxy
- Certbot (if SSL enabled)

**User Mode:**
- Cap Web application
- MySQL 9 database
- MinIO object storage
- Nginx reverse proxy
- (Assumes Docker already installed)

---

## 🎬 Installation Questions

### How long does installation take?

- **Full Install:** 5-15 minutes (depending on internet speed)
- **User Mode:** 3-10 minutes

### What happens during installation?

The script will:
1. Check your system
2. Offer installation mode selection
3. Ask for domain/IP
4. Ask about SSL/HTTPS (if using domain)
5. Ask about email login links (optional)
6. Install/configure everything
7. Start all services
8. Show you access URL and instructions

### Can I customize the installation?

Yes! The script asks you:
- Domain or IP address
- Enable SSL? (Yes/No)
- Enable email login? (Yes/No)
- Email address for SSL notifications (if SSL enabled)
- Resend API key (if email enabled)

Everything else is configured automatically with secure defaults.

---

## 🎥 Recordings Storage Questions

### Where are my Cap.so recordings saved?

Your recordings are stored in **two places**:

#### 1. Physical Storage Location

**Full Install Mode:**
```
/var/lib/docker/volumes/cap_cap-minio-data/_data
```

**User Mode:**
```
/var/lib/docker/volumes/cap_cap-minio-data/_data
```

This is where the actual video files are stored on your server's disk.

#### 2. MinIO Console (Web Access)

**Full Install:**
- URL: `http://your-server.com/minio-console`

**User Mode:**
- URL: `http://your-server.com:8080/minio-console`

You can browse, download, and manage recordings through the MinIO web interface.

### How do I access the recordings?

**Method 1: Through Cap.so Interface**
- Login to your Cap instance
- Navigate to your recordings
- View, share, or download from the UI

**Method 2: Through MinIO Console**
1. Visit the MinIO console URL (shown after installation)
2. Login with MinIO credentials (in `/opt/cap/credentials.txt` or `~/cap/credentials.txt`)
3. Browse the `cap` bucket
4. Download files directly

**Method 3: Direct File Access (SSH)**
```bash
# Full install:
sudo ls /var/lib/docker/volumes/cap_cap-minio-data/_data/cap/

# User mode:
ls /var/lib/docker/volumes/cap_cap-minio-data/_data/cap/
```

### How much storage space will I need?

**Estimates:**
- 1 minute of 1080p recording ≈ 10-20 MB
- 10 recordings (5 min each) ≈ 500 MB - 1 GB
- 100 recordings (10 min each) ≈ 10-20 GB

**Recommendations:**
- Development/Testing: 10-20 GB
- Small Team: 50-100 GB
- Production: 200 GB+

### Can I move recordings to external storage?

Yes! MinIO supports:
- S3-compatible external storage
- NFS mounts
- Network attached storage

You can configure this in the MinIO settings after installation.

---

## 🔐 Login & Authentication Questions

### What are the dependencies for login to work?

**IMPORTANT: Login works WITHOUT any external dependencies!**

#### ✅ Always Works (No Dependencies)

**Verification codes in server logs:**
- ❌ No email service needed
- ❌ No Resend account needed
- ❌ No external APIs needed
- ✅ Codes appear in Docker logs
- ✅ Use helper script to view codes
- ✅ Perfect for testing, development, and single-user setups

**Required (automatically configured):**
- MySQL database (included in installation)
- NextAuth secret (auto-generated)
- Web URL (configured during installation)

#### 📧 Optional: Email Delivery (Resend)

**Only needed if you want codes sent to email instead of logs:**

**Dependencies:**
1. **Resend Account** - Free tier available at https://resend.com
   - Free: 100 emails/day
   - Free: 3,000 emails/month
   - Perfect for small teams

2. **Verified Domain in Resend**
   - Add your domain to Resend
   - Add DNS records (MX, TXT for verification)
   - Verify domain ownership

3. **Resend API Key**
   - Generate in Resend dashboard
   - Free tier included

**What Resend Does:**
- ✅ Sends 6-digit codes to user's email
- ✅ Professional branded emails
- ✅ Better user experience for teams
- ✅ No need to check server logs

**What Resend Doesn't Affect:**
- ❌ Doesn't change login security
- ❌ Not required for login to work
- ❌ Doesn't affect recordings
- ❌ Not needed for single users

---

### How do I login to Cap.so self-hosted version?

Cap.so uses **6-digit verification codes** for login (no passwords!). Here's how:

#### Step 1: Visit Your Cap Instance

**Full Install:**
```
http://YOUR_SERVER_IP
or
https://your-domain.com
```

**User Mode:**
```
http://YOUR_SERVER_IP:8080
```

#### Step 2: Enter Your Email

On the login page, type your email address and click "Login with email"

#### Step 3: Get the Verification Code

**If Email is NOT Configured (Default):**

The 6-digit code appears in server logs. Use the helper script:

```bash
# Full install:
/opt/cap/cap-get-login.sh

# User mode:
~/cap/cap-get-login.sh
```

This will watch the logs and show you the verification code. Example output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 VERIFICATION CODE (Development Mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📧 Email: your@email.com
🔢 Code: 744381
⏱  Expires in: 10 minutes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**If Email IS Configured (Resend):**

1. Check your email inbox
2. Find the 6-digit verification code
3. Enter it on the login page

#### Step 4: Enter the Code

After clicking "Login with email", you'll see a verification code entry page. Type the 6-digit code and you're logged in!

### Why no username/password?

Cap.so uses **passwordless authentication** for security and convenience:
- ✅ No passwords to remember or forget
- ✅ No password database to protect
- ✅ Reduces risk of credential theft
- ✅ Easier and more secure

### Do I need to configure email to use Cap?

**No!** Email configuration is **optional**:

**Without Email (Default):**
- ✅ Works immediately
- ✅ Verification codes in server logs
- ✅ Use helper script to get codes
- ✅ Perfect for single-user or development

**With Email (Resend):**
- ✅ Professional user experience
- ✅ Verification codes sent to email
- ✅ Better for teams
- ✅ No need to check server logs
- ⚠️ Requires Resend API key (free tier available at https://resend.com)

### How do I set up email login?

During installation, when asked:
```
Do you want to enable email login links (Resend)? [y/N]: y
```

Then provide:
1. Resend API Key (get from https://resend.com)
2. Resend FROM domain (your verified domain)

Or enable it later by editing `/opt/cap/docker-compose.yml` (or `~/cap/docker-compose.yml`)

### Can multiple users login?

**Yes!** Each user:
1. Visits your Cap instance
2. Enters their email
3. Gets their own magic link
4. Logs in independently

No limit on number of users.

---

## 🛠️ Post-Installation Questions

### Where are my credentials saved?

**Full Install:**
```
/opt/cap/credentials.txt
```

**User Mode:**
```
~/cap/credentials.txt
```

**View credentials:**
```bash
# Full install:
sudo cat /opt/cap/credentials.txt

# User mode:
cat ~/cap/credentials.txt
```

The file contains:
- MySQL passwords
- MinIO credentials
- S3 access keys
- NextAuth secret
- Access URLs

### How do I manage my Cap installation?

**Helper scripts provided:**

```bash
# Full install:
/opt/cap/cap-start.sh      # Start services
/opt/cap/cap-stop.sh       # Stop services
/opt/cap/cap-restart.sh    # Restart services
/opt/cap/cap-logs.sh       # View logs
/opt/cap/cap-get-login.sh  # Get login link

# User mode:
~/cap/cap-start.sh      # Start services
~/cap/cap-stop.sh       # Stop services
~/cap/cap-restart.sh    # Restart services
~/cap/cap-logs.sh       # View logs
~/cap/cap-get-login.sh  # Get login link
```

**Re-run installer for management menu:**
```bash
sudo bash cap-install.sh  # Full mode
bash cap-install.sh       # User mode
```

### How do I update Cap.so?

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

### How do I backup my recordings?

**Method 1: Backup MinIO Data Directory**
```bash
# Full install:
sudo tar -czf cap-recordings-backup.tar.gz \
  /var/lib/docker/volumes/cap_cap-minio-data/_data

# User mode:
sudo tar -czf cap-recordings-backup.tar.gz \
  /var/lib/docker/volumes/cap_cap-minio-data/_data
```

**Method 2: Use MinIO mc (MinIO Client)**
```bash
docker run --rm -it \
  --network cap_cap-network \
  -v $(pwd):/backup \
  minio/mc cp --recursive cap-minio/cap /backup/
```

**Method 3: Download via MinIO Console**
- Login to MinIO console
- Browse recordings
- Download individually or in bulk

---

## 🔧 Troubleshooting Questions

### The installation failed, what should I do?

1. **Check the error message** in the installation output
2. **Common fixes:**
   ```bash
   # Not enough disk space:
   df -h

   # Port conflicts:
   sudo netstat -tulpn | grep -E '80|443|3306|9000'

   # Docker not running:
   sudo systemctl status docker
   sudo systemctl start docker
   ```
3. **Re-run the installer** - it's safe to run multiple times
4. **Check logs:**
   ```bash
   /opt/cap/cap-logs.sh  # or ~/cap/cap-logs.sh
   ```

### I can't access my Cap instance

**Check if services are running:**
```bash
# Full install:
cd /opt/cap && docker compose ps

# User mode:
cd ~/cap && docker compose ps
```

**Check firewall:**
```bash
# Full install:
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# User mode:
sudo ufw allow 8080/tcp
sudo ufw allow 8443/tcp
```

**Check your access URL:**
- Full install: `http://YOUR_IP` or `https://your-domain.com`
- User mode: `http://YOUR_IP:8080`

### I lost my verification code, how do I get a new one?

Easy! Just re-request it:

1. Visit your Cap instance
2. Enter your email again
3. Run the helper script:
   ```bash
   /opt/cap/cap-get-login.sh  # Full install
   ~/cap/cap-get-login.sh     # User mode
   ```
4. Copy the new 6-digit code from the logs
5. Enter it on the verification page

**Note:** Each code expires in 10 minutes for security.

### How do I enable SSL after installation?

Re-run the installer:
```bash
sudo bash cap-install.sh
```

Choose "Reconfigure" or "Enable SSL" from the management menu.

---

## 💰 Cost Questions

### Is Cap.so self-hosting free?

**Yes!** Cap.so is open source and free to self-host.

**You only pay for:**
- ✅ Your server/VPS costs (varies by provider)
- ✅ Optional: Domain name ($10-15/year)
- ✅ Optional: Resend email service (free tier available, then $20/month)

**No Cap.so licensing fees!**

### What are typical server costs?

**VPS Recommendations:**

| Provider | Plan | Cost | Specs |
|----------|------|------|-------|
| DigitalOcean | Basic Droplet | $12/month | 2GB RAM, 50GB disk |
| Hetzner | CX21 | €5/month | 4GB RAM, 40GB disk |
| Vultr | Cloud Compute | $12/month | 2GB RAM, 55GB disk |
| Linode | Shared CPU | $12/month | 2GB RAM, 50GB disk |

For small teams (5-10 users), expect $10-20/month.

---

## 🔒 Security Questions

### Is my data secure?

**Yes!** When you self-host:
- ✅ You own all data
- ✅ Data stays on your server
- ✅ No third-party access
- ✅ You control security
- ✅ Can use SSL/HTTPS
- ✅ Can configure firewall

**Security features:**
- Magic link authentication (no password leaks)
- MySQL with secure passwords
- MinIO with access keys
- Nginx reverse proxy
- Optional SSL/TLS encryption

### Should I use SSL/HTTPS?

**Yes, for production!**

**Use SSL if:**
- ✅ You have a domain name
- ✅ Users access from public internet
- ✅ You handle sensitive recordings
- ✅ You want professional appearance

**Skip SSL if:**
- Testing/development only
- Local network access only
- Using IP address (SSL requires domain)

---

## 📞 Getting Help

### Where can I get support?

1. **This FAQ** - Most common questions answered
2. **[README.md](README.md)** - Full documentation
3. **[QUICK_START.md](QUICK_START.md)** - Quick reference
4. **[Cap.so Documentation](https://cap.so/docs)** - Official docs
5. **[GitHub Issues](https://github.com/webvijayi/cap-install/issues)** - Report bugs
6. **[Cap.so Discord](https://discord.gg/cap)** - Community support

### How do I report a bug?

1. Check if it's in this FAQ
2. Search [existing issues](https://github.com/webvijayi/cap-install/issues)
3. Create new issue with:
   - Your OS/version
   - Installation mode (Full/User)
   - Error messages
   - Steps to reproduce

---

## 🎯 Quick Answer Summary

| Question | Quick Answer |
|----------|--------------|
| **What do I need?** | Server with 2GB+ RAM, internet. Full mode needs sudo, User mode needs Docker. |
| **Do I need a domain?** | No! Can use IP address. Domain needed for SSL. |
| **Where are recordings saved?** | `/var/lib/docker/volumes/cap_cap-minio-data/_data` |
| **How do I login?** | 6-digit code! Visit site, enter email, get code from logs or email, enter code. |
| **How to get verification code?** | Run `/opt/cap/cap-get-login.sh` (or `~/cap/cap-get-login.sh`) |
| **Do I need email setup?** | No! Optional. Codes appear in logs if email not configured. |
| **How to backup?** | Backup `/var/lib/docker/volumes/cap_cap-minio-data/_data` |
| **How to update?** | `cd /opt/cap && docker compose pull && docker compose up -d` |
| **Is it free?** | Yes! Only pay for your server costs. |
| **Is it secure?** | Yes! You own all data. Use SSL for extra security. |

---

**Still have questions?** Open an issue or check the full [README.md](README.md)!
