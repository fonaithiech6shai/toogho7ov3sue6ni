#!/bin/bash
# Скрипт для запуска всех тестов 1C Exchange API
# Usage: ./run_1c_exchange_tests.sh [unit|mock|integration|all]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
TEST_DIR="$(dirname "$0")"
UNIT_TEST="$TEST_DIR/unit/test_1c_exchange_logic.rb"
MOCK_TEST="$TEST_DIR/utils/test_1c_exchange_mock.rb"
INTEGRATION_TEST="$TEST_DIR/integration/test_1c_exchange_api.rb"

# Функции для вывода
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    local missing_gems=()
    
    if ! gem list minitest | grep -q minitest; then
        missing_gems+=("minitest")
    fi
    
    if ! gem list nokogiri | grep -q nokogiri; then
        missing_gems+=("nokogiri")
    fi
    
    if [[ "$1" == "mock" || "$1" == "all" ]]; then
        if ! gem list webmock | grep -q webmock; then
            missing_gems+=("webmock")
        fi
    fi
    
    if [[ ${#missing_gems[@]} -gt 0 ]]; then
        log_warning "Установка недостающих gems: ${missing_gems[*]}"
        gem install "${missing_gems[@]}"
    fi
}

# Запуск unit тестов
run_unit_tests() {
    log_info "Запуск Unit тестов (без БД)..."
    if ruby "$UNIT_TEST"; then
        log_success "Unit тесты прошли успешно"
        return 0
    else
        log_error "Unit тесты завершились с ошибками"
        return 1
    fi
}

# Запуск mock тестов
run_mock_tests() {
    log_info "Запуск Mock тестов (HTTP симуляция)..."
    if ruby "$MOCK_TEST"; then
        log_success "Mock тесты прошли успешно"
        return 0
    else
        log_error "Mock тесты завершились с ошибками"
        return 1
    fi
}

# Запуск integration тестов
run_integration_tests() {
    log_info "Запуск Integration тестов (с БД и HTTP)..."
    
    # Проверяем переменные окружения
    if [[ -z "$TEST_BASE_URL" ]]; then
        export TEST_BASE_URL="http://localhost:4567"
        log_warning "TEST_BASE_URL не установлен, используется: $TEST_BASE_URL"
    fi
    
    log_info "Тестирование против: $TEST_BASE_URL"
    
    if ruby "$INTEGRATION_TEST"; then
        log_success "Integration тесты прошли успешно"
        return 0
    else
        log_error "Integration тесты завершились с ошибками"
        return 1
    fi
}

# Показать справку
show_help() {
    echo "Скрипт для запуска тестов 1C Exchange API"
    echo ""
    echo "Использование: $0 [OPTION]"
    echo ""
    echo "Опции:"
    echo "  unit         Запуск только Unit тестов (быстро, без БД)"
    echo "  mock         Запуск только Mock тестов (быстро, HTTP симуляция)"
    echo "  integration  Запуск только Integration тестов (медленно, требует БД)"
    echo "  all          Запуск всех тестов (по умолчанию)"
    echo "  help         Показать эту справку"
    echo ""
    echo "Переменные окружения:"
    echo "  TEST_BASE_URL    URL для тестирования (по умолчанию: http://localhost:4567)"
    echo "  TESTER_NAME      Имя тестировщика для фильтрации заказов"
    echo ""
    echo "Примеры:"
    echo "  $0 unit                              # Только быстрые тесты"
    echo "  $0 mock                              # Mock HTTP тесты"
    echo "  TEST_BASE_URL=https://example.com $0 integration   # Production тесты"
    echo "  $0 all                               # Все тесты"
}

# Основная логика
run_tests() {
    local test_type="${1:-all}"
    local failed_tests=()
    local total_tests=0
    local passed_tests=0
    
    echo "==========================================="
    log_info "Начало тестирования 1C Exchange API"
    echo "==========================================="
    
    case "$test_type" in
        "unit")
            check_dependencies
            total_tests=1
            if run_unit_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Unit")
            fi
            ;;
        "mock")
            check_dependencies "mock"
            total_tests=1
            if run_mock_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Mock")
            fi
            ;;
        "integration")
            total_tests=1
            if run_integration_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Integration")
            fi
            ;;
        "all")
            check_dependencies "all"
            total_tests=3
            
            # Unit тесты (всегда запускаем)
            if run_unit_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Unit")
            fi
            
            echo ""
            
            # Mock тесты
            if run_mock_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Mock")
            fi
            
            echo ""
            
            # Integration тесты
            if run_integration_tests; then
                ((passed_tests++))
            else
                failed_tests+=("Integration")
            fi
            ;;
        "help")
            show_help
            return 0
            ;;
        *)
            log_error "Неизвестная опция: $test_type"
            show_help
            return 1
            ;;
    esac
    
    echo ""
    echo "==========================================="
    log_info "Результаты тестирования"
    echo "==========================================="
    
    if [[ $passed_tests -eq $total_tests ]]; then
        log_success "Все тесты прошли успешно! ($passed_tests/$total_tests)"
        return 0
    else
        log_error "Некоторые тесты завершились с ошибками ($passed_tests/$total_tests)"
        if [[ ${#failed_tests[@]} -gt 0 ]]; then
            log_error "Упавшие тесты: ${failed_tests[*]}"
        fi
        return 1
    fi
}

# Проверяем аргументы и запускаем
if [[ $# -eq 0 ]]; then
    run_tests "all"
else
    run_tests "$1"
fi
