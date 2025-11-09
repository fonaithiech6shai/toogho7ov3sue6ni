#!/bin/bash
# Быстрый тест 1C эндпоинта
# Простая версия для моментального тестирования

set -e

# Конфигурация
BASE_URL="https://rozarioflowers.ru"
API_ENDPOINT="/api/1c_notify_update"
USERNAME="bae15749-52e9-4420-b429-f9fb483f4e48"
PASSWORD="94036dbc-5bbc-4495-952c-9f2150047b9a"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 1C Integration Quick Test ===${NC}"
echo "URL: $BASE_URL$API_ENDPOINT"
echo "Time: $(date)"
echo ""

# Функция для выполнения curl запроса
test_endpoint() {
    local use_auth="$1"
    local description="$2"
    
    echo -e "${BLUE}Testing: $description${NC}"
    
    local curl_cmd="curl -s -w '\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}s\n' --max-time 30"
    
    if [ "$use_auth" = "true" ]; then
        curl_cmd="$curl_cmd -u '$USERNAME:$PASSWORD'"
    fi
    
    curl_cmd="$curl_cmd -H 'Accept: application/json' '$BASE_URL$API_ENDPOINT'"
    
    echo "Command: $curl_cmd"
    local response=$(eval $curl_cmd 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}❌ cURL failed with exit code: $exit_code${NC}"
        echo "Error: $response"
        return $exit_code
    fi
    
    # Parse response
    local body=$(echo "$response" | sed '/^HTTP_STATUS:/,$d')
    local http_status=$(echo "$response" | grep '^HTTP_STATUS:' | cut -d: -f2)
    local time_total=$(echo "$response" | grep '^TIME_TOTAL:' | cut -d: -f2)
    
    echo "HTTP Status: $http_status"
    echo "Response Time: $time_total"
    
    # Analyze status
    case "$http_status" in
        200)
            echo -e "${GREEN}✓ SUCCESS${NC}"
            ;;
        409)
            echo -e "${YELLOW}⚠️  CONFLICT - Process already running${NC}"
            ;;
        401)
            echo -e "${RED}❌ UNAUTHORIZED${NC}"
            ;;
        403)
            echo -e "${RED}❌ FORBIDDEN${NC}"
            ;;
        404)
            echo -e "${RED}❌ NOT FOUND${NC}"
            ;;
        500)
            echo -e "${RED}❌ INTERNAL SERVER ERROR${NC}"
            ;;
        *)
            echo -e "${RED}❌ UNEXPECTED STATUS: $http_status${NC}"
            ;;
    esac
    
    if [ -n "$body" ]; then
        echo "Response Body:"
        if command -v jq &> /dev/null; then
            echo "$body" | jq . 2>/dev/null || echo "$body"
        else
            echo "$body"
        fi
    fi
    
    echo ""
    return 0
}

# Выполнение тестов
echo -e "${BLUE}=== Test 1: Without Authentication ===${NC}"
test_endpoint "false" "Check authentication requirement"

echo -e "${BLUE}=== Test 2: With Valid Authentication ===${NC}"
test_endpoint "true" "Start 1C integration process"

echo -e "${BLUE}=== Test 3: Concurrent Request (Thread Conflict Test) ===${NC}"
echo "Waiting 2 seconds before second request..."
sleep 2
test_endpoint "true" "Test thread blocking mechanism"

echo -e "${BLUE}=== Test Complete ===${NC}"
echo "Time: $(date)"

# Проверка логов если доступны
echo ""
echo -e "${BLUE}=== Recent Log Entries ===${NC}"
if [ -f "/srv/log/rozarioflowers.ru.production.log" ]; then
    echo "Last 10 1C-related log entries:"
    tail -50 "/srv/log/rozarioflowers.ru.production.log" | grep -E "1c_notify_update|Начало процесса|Конец|\[TRANSACTION" | tail -10 || echo "No recent 1C activity found"
elif [ -f "log/1c_notify_update.log" ]; then
    echo "1C integration log:"
    tail -10 "log/1c_notify_update.log"
else
    echo "No log files found or accessible"
fi
