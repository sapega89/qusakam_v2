# Скрипт для разрезания спрайт-листа на отдельные спрайты
# Автоматически находит непустые области и вырезает их

from PIL import Image
import os

def find_sprite_bounds(img, start_x, start_y, max_w, max_h):
    """Находит границы спрайта начиная с позиции"""
    pixels = img.load()
    width, height = img.size
    
    # Ищем правую границу
    right = start_x
    for x in range(start_x, min(start_x + max_w, width)):
        has_pixel = False
        for y in range(start_y, min(start_y + max_h, height)):
            if pixels[x, y][3] > 10:  # Альфа > 10
                has_pixel = True
                right = x
                break
        if not has_pixel and x > right + 5:
            break
    
    # Ищем нижнюю границу  
    bottom = start_y
    for y in range(start_y, min(start_y + max_h, height)):
        has_pixel = False
        for x in range(start_x, right + 1):
            if pixels[x, y][3] > 10:
                has_pixel = True
                bottom = y
                break
        if not has_pixel and y > bottom + 5:
            break
    
    return right - start_x + 1, bottom - start_y + 1

def split_by_grid(img, cell_width, cell_height, output_dir):
    """Разрезает по фиксированной сетке"""
    width, height = img.size
    cols = width // cell_width
    rows = height // cell_height
    
    count = 0
    for row in range(rows):
        for col in range(cols):
            x = col * cell_width
            y = row * cell_height
            
            # Вырезаем кадр
            frame = img.crop((x, y, x + cell_width, y + cell_height))
            
            # Проверяем есть ли непрозрачные пиксели
            pixels = frame.load()
            has_content = False
            for py in range(cell_height):
                for px in range(cell_width):
                    if pixels[px, py][3] > 10:
                        has_content = True
                        break
                if has_content:
                    break
            
            if has_content:
                frame.save(os.path.join(output_dir, f"sprite_{row:02d}_{col:02d}.png"))
                count += 1
    
    return count

def split_by_rows(img, output_dir):
    """Разрезает по рядам, определяя высоту каждого ряда автоматически"""
    width, height = img.size
    pixels = img.load()
    
    # Находим ряды по горизонтальным пустым линиям
    row_starts = []
    in_row = False
    
    for y in range(height):
        has_pixel = False
        for x in range(width):
            if pixels[x, y][3] > 10:
                has_pixel = True
                break
        
        if has_pixel and not in_row:
            row_starts.append(y)
            in_row = True
        elif not has_pixel and in_row:
            in_row = False
    
    print(f"Найдено {len(row_starts)} рядов спрайтов")
    
    # Определяем высоту каждого ряда
    row_heights = []
    for i, start in enumerate(row_starts):
        if i < len(row_starts) - 1:
            # Ищем конец ряда
            end = start
            for y in range(start, row_starts[i + 1]):
                for x in range(width):
                    if pixels[x, y][3] > 10:
                        end = y
                        break
            row_heights.append(end - start + 1)
        else:
            # Последний ряд
            end = start
            for y in range(start, height):
                for x in range(width):
                    if pixels[x, y][3] > 10:
                        end = y
                        break
            row_heights.append(end - start + 1)
    
    # Вырезаем каждый ряд
    count = 0
    for i, (start, h) in enumerate(zip(row_starts, row_heights)):
        row_img = img.crop((0, start, width, start + h + 5))
        
        # Находим отдельные спрайты в ряду
        in_sprite = False
        sprite_start = 0
        sprites_in_row = 0
        
        for x in range(width):
            has_pixel = False
            for y in range(h + 5):
                px = row_img.load()[x, y] if x < row_img.width and y < row_img.height else (0,0,0,0)
                if len(px) >= 4 and px[3] > 10:
                    has_pixel = True
                    break
            
            if has_pixel and not in_sprite:
                sprite_start = x
                in_sprite = True
            elif not has_pixel and in_sprite:
                # Конец спрайта
                sprite = row_img.crop((sprite_start, 0, x, h + 5))
                sprite.save(os.path.join(output_dir, f"row{i:02d}_sprite{sprites_in_row:02d}.png"))
                sprites_in_row += 1
                count += 1
                in_sprite = False
        
        # Последний спрайт в ряду
        if in_sprite:
            sprite = row_img.crop((sprite_start, 0, width, h + 5))
            sprite.save(os.path.join(output_dir, f"row{i:02d}_sprite{sprites_in_row:02d}.png"))
            count += 1
    
    return count

def main():
    # Путь к спрайт-листу
    input_path = "character-spritesheet (8).png"
    output_dir = "SampleProject/Sprites/Character"
    
    # Создаём папку для вывода
    os.makedirs(output_dir, exist_ok=True)
    
    # Загружаем изображение
    print(f"Загружаю {input_path}...")
    img = Image.open(input_path).convert("RGBA")
    print(f"Размер: {img.width}x{img.height}")
    
    # Разрезаем по рядам
    print("Разрезаю спрайт-лист...")
    count = split_by_rows(img, output_dir)
    
    print(f"\nГотово! Сохранено {count} спрайтов в {output_dir}/")
    print("\nТеперь вы можете:")
    print("1. Открыть папку и посмотреть спрайты")
    print("2. Выбрать нужные для анимаций (Idle, Run, Jump, Fall)")
    print("3. Сказать мне какие файлы использовать")

if __name__ == "__main__":
    main()

