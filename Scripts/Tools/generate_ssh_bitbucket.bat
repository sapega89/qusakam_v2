@echo off
chcp 65001 >nul
echo === Генерація SSH ключа для Bitbucket ===
echo.

set SSH_PATH=%USERPROFILE%\.ssh
set PUBLIC_KEY=%SSH_PATH%\id_rsa.pub
set PRIVATE_KEY=%SSH_PATH%\id_rsa

if exist "%PUBLIC_KEY%" (
    echo Знайдено існуючий SSH ключ!
    echo.
    echo Ваш публічний ключ:
    echo ===================
    type "%PUBLIC_KEY%"
    echo.
    echo Якщо ви хочете створити новий ключ, видаліть старі файли:
    echo   del "%PRIVATE_KEY%"
    echo   del "%PUBLIC_KEY%"
    echo.
    goto :instructions
)

echo SSH ключ не знайдено. Генерую новий...
echo.

if not exist "%SSH_PATH%" (
    mkdir "%SSH_PATH%"
    echo Створено директорію: %SSH_PATH%
)

echo Генерую SSH ключ...
echo Відповідайте на питання (можна натискати Enter для пропуску)
echo.

ssh-keygen -t rsa -b 4096 -f "%PRIVATE_KEY%"

if exist "%PUBLIC_KEY%" (
    echo.
    echo ✓ SSH ключ успішно створено!
    echo.
    echo Ваш публічний ключ:
    echo ===================
    type "%PUBLIC_KEY%"
    echo.
) else (
    echo Помилка при створенні SSH ключа!
    pause
    exit /b 1
)

:instructions
echo.
echo === Інструкції для додавання ключа в Bitbucket ===
echo.
echo 1. Скопіюйте весь публічний ключ вище (починається з 'ssh-rsa')
echo 2. Перейдіть на https://bitbucket.org/account/settings/ssh-keys/
echo 3. Натисніть 'Add key'
echo 4. Вставте скопійований ключ у поле 'Key'
echo 5. Додайте опис (наприклад, 'My Computer')
echo 6. Натисніть 'Add key'
echo.
echo Після додавання ключа ви зможете використовувати SSH для роботи з Bitbucket!
echo.
pause
