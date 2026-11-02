from PIL import Image

focus_img = Image.open('Resources/Mascot/character_2_focus.jpg').convert('RGBA')
notes = Image.open('chrome_notes.png').convert('RGBA')

comp = Image.alpha_composite(focus_img, notes)
out_path = 'Resources/Mascot/character_5_music.jpg'
comp.convert('RGB').save(out_path, quality=95)
print(f"Saved {out_path}")
