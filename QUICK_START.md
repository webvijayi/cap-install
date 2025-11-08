# Cap.so Quick Start Guide

## 🚀 Installation (Choose One)

### Option 1: Full Install (With Root)
```bash
curl -fsSL https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh | sudo bash
```

### Option 2: User Mode (No Root)
```bash
curl -fsSL https://raw.githubusercontent.com/webvijayi/cap-install/main/cap-install.sh | bash
```

---

## 📊 Installation Modes Comparison

| Feature | Full Install | User Mode |
|---------|--------------|-----------|
| **Requires Root** | ✅ Yes | ❌ No |
| **Location** | `/opt/cap` | `~/cap` |
| **HTTP Port** | 80 | 8080 |
| **HTTPS Port** | 443 | 8443 |
| **Installs Docker** | Yes | No (needs existing) |
| **Firewall Config** | Yes | No (manual) |
| **SSL Support** | ✅ Yes | ✅ Yes |

---

## 🔑 First Login

### Step 1: Visit Your Instance
**Full Install:** `http://your-server.com`
**User Mode:** `http://your-server.com:8080`

### Step 2: Enter Email
Type your email address on the login page

### Step 3: Get Magic Link
```bash
# Full Install:
/opt/cap/cap-get-login.sh

# User Mode:
~/cap/cap-get-login.sh
```

### Step 4: Login
Copy the URL from logs and paste in browser

---

## ⚡ Quick Commands

### Start/Stop Services

**Full Install:**
```bash
/opt/cap/cap-start.sh      # Start
/opt/cap/cap-stop.sh       # Stop
/opt/cap/cap-restart.sh    # Restart
/opt/cap/cap-logs.sh       # Logs
```

**User Mode:**
```bash
~/cap/cap-start.sh      # Start
~/cap/cap-stop.sh       # Stop
~/cap/cap-restart.sh    # Restart
~/cap/cap-logs.sh       # Logs
```

---

## 🌐 Domain Setup

### 1. DNS Configuration
```
Type: A
Name: @ (or your subdomain)
Value: YOUR_SERVER_IP
TTL: 300
```

### 2. Enable SSL
Run installer again and enable SSL:
```bash
sudo bash cap-install.sh
```

---

## 📦 Recordings Location

### MinIO Console Access

**Full Install:**
- URL: `http://your-server.com/minio-console`
- Storage: `/var/lib/docker/volumes/cap_cap-minio-data/_data`

**User Mode:**
- URL: `http://your-server.com:8080/minio-console`
- Storage: `/var/lib/docker/volumes/cap_cap-minio-data/_data`

**Get credentials:**
```bash
# Full install:
sudo cat /opt/cap/credentials.txt

# User mode:
cat ~/cap/credentials.txt
```

---

## 🐛 Troubleshooting

### Services Not Running
```bash
# Full install:
cd /opt/cap && docker compose ps

# User mode:
cd ~/cap && docker compose ps
```

### View Logs
```bash
# Full install:
/opt/cap/cap-logs.sh

# User mode:
~/cap/cap-logs.sh
```

### Restart Everything
```bash
# Full install:
cd /opt/cap
docker compose down
docker compose up -d

# User mode:
cd ~/cap
docker compose down
docker compose up -d
```

---

## 🔄 Update Cap

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

## 💡 Tips

1. **Use a domain for production** - Better for SSL and professional appearance
2. **Enable email login** - Get Resend API key for magic links via email
3. **Backup regularly** - MinIO data and credentials.txt
4. **Monitor disk space** - Recordings can consume significant storage
5. **User mode for testing** - Perfect for development and staging

---

## 📞 Need Help?

- [Full README](README.md)
- [Cap.so Documentation](https://cap.so/docs)
- [GitHub Issues](https://github.com/webvijayi/cap-install/issues)

---

**Happy Recording! 🎬**
