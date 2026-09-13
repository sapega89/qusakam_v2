# 🎬 Інструкція створення DemoEndScreen.tscn

## Крок 1: Створення сцени

1. Відкрити Godot Editor
2. File → New Scene
3. Вибрати `Control` як кореневий вузол
4. Зберегти як `SampleProject/Scenes/UI/DemoEndScreen.tscn`

## Крок 2: Структура сцени

```
DemoEndScreen (Control)
├── VBoxContainer (VBoxContainer)
│   ├── TitleLabel (Label)
│   ├── MessageLabel (Label)
│   └── ReturnButton (Button)
```

## Крок 3: Налаштування вузлів

### 3.1 DemoEndScreen (Control)

- **Anchors Preset**: Full Rect (Ctrl+Shift+Click на Full Rect)
- **Script**: `SampleProject/Scripts/UI/DemoEndScreen.gd`
- **Visible**: false (буде показано через скрипт)

### 3.2 VBoxContainer

- **Anchors Preset**: Center (Ctrl+Shift+Click на Center)
- **Size**: (600, 400)
- **Alignment**: Center

### 3.3 TitleLabel

- **Text**: "Дякуємо за гру!"
- **Horizontal Alignment**: Center
- **Vertical Alignment**: Center
- **Font Size**: 48
- **Autowrap Mode**: Enabled

### 3.4 MessageLabel

- **Text**: "Ви завершили демо-версію гри.\n\nСподіваємося, вам сподобалося!"
- **Horizontal Alignment**: Center
- **Vertical Alignment**: Center
- **Font Size**: 24
- **Autowrap Mode**: Enabled

### 3.5 ReturnButton

- **Text**: "Повернутися до головного меню"
- **Size**: (300, 50)
- **Horizontal Alignment**: Center

## Крок 4: Стилізація (опціонально)

### 4.1 Фон для DemoEndScreen

1. Додати `ColorRect` як дочірній вузол DemoEndScreen
2. Налаштувати:
   - **Anchors Preset**: Full Rect
   - **Color**: (0, 0, 0, 0.8) - напівпрозорий чорний

### 4.2 Стилізація кнопки

1. Вибрати ReturnButton
2. В Inspector → Theme Overrides → Colors:
   - **Font Color**: Білий
   - **Font Hover Color**: Світло-сірий
3. В Inspector → Theme Overrides → Styles:
   - **Normal**: StyleBoxFlat з темним фоном
   - **Hover**: StyleBoxFlat з світлішим фоном

## Крок 5: Перевірка

1. Відкрити сцену в Godot Editor
2. Перевірити, що всі вузли правильно налаштовані
3. Запустити сцену (F6) для перевірки вигляду

## Крок 6: Інтеграція

Сцена автоматично завантажується через `LaboratoryOutside.gd` після завершення діалогу `Demo_End`.

## Примітки

- Екран блокує ввід гравця під час показу
- Після натискання кнопки відбувається перехід до головного меню
- Анімація появи/зникнення реалізована в скрипті
