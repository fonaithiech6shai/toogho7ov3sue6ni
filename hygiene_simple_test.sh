#!/bin/bash
# Простой тест основной функциональности hygiene.sh

echo "=== Проверка синтаксиса hygiene.sh ==="
if bash -n hygiene.sh; then
  echo "✅ Синтаксис корректный"
else
  echo "❌ Ошибки синтаксиса!"
  exit 1
fi

echo "
=== Проверка git check-ignore ==="
if command -v git >/dev/null 2>&1 && [[ -d ".git" ]]; then
  echo "✅ Git доступен"
  
  # Тестируем git check-ignore
  echo "# test file" > test_ignored.tmp
  
  if git check-ignore "test_ignored.tmp" >/dev/null 2>&1; then
    echo "✅ test_ignored.tmp игнорируется git"
  else
    echo "❌ test_ignored.tmp НЕ игнорируется git"
  fi
  
  if git check-ignore "+/test.rb" >/dev/null 2>&1; then
    echo "✅ +/test.rb игнорируется git"
  else
    echo "❌ +/test.rb НЕ игнорируется git"
  fi
  
  rm -f test_ignored.tmp
else
  echo "❌ Git недоступен"
fi

echo "
=== Проверка find команд с исключениями ==="
test_find_count=$(find . -type f \( -path "*/public/*" -o -path "*/tmp/*" -o -path "*/vendor/*" -o -path "*/+/*" -o -path "*/.git/*" \) -prune -o -type f -name "*.rb" -print | wc -l)
echo "ℹ️  Найдено $test_find_count .rb файлов (с исключениями)"

if [[ $test_find_count -gt 0 ]]; then
  echo "✅ Find команды работают"
else
  echo "⚠️  Ни одного .rb файла не найдено"
fi

echo "
=== Проверка .gitignore файла ==="
if [[ -f ".gitignore" ]]; then
  echo "✅ .gitignore найден"
  echo "ℹ️  Ключевые паттерны:"
  grep -E "(\+/|\*\.bak|test_|vendor|public|tmp)" .gitignore | head -5 | sed 's/^/    /'
else
  echo "❌ .gitignore не найден!"
fi

echo "
=== Тест завершен ==="
