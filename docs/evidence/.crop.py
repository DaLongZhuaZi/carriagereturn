from PIL import Image
for t in ['a','b']:
    im=Image.open(f'docs/evidence/.tmp-{t}1920.png').crop((60,1050,900,1350))
    im.save(f'docs/evidence/.tmp-roll-{t}.png')
print('ok')
