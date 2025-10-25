#!/usr/bin/bash

# https://www.shellcheck.net/

# rm -rf /srv/development_rozarioflowers.ru/{*,.*} && cp -r /srv/development_rozarioflowers.ru/. /srv/development_rozarioflowers.ru/
# sudo nginx -t && sudo nginx -s reload && sudo systemctl status nginx

set -e

DIR=${1:-.} # Путь к папке, которую нужно проверить (по умолчанию текущая папка)

echo "Проверка файлов в папке: $DIR"

# Функция для проверки, игнорируется ли файл в .gitignore
is_ignored() {
  local file="$1"
  
  # Если нет .gitignore, файл не игнорируется
  if [[ ! -f ".gitignore" ]]; then
    return 1
  fi
  
  # Используем git check-ignore для точной проверки
  if command -v git >/dev/null 2>&1 && [[ -d ".git" ]] && [[ -n "$file" ]] && [[ -f "$file" ]]; then
    # Отключаем set -e для git check-ignore
    set +e
    git check-ignore "$file" >/dev/null 2>&1
    local result=$?
    set -e
    return $result
  else
    # Fallback: простая проверка без git - не игнорируем
    return 1
  fi
}

# Функция для создания find команды с исключением .gitignore файлов
create_find_with_gitignore() {
  local base_find="$1"
  
  # Если git доступен, используем его для фильтрации
  if command -v git >/dev/null 2>&1 && [[ -d ".git" ]]; then
    echo "$base_find | while IFS= read -r file; do if ! git check-ignore \"\$file\" >/dev/null 2>&1; then echo \"\$file\"; fi; done"
  else
    echo "$base_find"
  fi
}

# Поиск и вывод файлов в кодировках несовместимых с UTF-8
#
# find "$DIR" -type f -exec file -i {} \; | grep -Ev  'charset=(us-ascii|iso-8859-1|iso-8859-15|windows-1252|utf-8)' | while read -r line; do # Поиск файлов в кодировках несовместимых с UTF-8
#   echo "Несовместим с UTF-8: $line" # Вывод файлов с некорректной кодировкой
# done

# Поиск и конвертирование файлов в кодировках несовместимых с UTF-8
#
convert_to_utf8() { # Функция для конвертации файла в UTF-8. Файлы будут конвертированы в UTF-8 без BOM (Byte Order Mark), т.к. iconv по умолчанию не добавляет BOM.
  local file="$1"
  echo "Конвертация файла: $file"
  encoding=$(file -i "$file" | grep -oP 'charset=\K\S+') # Определение кодировки файла
  if [[ "$encoding" == "us-ascii"    || "$encoding" == "ascii"  || \
        "$encoding" == "iso-8859-1"  || "$encoding" == "latin1" || \
        "$encoding" == "iso-8859-15" || "$encoding" == "latin9" || \
        "$encoding" == "cp1252"      || "$encoding" == "windows-1252" ]]; then
    echo "Файл совместим с UTF-8: $file (кодировка $encoding)" # find . -type f -exec file -i {} \; | grep -E 'charset=(us-ascii|iso-8859-1|iso-8859-15|windows-1252|utf-8)'
  else
    cp "$file" "$file.bak" # Создание резервной копии файла перед конвертацией
    iconv -f "$encoding" -t utf-8 "$file" -o "$file.converted" && mv "$file.converted" "$file" # Конвертация в UTF-8
    echo "Файл успешно конвертирован: $file"
  fi
}
# Поиск файлов, не являющихся UTF-8, и их конвертация (с учетом .gitignore)
set +e  # Отключаем для цикла с проверками
find "$DIR" -type f \( -path "*/public/*" -o -path "*/tmp/*" -o -path "*/vendor/*" -o -path "*/+/*" -o -path "*/.git/*" \) -prune -o -type f -print | while read -r file; do
  # Пропускаем файлы из .gitignore
  if is_ignored "$file"; then continue; fi
  
  # Проверяем кодировку
  encoding=$(file -i "$file" 2>/dev/null | grep -v 'charset=utf-8' || true)
  if [[ -n "$encoding" ]]; then
    convert_to_utf8 "$file" # Преобразование файла в UTF-8
  fi
done
set -e  # Включаем обратно
# Чистка бэкапов (с учетом .gitignore)
set +e  # Отключаем для проверок .gitignore
find "$DIR" \( -path "*/public" -o -path "*/tmp" -o -path "*/vendor" -o -path "*/+" -o -path "*/.git" \) -prune -o -type f -name "*.bak" -print | while read -r file; do
  if ! is_ignored "$file"; then
    rm -f "$file"
  fi
done
set -e  # Включаем обратно
#
echo "Все файлы обработаны."

# Удалить все строки подобные `# encoding: utf-8` из файлов *.rb, кроме самой `# encoding: utf-8` 
#
# shopt -s nocasematch # Включить режим, в котором сравнение строк будет игнорировать регистр
# Обработка .rb файлов (с учетом .gitignore)
set +e  # Отключаем для проверок .gitignore
find "$DIR" -type f \( -path "*/public/*" -o -path "*/tmp/*" -o -path "*/vendor/*" -o -path "*/+/*" -o -path "*/.git/*" \) -prune -o -type f -name "*.rb" -print | while read -r file; do
  # Пропускаем файлы из .gitignore
  if is_ignored "$file"; then continue; fi
  sed -i '1s/^\xEF\xBB\xBF//' "$file" # Убираем BOM из файла (если присутствует)
  frst_line=$(head -n 1 "$file" |             tr -d ' ' | tr '[:upper:]' '[:lower:]') # Получить первую строку файла без пробелов в нижнем регистре
  scnd_line=$(head -n 2 "$file" | tail -n 1 | tr -d ' ' | tr '[:upper:]' '[:lower:]') # Получить вторую строку файла без пробелов в нижнем регистре
  if [[ "$frst_line" =~ ^\#encoding\:utf\-8 || "$frst_line" =~ ^\#coding\:utf\-8 ]]; then # Если первая строка соответствует одному из шаблонов
    if [[ "$scnd_line" =~ ^\#encoding\:utf\-8 || "$scnd_line" =~ ^\#coding\:utf\-8 ]]; then # Если вторая строка соответствует одному из шаблонов
      sed -i '1,2d' "$file" # Удаляем первую и вторую строку и сохраняем изменения в файл
      echo "Удалена первая и вторая строка из файла: $file"
    else
      # if grep -qi "# encoding: utf-8" "$file"; then
      if [[ "$(head -n 1 "$file")" =~ ^\#\ encoding\:\ utf\-8 ]]; then
        echo "Файл $file уже содержит строку \`# encoding: utf-8\`"
        continue
      else
        sed -i '1d' "$file" # Удаляем первую строку и сохраняем изменения в файл
        echo "Удалена первая строка из файла: $file"
      fi
    fi
  fi
  echo "Добавляю строку \`# encoding: utf-8\` в файл: $file"
  (echo "# encoding: utf-8"; cat "$file") > "$file.tmp" # Создать временный файл с новой первой строкой
  mv "$file.tmp" "$file" # Перемещаем временный файл обратно в исходный
done
set -e  # Включаем обратно
# shopt -u casematch # Включить режим, в котором сравнение строк НЕ будет игнорировать регистр
#
echo "Все файлы *.rb обработаны."

# Проверка и исправление наличия строки `- # coding: utf-8` в начале всех .haml файлов, за исключением файлов, включаемых в другие файлы (_*.haml)
#
# Обработка .haml файлов (с учетом .gitignore)
set +e  # Отключаем для проверок .gitignore
find "$DIR" -type f \( -path "*/public/*" -o -path "*/tmp/*" -o -path "*/vendor/*" -o -path "*/+/*" -o -path "*/.git/*" \) -prune -o -type f -name "*.haml" ! -name "_*.haml" -print | while read -r file; do
  # Пропускаем файлы из .gitignore
  if is_ignored "$file"; then continue; fi
  sed -i '1s/^\xEF\xBB\xBF//' "$file" # Убираем BOM из файла (если присутствует)
  frst_line=$(head -n 1 "$file" |             tr -d ' ' | tr '[:upper:]' '[:lower:]') # Получить первую строку файла без пробелов в нижнем регистре
  scnd_line=$(head -n 2 "$file" | tail -n 1 | tr -d ' ' | tr '[:upper:]' '[:lower:]') # Получить вторую строку файла без пробелов в нижнем регистре
  if [[ "$frst_line" =~ ^\-\#encoding\:utf\-8 || "$frst_line" =~ ^\-\#coding\:utf\-8 ]]; then # Если первая строка соответствует одному из шаблонов
    if [[ "$scnd_line" =~ ^\-\#encoding\:utf\-8 || "$scnd_line" =~ ^\-\#coding\:utf\-8 ]]; then # Если вторая строка соответствует одному из шаблонов
      sed -i '1,2d' "$file" # Удаляем первую и вторую строку и сохраняем изменения в файл
      echo "Удалена первая и вторая строка из файла: $file"
    else
      # if grep -qi "- # encoding: utf-8" "$file"; then
      if [[ "$(head -n 1 "$file")" =~ ^\-\ \#\ encoding\:\ utf\-8 ]]; then
        echo "Файл $file уже содержит строку \`- # encoding: utf-8\`"
        continue
      else
        sed -i '1d' "$file" # Удаляем первую строку и сохраняем изменения в файл
        echo "Удалена первая строка из файла: $file"
      fi
    fi
    echo "Добавляю строку \`- # encoding: utf-8\` в файл: $file"
    (echo "- # encoding: utf-8"; cat "$file") > "$file.tmp" # Создаем временный файл с новой первой строкой
    mv "$file.tmp" "$file" # Перемещаем временный файл обратно в исходный
  fi
done
set -e  # Включаем обратно
#
echo "Все файлы *.haml (кроме _*.haml) обработаны."

# Функция для проверки и применения dos2unix
#
check_and_apply_dos2unix() {
  local file="$1"
  # Проверяем наличие CRLF (Windows line endings)
  if file "$file" | grep -q "CRLF"; then
    echo "Обнаружены CRLF line endings в файле: $file"
    if command -v dos2unix >/dev/null 2>&1; then
      dos2unix "$file"
      echo "Применен dos2unix к файлу: $file"
    else
      echo "ПРЕДУПРЕЖДЕНИЕ: dos2unix не найден, пропускаем файл: $file"
    fi
  fi
}

# Применяем dos2unix к .rb и .haml файлам при необходимости
#
echo "Проверка line endings в .rb и .haml файлах..."
# Проверка line endings в .rb и .haml файлах (с учетом .gitignore)
set +e  # Отключаем для проверок .gitignore
find "$DIR" -type f \( -path "*/public/*" -o -path "*/tmp/*" -o -path "*/vendor/*" -o -path "*/+/*" -o -path "*/.git/*" \) -prune -o -type f \( -name "*.rb" -o -name "*.haml" \) -print | while read -r file; do
  # Пропускаем файлы из .gitignore
  if is_ignored "$file"; then continue; fi
  check_and_apply_dos2unix "$file"
done
set -e  # Включаем обратно

# Очистка от мусора
#
find . -type f -name "*.swp" -exec rm -v {} \;

echo "Обработка завершена."
