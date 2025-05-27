#!/bin/bash
set -e

GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

function with_spinner() {
    local pid
    "$@" &
    pid=$!
    local spin='|/-\'
    local i=0
    tput civis
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${CYAN}[${spin:$i:1}]${RESET} Running: $1"
        sleep 0.1
    done
    wait $pid
    local exit_code=$?
    tput cnorm
    if [ $exit_code -eq 0 ]; then
        echo -e "\r${GREEN}✔ Success:${RESET} $1"
    else
        echo -e "\r${RED}✘ Failed:${RESET} $1"
        exit $exit_code
    fi
}

function banner() {
    echo -e "\n${BLUE}──────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}${BOLD}🔧  $1${RESET}"
    echo -e "${BLUE}──────────────────────────────────────────────${RESET}"
}

function prompt_choice() {
    echo -ne "${CYAN}$1 (y/n)${RESET} "
    read -rp "> " response
    [[ "$response" =~ ^[Yy]$ ]]
}

AUTO_PHP_VERSION=""
AUTO_WEB_SERVER=""
AUTO_INSTALL_MARIADB=false
AUTO_INSTALL_PHPMYADMIN=false
AUTO_REMOTE_SQL=false
AUTO_GLPI_MODULES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --php-version) AUTO_PHP_VERSION="$2"; shift 2 ;;
    --web-server) AUTO_WEB_SERVER="$2"; shift 2 ;;
    --install-mariadb) AUTO_INSTALL_MARIADB=true; shift ;;
    --install-phpmyadmin) AUTO_INSTALL_PHPMYADMIN=true; shift ;;
    --remote-sql) AUTO_REMOTE_SQL=true; shift ;;
    --with-glpi-modules) AUTO_GLPI_MODULES=true; shift ;;
    *) echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

function check_os() {
    . /etc/os-release || { echo -e "${RED}Cannot detect OS!${RESET}"; exit 1; }
    OS=$ID
    VERSION=$VERSION_ID
}

function install_web_server() {
    if [[ -n "$AUTO_WEB_SERVER" ]]; then
        choice="$AUTO_WEB_SERVER"
    else
        echo "Choose web server: apache or nginx"
        read -rp "> " choice
    fi

    case "$choice" in
        apache|Apache2)
            WEB_SERVER="apache2"
            banner "Installing Apache2"
            if [[ $OS == rocky ]]; then
                with_spinner dnf install -y httpd
                systemctl enable --now httpd
            else
                with_spinner apt update
                with_spinner apt install -y apache2
                systemctl enable --now apache2
            fi
            ;;
        nginx|Nginx)
            WEB_SERVER="nginx"
            banner "Installing Nginx"
            if [[ $OS == rocky ]]; then
                with_spinner dnf install -y nginx
                systemctl enable --now nginx
            else
                with_spinner apt update
                with_spinner apt install -y nginx
                systemctl enable --now nginx
            fi
            ;;
        *) echo -e "${RED}Invalid web server selected${RESET}"; exit 1 ;;
    esac
}

function install_php() {
    RECOMMENDED_VERSIONS=("8.1" "8.2" "8.3")
    PHP_REQUIRED_MODULES=(curl gd intl mysqli zlib)
    PHP_OPTIONAL_MODULES=(bz2 zip exif ldap openssl opcache)

    if [[ -n "$AUTO_PHP_VERSION" ]]; then
        PHP_VERSION="$AUTO_PHP_VERSION"
    else
        echo "Recommended PHP versions: ${RECOMMENDED_VERSIONS[*]}"
        read -rp "Enter PHP version (e.g. 8.2): " PHP_VERSION
    fi

    while true; do
        banner "Installing PHP $PHP_VERSION"
        if [[ $OS == rocky ]]; then
            if dnf module list php | grep -q "$PHP_VERSION"; then
                with_spinner dnf install -y epel-release dnf-utils
                with_spinner dnf module reset -y php
                with_spinner dnf module enable -y php:$PHP_VERSION
                with_spinner dnf install -y php php-cli php-mysqlnd php-fpm php-gd php-xml php-mbstring
                systemctl enable --now php-fpm
                break
            else
                echo -e "${RED}Invalid PHP version${RESET}"
                [[ -n "$AUTO_PHP_VERSION" ]] && exit 1
            fi
        else
            if apt-cache show php$PHP_VERSION &>/dev/null; then
                with_spinner apt install -y software-properties-common
                with_spinner add-apt-repository -y ppa:ondrej/php
                with_spinner apt update
                with_spinner apt install -y php$PHP_VERSION php$PHP_VERSION-cli php$PHP_VERSION-mysql php$PHP_VERSION-fpm php$PHP_VERSION-gd php$PHP_VERSION-xml php$PHP_VERSION-mbstring
                systemctl enable --now php$PHP_VERSION-fpm
                break
            else
                echo -e "${RED}Invalid PHP version${RESET}"
                [[ -n "$AUTO_PHP_VERSION" ]] && exit 1
            fi
        fi
        [[ -z "$AUTO_PHP_VERSION" ]] && read -rp "Enter another version: " PHP_VERSION
    done

    if [[ "$AUTO_GLPI_MODULES" == true ]] || prompt_choice "Install GLPI required modules?"; then
        TO_INSTALL=("${PHP_REQUIRED_MODULES[@]}")
        [[ "$AUTO_GLPI_MODULES" == true ]] || prompt_choice "Also install optional GLPI modules?" && TO_INSTALL+=("${PHP_OPTIONAL_MODULES[@]}")
        banner "Installing PHP Extensions"
        for module in "${TO_INSTALL[@]}"; do
            if [[ $OS == rocky ]]; then
                with_spinner dnf install -y php-$module
            else
                with_spinner apt install -y php$PHP_VERSION-$module
            fi
        done
    fi
}

function install_mariadb_phpmyadmin() {
    if [[ "$AUTO_INSTALL_MARIADB" == true ]] || prompt_choice "Install MariaDB?"; then
        banner "Installing MariaDB"
        if [[ $OS == rocky ]]; then
            with_spinner dnf install -y mariadb-server mariadb
        else
            with_spinner apt install -y mariadb-server
        fi
        systemctl enable --now mariadb
        INSTALL_SQL=true
    fi
}


function apply_sql_remote_config() {
    if [[ "$AUTO_REMOTE_SQL" == true ]] || prompt_choice "Enable remote SQL access?"; then
        sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/*my.cnf* 2>/dev/null || true
        systemctl restart mariadb
        if command -v firewall-cmd &> /dev/null; then
            with_spinner firewall-cmd --permanent --add-service=mysql
            with_spinner firewall-cmd --reload
        elif command -v ufw &> /dev/null; then
            ufw allow mysql
        fi
        echo -e "${GREEN}Remote SQL enabled.${RESET}"
    fi
}


function install_phpmyadmin() {
    if [[ "$AUTO_INSTALL_PHPMYADMIN" == true ]] || prompt_choice "Install phpMyAdmin?"; then
        banner "Installing phpMyAdmin"
        if [[ $OS == rocky ]]; then
            PHPMYADMIN_VERSION=$(curl -s https://www.phpmyadmin.net/home_page/version.txt)
            cd /tmp
            curl -LO https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz
            tar xzf phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz
            mv phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /usr/share/phpMyAdmin
            mkdir -p /usr/share/phpMyAdmin/tmp
            chown -R apache:apache /usr/share/phpMyAdmin
            chmod 777 /usr/share/phpMyAdmin/tmp
            cat > /etc/httpd/conf.d/phpMyAdmin.conf <<EOF
Alias /phpmyadmin /usr/share/phpMyAdmin
<Directory /usr/share/phpMyAdmin/>
   AddDefaultCharset UTF-8
   Require all granted
</Directory>
EOF
            systemctl restart httpd
        else
            with_spinner apt install -y phpmyadmin
        fi
        echo -e "${GREEN}phpMyAdmin installed.${RESET}"
    fi
}


function check_services() {
    banner "Service Status"
    for svc in "$WEB_SERVER" "php$PHP_VERSION-fpm" "mariadb"; do
        systemctl is-active --quiet "$svc" \
            && echo -e "$svc: ${GREEN}running${RESET}" \
            || echo -e "$svc: ${RED}not running${RESET}"
    done
}

check_os
echo -e "\n${BOLD}🧠 Detected OS:${RESET} ${GREEN}${OS^} $VERSION${RESET}"
install_web_server
install_php
install_mariadb_phpmyadmin
[[ "$INSTALL_SQL" == true ]] && apply_sql_remote_config
install_phpmyadmin
check_services
echo -e "\n${GREEN}✅ Web stack setup complete.${RESET}"
