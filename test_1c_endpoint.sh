#!/bin/bash
# Тестовый скрипт для эндпоинта 1C интеграции
# Тестирование /api/1c_notify_update

set -e  # Остановить скрипт при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
BASE_URL="https://rozarioflowers.ru"
API_ENDPOINT="/api/1c_notify_update"
USERNAME="bae15749-52e9-4420-b429-f9fb483f4e48"
PASSWORD="94036dbc-5bbc-4495-952c-9f2150047b9a"
TIMEOUT=30
USER_AGENT="1C-Integration-Test/1.0"
LOG_FILE="/tmp/1c_endpoint_test_$(date +%Y%m%d_%H%M%S).log"

# Функции для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

# Функция для проверки зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq не найден. JSON ответы будут показаны без форматирования."
        JQ_AVAILABLE=false
    else
        JQ_AVAILABLE=true
    fi
    
    log_success "Зависимости проверены"
}

# Функция для форматирования JSON
format_json() {
    if [ "$JQ_AVAILABLE" = true ]; then
        echo "$1" | jq .
    else
        echo "$1"
    fi
}

# Функция для выполнения HTTP запроса
make_request() {
    local method="$1"
    local url="$2"
    local auth_required="$3"
    local description="$4"
    
    log_info "$description"
    log "Выполнение $method запроса к $url"
    
    # Подготовка curl команды
    local curl_cmd="curl -s -w '\n\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nTIME_CONNECT:%{time_connect}\nSIZE_DOWNLOAD:%{size_download}\n'"
    curl_cmd="$curl_cmd --max-time $TIMEOUT"
    curl_cmd="$curl_cmd --user-agent '$USER_AGENT'"
    curl_cmd="$curl_cmd -H 'Accept: application/json'"
    
    if [ "$auth_required" = "true" ]; then
        curl_cmd="$curl_cmd -u '$USERNAME:$PASSWORD'"
    fi
    
    curl_cmd="$curl_cmd -X $method '$url'"
    
    # Выполнение запроса
    log "Команда: $curl_cmd"
    local response=$(eval $curl_cmd 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "Ошибка выполнения curl (код: $exit_code)"
        log "Ответ: $response"
        return $exit_code
    fi
    
    # Парсинг ответа
    local body=$(echo "$response" | sed '/^HTTP_STATUS:/,$d')
    local http_status=$(echo "$response" | grep '^HTTP_STATUS:' | cut -d: -f2)
    local time_total=$(echo "$response" | grep '^TIME_TOTAL:' | cut -d: -f2)
    local time_connect=$(echo "$response" | grep '^TIME_CONNECT:' | cut -d: -f2)
    local size_download=$(echo "$response" | grep '^SIZE_DOWNLOAD:' | cut -d: -f2)
    
    # Логирование результатов
    log "HTTP Status: $http_status"
    log "Time Total: ${time_total}s"
    log "Time Connect: ${time_connect}s"
    log "Size Downloaded: ${size_download} bytes"
    
    echo "" >> "$LOG_FILE"
    echo "Response Body:" >> "$LOG_FILE"
    echo "$body" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Анализ HTTP статуса
    case "$http_status" in
        200)
            log_success "Запрос выполнен успешно (HTTP 200)"
            ;;
        409)
            log_warning "Конфликт - процесс уже запущен (HTTP 409)"
            ;;
        401)
            log_error "Ошибка аутентификации (HTTP 401)"
            ;;
        403)
            log_error "Доступ запрещен (HTTP 403)"
            ;;
        404)
            log_error "Эндпоинт не найден (HTTP 404)"
            ;;
        500)
            log_error "Внутренняя ошибка сервера (HTTP 500)"
            ;;
        *)
            log_error "Неожиданный HTTP статус: $http_status"
            ;;
    esac
    
    # Показ ответа
    if [ -n "$body" ]; then
        echo -e "${BLUE}Response Body:${NC}"
        format_json "$body"
    fi
    
    echo ""
    return 0
}

# Функция тестирования без аутентификации
test_without_auth() {
    log_info "=== Тест 1: Запрос без аутентификации ==="
    make_request "GET" "$BASE_URL$API_ENDPOINT" "false" "Проверка требования аутентификации"
}

# Функция тестирования с правильной аутентификацией
test_with_valid_auth() {
    log_info "=== Тест 2: Запрос с правильной аутентификацией ==="
    make_request "GET" "$BASE_URL$API_ENDPOINT" "true" "Запуск 1C интеграции"
}

# Функция тестирования повторного запроса (проверка на конфликт)
test_concurrent_request() {
    log_info "=== Тест 3: Повторный запрос (проверка блокировки потоков) ==="
    log_warning "Запуск через 2 секунды для проверки состояния thread_running..."
    sleep 2
    make_request "GET" "$BASE_URL$API_ENDPOINT" "true" "Проверка обработки конфликта потоков"
}

# Функция тестирования с неправильными credentials
test_with_invalid_auth() {
    log_info "=== Тест 4: Запрос с неправильными credentials ==="
    local old_username="$USERNAME"
    local old_password="$PASSWORD"
    
    USERNAME="invalid-username"
    PASSWORD="invalid-password"
    
    make_request "GET" "$BASE_URL$API_ENDPOINT" "true" "Проверка обработки неправильной аутентификации"
    
    # Восстановление правильных credentials
    USERNAME="$old_username"
    PASSWORD="$old_password"
}

# Функция тестирования POST метода (если поддерживается)
test_post_method() {
    log_info "=== Тест 5: POST метод ==="
    make_request "POST" "$BASE_URL$API_ENDPOINT" "true" "Проверка поддержки POST метода"
}

# Функция для проверки статуса приложения
test_app_health() {
    log_info "=== Тест 6: Проверка доступности приложения ==="
    make_request "GET" "$BASE_URL" "false" "Проверка главной страницы"
}

# Функция мониторинга лога (если доступен)
monitor_log() {
    log_info "=== Мониторинг лога 1C интеграции ==="
    local log_path="/srv/log/rozarioflowers.ru.production.log"
    
    if [ -f "$log_path" ]; then
        log_info "Отслеживание активности в логе..."
        echo -e "${BLUE}Последние записи из лога 1C интеграции:${NC}"
        tail -20 "$log_path" | grep -E "\[TRANSACTION|1c_notify_update|Начало процесса|Конец" || log_warning "Записи 1C интеграции не найдены в логе"
    else
        log_warning "Лог файл $log_path не найден или недоступен"
    fi
}

# Функция для анализа производительности
performance_test() {
    log_info "=== Тест производительности ==="
    
    local start_time=$(date +%s)
    
    for i in {1..3}; do
        log "Тест производительности - попытка $i/3"
        make_request "GET" "$BASE_URL$API_ENDPOINT" "true" "Тест производительности #$i"
        sleep 5  # Пауза между запросами
    done
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    log_info "Общее время тестирования: ${total_time} секунд"
}

# Главная функция
main() {
    echo -e "${BLUE}" 
    echo "╔═══════════════════════════════════════╗"
    echo "║     1C Integration Endpoint Tester    ║"
    echo "║        Rozario Flowers System         ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Начало тестирования эндпоинта 1C интеграции"
    log "Базовый URL: $BASE_URL"
    log "Эндпоинт: $API_ENDPOINT"
    log "Лог файл: $LOG_FILE"
    log "Timeout: $TIMEOUT секунд"
    
    check_dependencies
    
    # Выполнение тестов
    test_app_health
    test_without_auth
    test_with_invalid_auth
    test_with_valid_auth
    test_concurrent_request
    test_post_method
    
    # Опциональные тесты
    if [ "$1" = "--performance" ]; then
        performance_test
    fi
    
    if [ "$1" = "--monitor" ] || [ "$2" = "--monitor" ]; then
        monitor_log
    fi
    
    # Финальный отчет
    echo ""
    log_info "=== ОТЧЕТ О ТЕСТИРОВАНИИ ==="
    log "Лог файл с подробными результатами: $LOG_FILE"
    
    local error_count=$(grep -c "❌" "$LOG_FILE" || echo "0")
    local success_count=$(grep -c "✓" "$LOG_FILE" || echo "0")
    local warning_count=$(grep -c "⚠️" "$LOG_FILE" || echo "0")
    
    log "Успешных тестов: $success_count"
    log "Предупреждений: $warning_count"
    log "Ошибок: $error_count"
    
    if [ "$error_count" -eq 0 ]; then
        log_success "Все критические тесты прошли успешно!"
        exit 0
    else
        log_error "Обнаружены ошибки в $error_count тестах"
        exit 1
    fi
}

# Функция помощи
show_help() {
    echo "Использование: $0 [OPTIONS]"
    echo ""
    echo "Опции:"
    echo "  --help              Показать эту справку"
    echo "  --performance       Запустить тесты производительности"
    echo "  --monitor          Показать записи из лога приложения"
    echo "  --config           Показать текущую конфигурацию"
    echo ""
    echo "Примеры:"
    echo "  $0                          # Базовое тестирование"
    echo "  $0 --performance           # Тесты с проверкой производительности"
    echo "  $0 --monitor              # Включить мониторинг логов"
    echo "  $0 --performance --monitor # Полное тестирование"
    echo ""
    echo "Переменные окружения:"
    echo "  TEST_BASE_URL     Базовый URL для тестирования (по умолчанию: $BASE_URL)"
    echo "  TEST_USERNAME     Имя пользователя для аутентификации"
    echo "  TEST_PASSWORD     Пароль для аутентификации"
    echo "  TEST_TIMEOUT      Таймаут запросов в секундах (по умолчанию: $TIMEOUT)"
}

# Функция показа конфигурации
show_config() {
    echo "Текущая конфигурация:"
    echo "  BASE_URL: $BASE_URL"
    echo "  API_ENDPOINT: $API_ENDPOINT"
    echo "  USERNAME: ${USERNAME:0:8}..."
    echo "  PASSWORD: ${PASSWORD:0:8}..."
    echo "  TIMEOUT: $TIMEOUT"
    echo "  USER_AGENT: $USER_AGENT"
    echo "  LOG_FILE: $LOG_FILE"
}

# Обработка параметров командной строки
case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --config)
        show_config
        exit 0
        ;;
esac

# Переопределение настроек из переменных окружения
if [ -n "$TEST_BASE_URL" ]; then
    BASE_URL="$TEST_BASE_URL"
fi

if [ -n "$TEST_USERNAME" ]; then
    USERNAME="$TEST_USERNAME"
fi

if [ -n "$TEST_PASSWORD" ]; then
    PASSWORD="$TEST_PASSWORD"
fi

if [ -n "$TEST_TIMEOUT" ]; then
    TIMEOUT="$TEST_TIMEOUT"
fi

# Запуск главной функции
main "$@"
