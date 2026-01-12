@echo off
echo Перейменовую maaacks_input_remapping для усунення конфлікту...
if exist "addons\maaacks_input_remapping" (
    ren "addons\maaacks_input_remapping" "maaacks_input_remapping.disabled"
    echo Готово! Папка перейменована на maaacks_input_remapping.disabled
    echo Тепер перезапустіть Godot.
) else (
    echo Папка addons\maaacks_input_remapping не знайдена.
)
pause
