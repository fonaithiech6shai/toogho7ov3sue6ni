-- SQL для добавления поля permissions в таблицу accounts
-- Выполнить вручную в MySQL:

ALTER TABLE accounts ADD COLUMN role_permissions TEXT DEFAULT NULL;

-- Установить базовые разрешения для существующих админов
UPDATE accounts SET role_permissions = '[]' WHERE role_permissions IS NULL;
