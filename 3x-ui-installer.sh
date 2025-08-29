#!/bin/bash
# Установка 3x-ui (MHSanaei) — исправленная версия с ручным указанием тега
# Работает на Ubuntu 24.04

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Установка 3x-ui (исправленная версия)...${NC}"

# --- Обновление системы ---
echo -e "${YELLOW}📦 Обновляем систему...${NC}"
apt update && apt upgrade -y
apt install -y wget curl tar ufw

# --- Генерация случайного порта ---
PORT=$(shuf -i 10000-30000 -n 1)
echo -e "${GREEN}✅ Используем порт: ${PORT}${NC}"

# --- Настройка UFW ---
echo -e "${YELLOW}🔥 Настраиваем UFW...${NC}"
ufw allow 22/tcp
ufw allow $PORT/tcp
echo "y" | ufw enable > /dev/null 2>&1 || true

# --- Скачиваем исправленный установщик или используем прямую ссылку ---
echo -e "${YELLOW}📥 Устанавливаем 3x-ui (вручную, с правильной версией)...${NC}"

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
USERNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
WEB_BASE_PATH=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 12 | head -n 1)

# Создаём конфигурацию
/usr/local/x-ui/x-ui setting -username "$USERNAME" -password "$PASSWORD" -port "$PORT" -webBasePath "$WEB_BASE_PATH" > /dev/null 2>&1

# --- Включаем автозагрузку ---
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

# --- Генерация SSL-сертификата (10 лет) ---
echo -e "${YELLOW}🔐 Генерируем SSL-сертификат на 10 лет...${NC}"
SSL_DIR="/etc/3x-ui"
mkdir -p $SSL_DIR

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout $SSL_DIR/x-ui.key \
  -out $SSL_DIR/x-ui.crt \
  -days 3650 \
  -subj "/C=RU/ST=Earth/L=Internet/O=OmaVPN/CN=localhost"

# --- Перезапуск ---
systemctl restart x-ui

# --- Финальное сообщение ---
IP=$(curl -s https://api.ipify.org)
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Установка завершена!${NC}"
echo -e "${GREEN}🌐 Панель: https://${IP}:${PORT}/${WEB_BASE_PATH}${NC}"
echo -e "${GREEN}🔒 SSL: самоподписанный (до 2035 года)${NC}"
echo -e "${YELLOW}⚠️  При входе: нажмите 'Дополнительно' → 'Продолжить'${NC}"
echo -e "${GREEN}🔐 Логин: ${USERNAME}${NC}"
echo -e "${GREEN}🔐 Пароль: ${PASSWORD}${NC}"
echo -e "${GREEN}========================================${NC}"
