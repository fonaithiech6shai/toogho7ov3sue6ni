#!/bin/bash
# Тест для проверки работы hygiene.sh с .gitignore

echo "=== Тест функций .gitignore в hygiene.sh ==="

# Создаем тестовые файлы
echo "# Test Ruby file" > test_file.rb
echo "# Test backup" > test_file.bak  
echo "# Test HAML" > test_file.haml

# Проверяем функцию is_ignored (без запуска основной логики)
# Извлекаем только функции
sed -n '/^is_ignored()/,/^}$/p' hygiene.sh > temp_functions.sh
echo >> temp_functions.sh
sed -n '/^create_find_with_gitignore()/,/^}$/p' hygiene.sh >> temp_functions.sh
source temp_functions.sh

echo "
1. Проверка функции is_ignored:"

# Проверяем файлы, которые должны быть в .gitignore
files_to_test=("test_file.rb" "test_file.bak" "test_file.haml" "+/test.rb")

for file in "${files_to_test[@]}"; do
  if is_ignored "$file"; then
    echo "  ✅ $file - игнорируется"
  else
    echo "  ❌ $file - НЕ игнорируется"
  fi
done

echo "
2. Проверка git check-ignore:"
if command -v git >/dev/null 2>&1 && [[ -d ".git" ]]; then
  echo "  Git доступен - используем git check-ignore"
  for file in "${files_to_test[@]}"; do
    if git check-ignore "$file" >/dev/null 2>&1; then
      echo "    ✅ git check-ignore: $file - игнорируется"
    else
      echo "    ❌ git check-ignore: $file - НЕ игнорируется"
    fi
  done
else
  echo "  Git недоступен - используем fallback"
fi

echo "
3. Проверка .gitignore файла:"
if [[ -f ".gitignore" ]]; then
  echo "  .gitignore найден, основные паттерны:"
  grep -E "(\+/|\*\.bak|test_)" .gitignore | head -5 | sed 's/^/    /'
else
  echo "  .gitignore не найден!"
fi

# Удаляем тестовые файлы
rm -f test_file.rb test_file.bak test_file.haml temp_functions.sh

echo "
=== Тест завершен ==="
