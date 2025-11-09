#!/bin/bash
# Тест 1C эндпоинта на localhost
# Для разработки и локального тестирования

# Конфигурация для localhost
BASE_URL="http://localhost:3000"  # Или любой другой локальный порт
API_ENDPOINT="/api/1c_notify_update"
USERNAME="bae15749-52e9-4420-b429-f9fb483f4e48"
PASSWORD="94036dbc-5bbc-4495-952c-9f2150047b9a"

# Переопределение из переменных окружения
if [ -n "$LOCAL_PORT" ]; then
    BASE_URL="http://localhost:$LOCAL_PORT"
fi

if [ -n "$LOCAL_HOST" ]; then
    BASE_URL="http://$LOCAL_HOST"
fi

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Local 1C Integration Test ===${NC}"
echo "Testing URL: $BASE_URL$API_ENDPOINT"
echo "Time: $(date)"
echo ""

# Проверка доступности сервера
echo -e "${BLUE}=== Checking Server Availability ===${NC}"
if curl -s --max-time 5 "$BASE_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is accessible${NC}"
else
    echo -e "${RED}❌ Server is not accessible at $BASE_URL${NC}"
    echo "Make sure your local server is running on the correct port."
    echo "Examples:"
    echo "  - Padrino: padrino start -p 3000"
    echo "  - Rails: rails server -p 3000"
    echo "  - Or set LOCAL_PORT environment variable: LOCAL_PORT=4567 $0"
    exit 1
fi

echo ""

# Тесты
echo -e "${BLUE}=== Test 1: Basic Endpoint Test ===${NC}"
curl -v -X GET \
    -H "Accept: application/json" \
    -u "$USERNAME:$PASSWORD" \
    "$BASE_URL$API_ENDPOINT" 2>&1 | \
    grep -E "HTTP/|< |> |* Connected|* Connection"

echo ""
echo ""

echo -e "${BLUE}=== Test 2: JSON Response Test ===${NC}"
response=$(curl -s -X GET \
    -H "Accept: application/json" \
    -u "$USERNAME:$PASSWORD" \
    "$BASE_URL$API_ENDPOINT")

echo "Raw Response:"
echo "$response"
echo ""

if command -v jq &> /dev/null; then
    echo "Formatted JSON:"
    echo "$response" | jq . 2>/dev/null || echo "Response is not valid JSON"
else
    echo "Install 'jq' for JSON formatting"
fi

echo ""

echo -e "${BLUE}=== Test 3: Without Authentication ===${NC}"
http_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$API_ENDPOINT")
echo "HTTP Status without auth: $http_status"

if [ "$http_status" = "401" ]; then
    echo -e "${GREEN}✓ Authentication is required (correct behavior)${NC}"
elif [ "$http_status" = "200" ]; then
    echo -e "${YELLOW}⚠️  Authentication is not required (development mode?)${NC}"
else
    echo -e "${RED}❌ Unexpected status: $http_status${NC}"
fi

echo ""

echo -e "${BLUE}=== Test 4: Check Local Logs ===${NC}"
if [ -f "log/1c_notify_update.log" ]; then
    echo "Recent entries from local 1C log:"
    tail -20 "log/1c_notify_update.log" | head -10
elif [ -f "log/development.log" ]; then
    echo "Recent entries from development log:"
    tail -50 "log/development.log" | grep -E "1c_notify_update|Начало|Конец|api" | tail -10 || echo "No 1C activity in development log"
else
    echo "No local log files found"
    echo "Expected locations:"
    echo "  - log/1c_notify_update.log"
    echo "  - log/development.log"
fi

echo ""
echo -e "${BLUE}=== Local Test Complete ===${NC}"
echo "Time: $(date)"
echo ""
echo "Tips:"
echo "- Check log/development.log for detailed application logs"
echo "- Monitor log/1c_notify_update.log for 1C-specific logs"
echo "- Use 'tail -f log/development.log | grep 1c' to monitor in real-time"
