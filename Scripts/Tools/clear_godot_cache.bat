@echo off
echo ========================================
echo Clearing Godot Editor Cache
echo ========================================
echo.
echo This script will delete the .godot folder to clear Godot Editor cache.
echo Make sure Godot Editor is CLOSED before running this script!
echo.
pause

if exist ".godot" (
    echo Deleting .godot folder...
    rmdir /s /q ".godot"
    echo.
    echo .godot folder deleted successfully!
    echo.
    echo You can now open Godot Editor and the cache will be cleared.
) else (
    echo .godot folder not found. Cache may already be cleared.
)

echo.
pause
