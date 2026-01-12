# Скрипт для генерації SSH ключа для Bitbucket

Write-Host "=== Генерація SSH ключа для Bitbucket ===" -ForegroundColor Green
Write-Host ""

# Перевірка наявності SSH ключа
$sshPath = "$env:USERPROFILE\.ssh"
$publicKeyPath = "$sshPath\id_rsa.pub"
$privateKeyPath = "$sshPath\id_rsa"

if (Test-Path $publicKeyPath) {
    Write-Host "Знайдено існуючий SSH ключ!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ваш публічний ключ:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Get-Content $publicKeyPath
    Write-Host ""
    Write-Host "Якщо ви хочете створити новий ключ, видаліть старі файли:" -ForegroundColor Yellow
    Write-Host "  Remove-Item $privateKeyPath" -ForegroundColor Gray
    Write-Host "  Remove-Item $publicKeyPath" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "SSH ключ не знайдено. Генерую новий..." -ForegroundColor Yellow
    Write-Host ""
    
    # Створення директорії .ssh якщо не існує
    if (-not (Test-Path $sshPath)) {
        New-Item -ItemType Directory -Path $sshPath -Force | Out-Null
        Write-Host "Створено директорію: $sshPath" -ForegroundColor Green
    }
    
    # Генерація SSH ключа
    Write-Host "Генерую SSH ключ (це може зайняти кілька секунд)..." -ForegroundColor Yellow
    
    # Використовуємо ssh-keygen через cmd для уникнення проблем з PowerShell
    $email = Read-Host "Введіть ваш email для Bitbucket (або натисніть Enter для пропуску)"
    
    if ($email) {
        ssh-keygen -t rsa -b 4096 -C "$email" -f "$privateKeyPath" -N '""'
    } else {
        ssh-keygen -t rsa -b 4096 -f "$privateKeyPath" -N '""'
    }
    
    if (Test-Path $publicKeyPath) {
        Write-Host ""
        Write-Host "✓ SSH ключ успішно створено!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Ваш публічний ключ:" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        Get-Content $publicKeyPath
        Write-Host ""
    } else {
        Write-Host "Помилка при створенні SSH ключа!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Інструкції для додавання ключа в Bitbucket ===" -ForegroundColor Green
Write-Host ""
Write-Host "1. Скопіюйте весь публічний ключ вище (починається з 'ssh-rsa')" -ForegroundColor White
Write-Host "2. Перейдіть на https://bitbucket.org/account/settings/ssh-keys/" -ForegroundColor White
Write-Host "3. Натисніть 'Add key'" -ForegroundColor White
Write-Host "4. Вставте скопійований ключ у поле 'Key'" -ForegroundColor White
Write-Host "5. Додайте опис (наприклад, 'My Computer')" -ForegroundColor White
Write-Host "6. Натисніть 'Add key'" -ForegroundColor White
Write-Host ""
Write-Host "Після додавання ключа ви зможете використовувати SSH для роботи з Bitbucket!" -ForegroundColor Cyan
Write-Host ""
