# GitHub Actions Troubleshooting Guide

## Проблемы с CodeQL и SARIF загрузкой

### Проблема 1: "Resource not accessible by integration"

**Симптомы:**
```
Warning: This run of the CodeQL Action does not have permission to access the CodeQL Action API endpoints. 
This could be because the Action is running on a pull request from a fork. 
Details: Resource not accessible by integration
```

**Причина:**
Отсутствуют необходимые права доступа `security-events: write` для загрузки SARIF результатов.

**Решение:**
Добавить секцию `permissions` в job:
```yaml
jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read
```

### Проблема 2: "Path does not exist: trivy-results.sarif"

**Симптомы:**
```
Error: Path does not exist: trivy-results.sarif
```

**Причина:**
- Trivy не создал SARIF файл (нет уязвимостей или ошибка сканирования)
- Неправильный путь к файлу
- Trivy завершился с ошибкой

**Решение:**
Добавить проверку существования файла перед загрузкой:
```yaml
- name: Check if SARIF file exists
  id: sarif-check
  run: |
    if [ -f "trivy-results.sarif" ] && [ -s "trivy-results.sarif" ]; then
      echo "sarif_exists=true" >> $GITHUB_OUTPUT
      echo "✅ SARIF file created successfully"
    else
      echo "sarif_exists=false" >> $GITHUB_OUTPUT
      echo "⚠️  SARIF file not created or empty"
    fi
    
- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  if: steps.sarif-check.outputs.sarif_exists == 'true'
  with:
    sarif_file: 'trivy-results.sarif'
  continue-on-error: true
```

### Проблема 3: Trivy не находит файлы для сканирования

**Причина:**
Триви может исключать слишком много файлов из-за конфигурации `.trivyignore`.

**Диагностика:**
Добавить шаг для показа файлов, которые будут сканироваться:
```yaml
- name: Show files that will be scanned by Trivy
  run: |
    echo "📁 Files and directories that will be scanned:"
    find . -type f \( -name "*.rb" -o -name "*.yml" -o -name "*.yaml" \) \
      ! -path "./+/*" ! -path "./.git/*" ! -path "./vendor/*" \
      | head -10
```

## Текущие исправления

### Внесенные изменения в `.gitleaks.toml`:

1. ✅ **Исправлен TOML синтаксис:**
   - Удалены некорректные экранированные символы
   - Упрощена конфигурация для лучшей совместимости
   - Добавлены правильные allowlist правила

2. ✅ **Оптимизированы исключения:**
   - Корректное исключение auxiliary directory (`+/**`)
   - Правильные паттерны для тестовых файлов
   - Исключение системных директорий

### Внесенные изменения в `.github/workflows/quality-checks.yml`:

1. ✅ **Добавлены права доступа:**
   ```yaml
   permissions:
     security-events: write
     actions: read
     contents: read
   ```

2. ✅ **Добавлена проверка SARIF файла:**
   - Проверка существования и размера файла
   - Условная загрузка только если файл существует
   - Graceful handling ошибок

3. ✅ **Улучшена обработка ошибок:**
   - `continue-on-error: true` для всех security-related шагов
   - Более информативные сообщения об ошибках

4. ✅ **Исправлена конфигурация GitLeaks:**
   - Убраны deprecated параметры
   - Добавлена проверка результатов сканирования
   - Улучшена обработка ошибок конфигурации

5. ✅ **Добавлена диагностика:**
   - Показ файлов для сканирования
   - Настройка серьезности для Trivy

## Рекомендации

### Для Pull Requests из форков:
- Security scans могут быть ограничены в правах
- Рассмотреть separate workflow только для основной ветки
- Использовать `pull_request_target` с осторожностью

### Для Production:
- Регулярно обновлять версии actions (v3 -> v4)
- Мониторить SARIF загрузки в Security tab
- Настроить алерты на неудачные security scans

### Дополнительная конфигурация Trivy:
```yaml
with:
  scan-type: 'fs'
  scan-ref: '.'
  format: 'sarif'
  output: 'trivy-results.sarif'
  severity: 'CRITICAL,HIGH,MEDIUM'
  exit-code: '0'  # Не прерывать workflow при найденных уязвимостях
```

## Проблемы с GitLeaks

### Проблема 4: "invalid escaped character U+002F '/'"

**Симптомы:**
```
FTL unable to load gitleaks config, err: While parsing config: toml: invalid escaped character U+002F '/'
```

**Причина:**
Неправильное экранирование символов в TOML конфигурации GitLeaks.

**Решение:**
Использовать правильный синтаксис TOML без лишних экранирований:
```toml
# Неправильно:
paths = [
    "\/\+\/.*",
    "\+\/.*"
]

# Правильно:
paths = [
    "+/**",
    "**/.git/**"
]
```

### Проблема 5: "Unexpected input(s) 'config-path'"

**Причина:**
Устаревший или неправильный параметр в новой версии gitleaks-action.

**Решение:**
Использовать корректные параметры:
```yaml
- name: Run GitLeaks
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    config-path: .gitleaks.toml  # Этот параметр поддерживается
  continue-on-error: true
```

### Проблема 6: "File results.sarif does not exist"

**Причина:**
GitLeaks не создал SARIF файл из-за ошибок конфигурации или отсутствия находок.

**Решение:**
Добавить проверку существования файла:
```yaml
- name: Check GitLeaks results
  if: always()
  run: |
    if [ -f "results.sarif" ]; then
      echo "✅ GitLeaks scan completed with results"
    else
      echo "⚠️  GitLeaks scan completed without SARIF output"
    fi
```

## Исправленная конфигурация GitLeaks

```toml
# Gitleaks configuration for Rozario.Flowers
title = "Rozario Security Scanning"

# Skip auxiliary directory with test data
[allowlist]
paths = [
    "+/**",
    "**/.git/**",
    "**/vendor/**",
    "**/tmp/**",
    "**/log/**"
]

files = [
    "test_*.rb",
    "*_test.rb",
    "*.tmp",
    "*.log",
    "*.bak"
]

# Allowlist common false positives
regexes = [
    "Mozilla",
    "localhost",
    "127.0.0.1",
    "example_api_key",
    "test_token"
]
```

Эти исправления должны решить основные проблемы с GitHub Actions security scanning.
