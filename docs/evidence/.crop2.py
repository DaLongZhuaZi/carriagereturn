from PIL import Image
im=Image.open('docs/evidence/.tmp-b1960.png')
im.crop((60,1050,1560,1400)).save('docs/evidence/.tmp-crop1960.png')
print('ok')
