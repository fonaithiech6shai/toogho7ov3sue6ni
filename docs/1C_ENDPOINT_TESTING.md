# Тестирование 1C Integration Endpoint

Этот документ описывает скрипты для тестирования эндпоинта `/api/1c_notify_update` системы интеграции с 1С.

## Доступные скрипты

### 1. `test_1c_endpoint.sh` - Полное тестирование

Комплексный скрипт для всестороннего тестирования эндпоинта с подробным логированием.

**Возможности:**
- Проверка зависимостей (curl, jq)
- Тестирование с/без аутентификации
- Проверка обработки конфликтов потоков
- Тестирование производительности
- Мониторинг логов приложения
- Подробная статистика выполнения

**Использование:**
```bash
# Базовое тестирование
./test_1c_endpoint.sh

# С тестами производительности
./test_1c_endpoint.sh --performance

# С мониторингом логов
./test_1c_endpoint.sh --monitor

# Полное тестирование
./test_1c_endpoint.sh --performance --monitor

# Справка
./test_1c_endpoint.sh --help

# Показать текущую конфигурацию
./test_1c_endpoint.sh --config
```

**Переменные окружения:**
```bash
export TEST_BASE_URL="https://your-server.com"  # Базовый URL
export TEST_USERNAME="your-username"           # Имя пользователя
export TEST_PASSWORD="your-password"           # Пароль
export TEST_TIMEOUT=60                          # Таймаут в секундах
```

### 2. `quick_1c_test.sh` - Быстрое тестирование

Простой скрипт для быстрой проверки работоспособности эндпоинта.

**Возможности:**
- Быстрая проверка базовой функциональности
- Проверка аутентификации
- Тест блокировки потоков
- Просмотр последних записей логов

**Использование:**
```bash
./quick_1c_test.sh
```

### 3. `local_1c_test.sh` - Локальное тестирование

Скрипт для тестирования локальной версии приложения во время разработки.

**Возможности:**
- Тестирование localhost сервера
- Проверка доступности сервера
- Просмотр локальных логов
- Настройка портов

**Использование:**
```bash
# Тестирование на порту 3000 (по умолчанию)
./local_1c_test.sh

# Тестирование на другом порту
LOCAL_PORT=4567 ./local_1c_test.sh

# Тестирование другого хоста
LOCAL_HOST="192.168.1.100:3000" ./local_1c_test.sh
```

## Установка и настройка

### Требования

**Обязательные:**
- `curl` - для HTTP запросов
- `bash` версии 4.0+

**Рекомендуемые:**
- `jq` - для форматирования JSON ответов
- Доступ к логам приложения

### Установка зависимостей

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install curl jq
```

**CentOS/RHEL:**
```bash
sudo yum install curl jq
# или для новых версий
sudo dnf install curl jq
```

**macOS:**
```bash
brew install curl jq
```

### Настройка доступа

1. **Сделать скрипты исполняемыми:**
```bash
chmod +x test_1c_endpoint.sh quick_1c_test.sh local_1c_test.sh
```

2. **Настроить credentials (если отличаются от стандартных):**
```bash
# Создать файл конфигурации
cat > ~/.1c_test_config << 'EOF'
TEST_BASE_URL="https://your-server.com"
TEST_USERNAME="your-username"
TEST_PASSWORD="your-password"
TEST_TIMEOUT=30
EOF

# Загрузить конфигурацию перед запуском
source ~/.1c_test_config
./test_1c_endpoint.sh
```

## Интерпретация результатов

### HTTP статусы

| Статус | Значение | Интерпретация |
|--------|----------|---------------|
| 200 | OK | ✅ Запрос выполнен успешно, процесс запущен |
| 409 | Conflict | ⚠️ Процесс уже запущен (нормальное поведение) |
| 401 | Unauthorized | ❌ Неверные credentials |
| 403 | Forbidden | ❌ Доступ запрещен |
| 404 | Not Found | ❌ Эндпоинт не найден |
| 500 | Internal Error | ❌ Ошибка сервера |

### Примеры ответов

**Успешный запуск:**
```json
{
  "message": "Operation completed successfully",
  "status": "success"
}
```

**Конфликт потоков:**
```json
{
  "message": "The process is already underway",
  "status": "error"
}
```

**Ошибка сервера:**
```json
{
  "message": "An error occurred: [error details]",
  "status": "error"
}
```

### Анализ времени ответа

- **< 1 секунда** - Отличная производительность
- **1-3 секунды** - Хорошая производительность
- **3-10 секунд** - Приемлемая производительность
- **> 10 секунд** - Возможны проблемы

## Автоматизация

### Cron Job для мониторинга

```bash
# Ежечасная проверка доступности
0 * * * * /path/to/quick_1c_test.sh >> /var/log/1c_monitoring.log 2>&1

# Ежедневная проверка производительности
0 6 * * * /path/to/test_1c_endpoint.sh --performance >> /var/log/1c_daily.log 2>&1
```

### Интеграция с мониторингом

**Nagios/Icinga проверка:**
```bash
#!/bin/bash
# check_1c_endpoint.sh
result=$(./quick_1c_test.sh 2>&1)
if echo "$result" | grep -q "SUCCESS"; then
    echo "OK - 1C endpoint is working"
    exit 0
else
    echo "CRITICAL - 1C endpoint failed"
    exit 2
fi
```

**Prometheus метрики:**
```bash
#!/bin/bash
# 1c_metrics.sh
start_time=$(date +%s%3N)
status=$(curl -s -u "user:pass" -w "%{http_code}" -o /dev/null "https://server/api/1c_notify_update")
end_time=$(date +%s%3N)
response_time=$((end_time - start_time))

echo "1c_endpoint_response_time_ms $response_time"
echo "1c_endpoint_status_code $status"
echo "1c_endpoint_up $([ "$status" = "200" ] && echo 1 || echo 0)"
```

## Troubleshooting

### Общие проблемы

**1. `curl: command not found`**
```bash
# Установить curl
sudo apt-get install curl  # Ubuntu/Debian
sudo yum install curl      # CentOS/RHEL
```

**2. `Connection refused`**
- Проверить доступность сервера
- Проверить firewall/iptables
- Проверить правильность URL

**3. `SSL certificate problem`**
```bash
# Временно отключить проверку SSL (только для тестирования!)
curl -k https://...

# Или добавить в скрипт:
curl --insecure https://...
```

**4. `timeout`**
- Увеличить таймаут: `TEST_TIMEOUT=60 ./test_1c_endpoint.sh`
- Проверить нагрузку на сервер
- Проверить сетевое соединение

### Диагностика

**1. Проверка сетевой доступности:**
```bash
ping your-server.com
telnet your-server.com 443
curl -I https://your-server.com
```

**2. Проверка SSL сертификата:**
```bash
openssl s_client -connect your-server.com:443 -servername your-server.com
```

**3. Детальная диагностика curl:**
```bash
curl -v -u "user:pass" https://your-server.com/api/1c_notify_update
```

**4. Проверка DNS:**
```bash
nslookup your-server.com
dig your-server.com
```

## Логи и отчеты

### Расположение логов

**Полный тест:**
- `/tmp/1c_endpoint_test_YYYYMMDD_HHMMSS.log`

**Приложение:**
- `/srv/log/rozarioflowers.ru.production.log`
- `log/1c_notify_update.log`
- `log/development.log` (для локального тестирования)

### Анализ логов

**Поиск ошибок:**
```bash
grep -E "ERROR|CRITICAL|FAILED" /tmp/1c_endpoint_test_*.log
```

**Статистика производительности:**
```bash
grep "TIME_TOTAL:" /tmp/1c_endpoint_test_*.log | awk -F: '{sum+=$2; count++} END {print "Average:", sum/count "s"}'
```

**Анализ HTTP статусов:**
```bash
grep "HTTP_STATUS:" /tmp/1c_endpoint_test_*.log | sort | uniq -c
```

## Расширение скриптов

### Добавление новых тестов

```bash
# Добавить в test_1c_endpoint.sh
test_custom_scenario() {
    log_info "=== Custom Test ==="
    make_request "GET" "$BASE_URL/api/custom" "true" "Custom test description"
}

# Вызвать в main()
test_custom_scenario
```

### Интеграция с другими системами

```bash
# Отправка уведомлений в Slack
send_slack_notification() {
    local message="$1"
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" \
        "$SLACK_WEBHOOK_URL"
}

# Сохранение в базу данных
save_test_result() {
    local status="$1"
    local response_time="$2"
    mysql -u user -p database -e "INSERT INTO test_results (timestamp, status, response_time) VALUES (NOW(), '$status', '$response_time')"
}
```

## Best Practices

1. **Регулярное тестирование:** Запускайте тесты регулярно для раннего обнаружения проблем

2. **Мониторинг производительности:** Отслеживайте время ответа для выявления деградации производительности

3. **Логирование:** Сохраняйте все результаты тестирования для анализа трендов

4. **Уведомления:** Настройте автоматические уведомления при сбоях

5. **Безопасность:** Не храните credentials в открытом виде в скриптах

6. **Документирование:** Ведите документацию об изменениях и результатах тестирования

---

*Эти скрипты предназначены для тестирования и мониторинга. В production окружении рекомендуется использовать профессиональные решения для мониторинга.*
