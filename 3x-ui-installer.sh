#!/bin/bash
# Автоматическая установка 3x-ui с случайным портом, SSL на 10 лет и настройкой UFW
# Работает под root на Debian/Ubuntu

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Запуск установки 3x-ui...${NC}"

# --- Шаг 1: Обновление системы ---
echo -e "${YELLOW}📦 Обновляем систему...${NC}"
apt update && apt upgrade -y
apt install -y wget curl tar nginx openssl ufw

# --- Шаг 2: Генерация случайного порта (10000-30000) ---
PORT=$(shuf -i 10000-30000 -n 1)
echo -e "${GREEN}✅ Выбран случайный порт: ${PORT}${NC}"

# --- Шаг 3: Настройка UFW ---
echo -e "${YELLOW}🔥 Настраиваем UFW...${NC}"

# Включаем UFW, если ещё не включён
if ! ufw status | grep -q "Status: active"; then
    echo "UFW не активен — включаем с базовыми правилами..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp  # SSH
    ufw --force enable
fi

# Удаляем старее правило 3x-ui, если порт был использован ранее
ufw status numbered | grep "$PORT/tcp" > /dev/null 2>&1 && {
    echo "Найдено старое правило для порта $PORT — удаляем..."
    CONN=$(ufw status numbered | grep "$PORT/tcp" | head -1 | grep -o '^\[[0-9]\+\]')
    CONN=${CONN//[^0-9]/}
    echo "yes" | ufw delete $CONN > /dev/null 2>&1 || true
}

# Добавляем новый порт
ufw allow $PORT/tcp
echo -e "${GREEN}✅ Порт $PORT открыт в UFW${NC}"

# --- Шаг 4: Установка 3x-ui ---
echo -e "${YELLOW}📥 Устанавливаем 3x-ui...${NC}"
wget -N --no-check-certificate -O /root/install.sh https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh
chmod +x /root/install.sh
bash /root/install.sh $PORT

# --- Шаг 5: Генерация SSL-сертификата (10 лет) ---
echo -e "${YELLOW}🔐 Генерируем SSL-сертификат на 10 лет...${NC}"
SSL_DIR="/root/3x-ui-ssl"
XUI_DIR="/etc/3x-ui"
mkdir -p $SSL_DIR $XUI_DIR

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout $SSL_DIR/x-ui.key \
  -out $SSL_DIR/x-ui.crt \
  -days 3650 \
  -subj "/C=RU/ST=Earth/L=Internet/O=OmaVPN/CN=$(hostname -I | awk '{print $1}')"

cp $SSL_DIR/x-ui.crt $XUI_DIR/
cp $SSL_DIR/x-ui.key $XUI_DIR/
echo -e "${GREEN}✅ SSL-сертификат скопирован в $XUI_DIR${NC}"

# --- Шаг 6: Перезапуск ---
echo -e "${YELLOW}🔄 Перезапускаем 3x-ui...${NC}"
systemctl restart 3x-ui

# --- Шаг 7: Проверка ---
if systemctl is-active --quiet 3x-ui; then
    echo -e "${GREEN}✅ Сервис 3x-ui запущен!${NC}"
else
    echo -e "${RED}❌ Ошибка запуска 3x-ui${NC}"
    exit 1
fi

# --- Финальное сообщение ---
IP=$(curl -s https://api.ipify.org)
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Установка завершена!${NC}"
echo -e "${GREEN}🌐 Панель доступна по: https://${IP}:${PORT}${NC}"
echo -e "${GREEN}🔒 SSL: самоподписанный (действует 10 лет)${NC}"
echo -e "${YELLOW}⚠️  При входе в браузере нажмите 'Дополнительно' → 'Продолжить'${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🔑 Логин по умолчанию: admin / admin${NC}"
echo -e "   Не забудьте сменить пароль после входа!"