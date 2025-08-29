#!/bin/bash
# Установка 3x-ui (прод)
echo -e "${GREEN}🚀 Подготовка к установке...${NC}"
set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Define the database path and the SQL statements template (to be modified based on last ID)
DB_PATH="/etc/x-ui/x-ui.db"
SQL_INSERT_TEMPLATE="
INSERT INTO settings VALUES (%d, 'webCertFile', '/etc/ssl/certs/3x-ui-public.key');
INSERT INTO settings VALUES (%d, 'webKeyFile', '/etc/ssl/private/3x-ui-private.key');
"

# Function to check if sqlite3 is installed
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null
    then
        echo "sqlite3 could not be found, installing..."
        install_sqlite3
    else
        echo "sqlite3 is already installed."
    fi
}

# Function to install sqlite3
install_sqlite3() {
    # Detect the package manager and install sqlite3
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y sqlite3
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y sqlite
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y sqlite
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm sqlite
    else
        echo "Package manager not found. Please install sqlite3 manually."
        exit 1
    fi
}

# Function to check if openssl is installed
check_openssl() {
    if ! command -v openssl &> /dev/null
    then
        echo "openssl could not be found, installing..."
        install_openssl
    else
        echo "openssl is already installed."
    fi
}

# Function to install openssl
install_openssl() {
    # Detect the package manager and install openssl
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y openssl
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y openssl
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y openssl
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm openssl
    else
        echo "Package manager not found. Please install openssl manually."
        exit 1
    fi
}

check_if_ssl_present() {
    local ssl_detected=$(grep -a 'webCertFile' "$DB_PATH")
    if [ -n "$ssl_detected" ]; then  # Check if the variable is non-empty
        echo "SSL cert detected in settings, exiting"
        exit 0
    fi
}

# Function to get the last ID in the settings table
get_last_id() {
    LAST_ID=$(sqlite3 "$DB_PATH" "SELECT IFNULL(MAX(id), 0) FROM settings;")
    echo "The last ID in the settings table is $LAST_ID"
}

# Function to execute SQL inserts
execute_sql_inserts() {
    local next_id=$((LAST_ID + 1))
    local second_id=$((next_id + 1))
    printf "$SQL_INSERT_TEMPLATE" "$next_id" "$second_id" | sqlite3 "$DB_PATH"
    echo "SQL inserts executed with IDs $next_id and $second_id."
}

gen_ssl_cert() {
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout /etc/ssl/private/3x-ui-private.key -out /etc/ssl/certs/3x-ui-public.key -days 3650 -subj "/CN=APP"
}

echo -e "${GREEN}🚀 Установка 3x-ui...${NC}"

# --- Обновление системы ---
echo -e "${YELLOW}📦 Обновляем систему...${NC}"
apt update && apt upgrade -y
apt install -y wget curl tar ufw

# --- Генерация случайного порта ---
PORT=$(shuf -i 10000-30000 -n 1)
echo -e "${GREEN}✅ Используем порт: ${PORT}${NC}"

# --- Настройка UFW ---
echo -e "${YELLOW}🔥 Настраиваем UFW...${NC}"
ufw allow 22
ufw allow $PORT
ufw allow 8888
ufw allow 9999
echo "y" | ufw enable > /dev/null 2>&1 || true

# --- Скачиваем установщик---
echo -e "${YELLOW}📥 Устанавливаем 3x-ui...${NC}"

# Указываем актуальную версию (проверено: работает)
TAG_VERSION="v2.6.6"
# Прямая ссылка на архив
DOWNLOAD_URL="https://github.com/MHSanaei/3x-ui/releases/download/${TAG_VERSION}/x-ui-linux-amd64.tar.gz"

# Создаём папку и скачиваем
cd /usr/local/
wget -O x-ui-linux-amd64.tar.gz $DOWNLOAD_URL

# Останавливаем, если уже был установлен
systemctl stop x-ui 2>/dev/null || true
rm -rf /usr/local/x-ui/

# Распаковываем
tar zxvf x-ui-linux-amd64.tar.gz
rm -f x-ui-linux-amd64.tar.gz
cd x-ui
chmod +x x-ui bin/xray-linux-amd64

# Копируем сервис
cp -f x-ui.service /etc/systemd/system/

# Устанавливаем скрипт управления
wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
chmod +x /usr/bin/x-ui
chmod +x /usr/local/x-ui/x-ui.sh

# --- Настройка ---
echo -e "${YELLOW}⚙️  Настраиваем панель...${NC}"

# Генерация случайных данных
USERNAME="administrator"
PASSWORD="administrator"
WEB_BASE_PATH=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 12 | head -n 1)

# Создаём конфигурацию
/usr/local/x-ui/x-ui setting -username "$USERNAME" -password "$PASSWORD" -port "$PORT" -webBasePath "$WEB_BASE_PATH" > /dev/null 2>&1

# --- Включаем автозагрузку ---
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

# --- Генерация SSL-сертификата (10 лет) ---
echo -e "${YELLOW}🔐 Генерируем SSL-сертификат на 10 лет...${NC}"
check_sqlite3
check_if_ssl_present
check_openssl
gen_ssl_cert
get_last_id
execute_sql_inserts

# --- Перезапуск ---
echo -e "${YELLOW}✳️ Перезапускаем панель${NC}"
systemctl restart x-ui

# --- Финальное сообщение ---
IP=$(curl -s https://api.ipify.org)
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Установка завершена!${NC}"
echo -e "${GREEN}🌐 Панель: https://${IP}:${PORT}/${WEB_BASE_PATH}${NC}"
echo -e "${GREEN}🔒 SSL: самоподписанный${NC}"
echo -e "${YELLOW}⚠️ При входе: нажмите 'Дополнительно' → 'Продолжить'${NC}"
echo -e "${GREEN}🔐 Логин: ${USERNAME}${NC}"
echo -e "${GREEN}🔐 Пароль: ${PASSWORD}${NC}"
echo -e "${GREEN}========================================${NC}"
