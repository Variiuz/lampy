# 🚀 LAMPy - yet another LAMP/LEMP Web Stack Installer

This is a modern, interactive and scriptable installer for quickly setting up a **LAMP** (Apache, MariaDB, PHP) or **LEMP** (Nginx, MariaDB, PHP) stack on **Ubuntu, Debian**, or **Rocky Linux**.

---

## ✨ Features

- ✅ Apache or Nginx (choose during install or via flag)
- ✅ Custom PHP version (7.4, 8.1, 8.2, 8.3...)
- ✅ Required & optional GLPI PHP modules (for GLPI Install)
- ✅ MariaDB (optional)
- ✅ phpMyAdmin (optional, manual setup for Rocky)
- ✅ Fully scriptable with CLI arguments

---

## 📦 Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/Variiuz/lampy/refs/heads/master/install.sh | sudo bash
```

You’ll be prompted interactively to configure your stack.

---

## ⚙️ Fully Automated Install

Skip all prompts using flags:

```bash
curl -sSL https://raw.githubusercontent.com/Variiuz/lampy/refs/heads/master/install.sh | sudo bash -s -- \
  --web-server apache \
  --php-version 8.2 \
  --install-mariadb \
  --install-phpmyadmin \
  --remote-sql \
  --with-glpi-modules
```

---

## 🔧 CLI Flags

| Flag                   | Description                                       |
|------------------------|---------------------------------------------------|
| `--web-server`         | Choose `apache` or `nginx`                        |
| `--php-version`        | Specify PHP version (e.g., `8.2`)                 |
| `--install-mariadb`    | Installs MariaDB server                           |
| `--install-phpmyadmin` | Installs phpMyAdmin (manual method on Rocky)      |
| `--remote-sql`         | Enables remote SQL connections                    |
| `--with-glpi-modules`  | Installs required + optional PHP modules for GLPI |

---

## ✅ Examples

### Minimal setup (Nginx + PHP 8.3)

```bash
curl -sSL https://raw.githubusercontent.com/Variiuz/lampy/refs/heads/master/install.sh | sudo bash -s -- \
  --web-server nginx \
  --php-version 8.3
```

### Full LAMP with GLPI modules

```bash
curl -sSL https://raw.githubusercontent.com/Variiuz/lampy/refs/heads/master/install.sh | sudo bash -s -- \
  --web-server apache \
  --php-version 8.2 \
  --install-mariadb \
  --install-phpmyadmin \
  --remote-sql \
  --with-glpi-modules
```

---

## 📌 Compatibility

- Ubuntu 20.04, 22.04+
- Debian 11+
- Rocky Linux 8/9

- TESTED ON ROCKY 9.5

---

## 🔒 Notes

- Run this script as root or with `sudo`
- For production environments, always review the script before use
- phpMyAdmin on **Rocky** is installed manually (from official tarball)

---

## 📁 License

MIT – Do whatever you want, but you're responsible.
