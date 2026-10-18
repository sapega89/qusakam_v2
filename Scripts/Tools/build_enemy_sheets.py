# Лист спрайтів ворога з паку: рядки idle / walk / attack / death, клітинка 96x72,
# кадри віддзеркалені (у паку морда ліворуч, у грі спрайт дивиться праворуч), тіло idle по центру клітинки.
from PIL import Image
A='D:/Projects/new-game-project/assets/ChatGPT Image Jul 30, 2025, 06_51_40 PM-autotile/'
OUT='D:/Projects/new-game-project/SampleProject/Assets/Characters/Enemies/'
CW,CH=96,72
for folder,pre,attack,name in [('1 Centipede','Centipede','attack3','centipede'),('2 Battle turtle','Battle_turtle','attack2','battle_turtle')]:
    rows=[]
    for a in ['idle','walk',attack,'death']:
        im=Image.open(f'{A}{folder}/{pre}_{a}.png').convert('RGBA')
        rows.append([im.crop((i*72,0,i*72+72,72)).transpose(Image.FLIP_LEFT_RIGHT) for i in range(im.size[0]//72)])
    l,_,r,_=rows[0][0].getbbox()
    dx=CW//2-(l+r)//2
    cols=max(len(r) for r in rows)
    sheet=Image.new('RGBA',(cols*CW,len(rows)*CH))
    for y,row in enumerate(rows):
        for x,f in enumerate(row):
            sheet.alpha_composite(f,(x*CW+dx,y*CH))
    sheet.save(OUT+name+'/sheet.png')
    print(name,'cols',cols,'frames',[len(r) for r in rows],'dx',dx)
