from PIL import Image
import sys

img_path = '/Users/sakshi/.gemini/antigravity/brain/8187cf3e-1e77-4e79-8da4-0d5d99dcb9f9/media__1780395459470.png'
try:
    img = Image.open(img_path)
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    
    # We want to keep the white parts and make everything else transparent
    for item in datas:
        # white is 255, 255, 255
        if item[0] > 220 and item[1] > 220 and item[2] > 220:
            new_data.append(item)
        else:
            new_data.append((255, 255, 255, 0))
            
    img.putdata(new_data)
    img.save('FMS/Assets.xcassets/AppLogo.imageset/AppLogo.png')
    print("Image processed successfully.")
except Exception as e:
    print(f"Error processing image: {e}")
