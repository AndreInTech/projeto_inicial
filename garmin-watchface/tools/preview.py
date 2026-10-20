"""Renders an approximate preview of the watch face (same geometry as ForeChronoView.mc)."""
import math, sys
from PIL import Image, ImageDraw, ImageFont

S = 4  # supersampling

def render(size, theme, out):
    W = size * S; r = W / 2; cx = cy = r
    img = Image.new("RGB", (W, W), "#04070D" if theme == 0 else "#050505")
    d = ImageDraw.Draw(img)
    def xy(a, rad): return (cx + rad*math.sin(math.radians(a)), cy - rad*math.cos(math.radians(a)))
    def circ(x, y, rad, fill=None, outline=None, w=1): d.ellipse([x-rad, y-rad, x+rad, y+rad], fill=fill, outline=outline, width=w)
    def shape(pts, a, dx=0, dy=0):
        s, c = math.sin(math.radians(a)), math.cos(math.radians(a))
        return [(cx+dx+p[0]*r*s+p[1]*r*c, cy+dy-p[0]*r*c+p[1]*r*s) for p in pts]
    def font(h):
        try: return ImageFont.truetype("DejaVuSans-Bold.ttf", int(h))
        except Exception: return ImageFont.load_default()
    def text(x, y, t, h, fill): d.text((x, y), t, font=font(h), fill=fill, anchor="mm")
    GOLD, LUME, GREY, SILVER = "#C9A66B", "#F4F1E6", "#6E747C", "#B8BCC2"
    bg, tex = ("#0B1F3F", "#173463") if theme == 0 else ("#121212", "#262626")
    circ(cx, cy, r*0.885, fill=bg)
    for i in range(13): circ(cx, cy, r*(0.52+i*0.027), outline=tex, w=S)
    for a in range(0, 360, 6): d.line([xy(a, r*0.10), xy(a, r*0.50)], fill=tex, width=S)
    circ(cx, cy, r*0.09, fill="#07090D"); circ(cx, cy, r*0.885, outline=GREY, w=2*S)
    for i in range(60):
        a = i*6
        if i % 10 == 0: text(*xy(a, r*0.94), "60" if i == 0 else str(i), r*0.07, GREY)
        elif i % 5 == 0: d.line([xy(a, r*0.91), xy(a, r*0.98)], fill=SILVER, width=3*S)
        else: d.line([xy(a, r*0.94), xy(a, r*0.98)], fill=GREY, width=S)
    for h in range(1, 12):
        if h in (3, 6, 9): continue
        d.polygon(shape([(0.70,-0.024),(0.84,-0.024),(0.84,0.024),(0.70,0.024)], h*30), fill=GOLD)
        d.polygon(shape([(0.715,-0.010),(0.825,-0.010),(0.825,0.010),(0.715,0.010)], h*30), fill=LUME)
    for i, n in enumerate(["12", "3", "6", "9"]):
        x, y = xy(i*90, r*0.765); text(x+2*S, y+2*S, n, r*0.2, "black"); text(x, y, n, r*0.2, GOLD)
    text(cx, cy-r*0.42, "MONDAY", r*0.1, LUME); text(cx, cy-r*0.285, "22", r*0.13, LUME)
    for a, v, l in [(315, "57%", "POWER"), (45, "1885", "ALT"), (225, "342", "KCAL"), (135, "5.5", "KM")]:
        x, y = xy(a, r*0.60); text(x, y-r*0.055, v, r*0.1, LUME); text(x, y+r*0.055, l, r*0.065, GOLD)
    def sub(x, y, rad, icon, val, extra=None):
        circ(x, y, rad, fill="#07090D", outline=GREY, w=2*S)
        d.line([(x-rad*1.08, y), (x-rad*0.8, y)], fill=SILVER, width=2*S); d.line([(x+rad*0.8, y), (x+rad*1.08, y)], fill=SILVER, width=2*S)
        icon(x, y-rad*(0.48 if extra else 0.40), r*0.03)
        text(x, y+rad*(0.05 if extra else 0.32), val, r*(0.09 if extra else 0.1), LUME)
        if extra: text(x, y+rad*0.55, extra, r*0.065, GOLD)
    def heart(x, y, s):
        circ(x-s*0.5, y-s*0.2, s*0.55, fill=LUME); circ(x+s*0.5, y-s*0.2, s*0.55, fill=LUME)
        d.polygon([(x-s*1.03, y), (x+s*1.03, y), (x, y+s*1.15)], fill=LUME)
    def steps(x, y, s):
        d.ellipse([x-s*0.98, y-s*0.55, x-s*0.22, y+s*0.85], fill=LUME); circ(x-s*0.6, y+s*1.15, s*0.28, fill=LUME)
        d.ellipse([x+s*0.22, y-s*1.05, x+s*0.98, y+s*0.35], fill=LUME); circ(x+s*0.6, y+s*0.65, s*0.28, fill=LUME)
    def weather(x, y, s):
        sx, sy, ss = x-s*0.5, y-s*0.35, s*0.85
        circ(sx, sy, ss*0.55, fill="#F2C14E")
        for a in range(0, 360, 45):
            d.line([(sx+ss*0.8*math.sin(math.radians(a)), sy-ss*0.8*math.cos(math.radians(a))),
                    (sx+ss*1.1*math.sin(math.radians(a)), sy-ss*1.1*math.cos(math.radians(a)))], fill="#F2C14E", width=2*S)
        x, y, s = x+s*0.2, y+s*0.15, s*0.9
        circ(x-s*0.55, y+s*0.15, s*0.5, fill=LUME); circ(x+s*0.1, y-s*0.15, s*0.7, fill=LUME); circ(x+s*0.75, y+s*0.2, s*0.45, fill=LUME)
        d.rectangle([x-s*0.55, y+s*0.15, x+s*0.75, y+s*0.65], fill=LUME)
    sub(cx-r*0.43, cy+r*0.04, r*0.21, heart, "159")
    sub(cx+r*0.43, cy+r*0.04, r*0.21, steps, "6859")
    sub(cx, cy+r*0.44, r*0.19, weather, "15°C", "18/9")
    HOUR = [(-0.06,-0.020),(0.17,-0.013),(0.20,-0.048),(0.43,-0.038),(0.52,0),(0.43,0.038),(0.20,0.048),(0.17,0.013),(-0.06,0.020)]
    HL = [(0.225,-0.030),(0.42,-0.023),(0.485,0),(0.42,0.023),(0.225,0.030)]
    MIN = [(-0.08,-0.018),(0.30,-0.011),(0.33,-0.036),(0.72,-0.027),(0.80,0),(0.72,0.027),(0.33,0.036),(0.30,0.011),(-0.08,0.018)]
    ML = [(0.355,-0.021),(0.71,-0.016),(0.765,0),(0.71,0.016),(0.355,0.021)]
    hh, mm, ss = 10, 9, 36
    for frame, lume, a in [(HOUR, HL, (hh % 12 + mm/60)*30), (MIN, ML, (mm + ss/60)*6)]:
        d.polygon(shape(frame, a, 3*S, 3*S), fill="black"); d.polygon(shape(frame, a), fill=GOLD); d.polygon(shape(lume, a), fill=LUME)
    sa = ss*6
    d.line([xy(sa, -r*0.18), xy(sa, r*0.86)], fill=GOLD, width=max(2, int(r*0.012)))
    circ(*xy(sa, -r*0.14), r*0.028, fill=GOLD); circ(cx, cy, r*0.038, fill=GOLD); circ(cx, cy, r*0.016, fill="black")
    mask = Image.new("L", (W, W), 0); ImageDraw.Draw(mask).ellipse([0, 0, W, W], fill=255)
    final = Image.new("RGB", (W, W), "black"); final.paste(img, mask=mask)
    final.resize((size, size), Image.LANCZOS).save(out)

if __name__ == "__main__":
    render(454, 0, sys.argv[1] + "/preview_blue.png")
    render(454, 1, sys.argv[1] + "/preview_black.png")
    render(70, 0, sys.argv[2] + "/launcher_icon.png")
