#!/usr/bin/env python3
"""
Branding generator for linkpc Flutter Client.
Generates SVG and high-resolution PNG icons using Pillow.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = "/home/user/vless-panel/linkpc/assets"
ICONS_DIR = os.path.join(OUTPUT_DIR, "icons")
BRANDING_DIR = os.path.join(OUTPUT_DIR, "branding")
os.makedirs(ICONS_DIR, exist_ok=True)
os.makedirs(BRANDING_DIR, exist_ok=True)

# 1. Generate Clean Vector SVG App Icon
svg_icon_content = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0F172A" />
      <stop offset="50%" stop-color="#080C14" />
      <stop offset="100%" stop-color="#030712" />
    </linearGradient>

    <!-- Neon Cyan Gradient -->
    <linearGradient id="cyanGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8" />
      <stop offset="50%" stop-color="#00F0FF" />
      <stop offset="100%" stop-color="#0284C7" />
    </linearGradient>

    <!-- Neon Emerald Gradient -->
    <linearGradient id="neonGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00FF88" />
      <stop offset="100%" stop-color="#10B981" />
    </linearGradient>

    <!-- Border Glow Gradient -->
    <linearGradient id="borderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF" stop-opacity="0.7" />
      <stop offset="50%" stop-color="#1E293B" stop-opacity="0.3" />
      <stop offset="100%" stop-color="#00FF88" stop-opacity="0.6" />
    </linearGradient>

    <!-- Drop Shadows and Glows -->
    <filter id="neonGlow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="10" result="blur1" />
      <feGaussianBlur stdDeviation="24" result="blur2" />
      <feMerge>
        <feMergeNode in="blur2" />
        <feMergeNode in="blur1" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>

    <filter id="pulseGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="14" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
  </defs>

  <!-- Base Squircle Background -->
  <rect x="16" y="16" width="480" height="480" rx="108" fill="url(#bgGrad)" stroke="url(#borderGrad)" stroke-width="4" />

  <!-- Subtle Cyber Matrix Grid in background -->
  <g opacity="0.08" stroke="#00F0FF" stroke-width="1.5">
    <line x1="80" y1="120" x2="432" y2="120" />
    <line x1="80" y1="190" x2="432" y2="190" />
    <line x1="80" y1="260" x2="432" y2="260" />
    <line x1="80" y1="330" x2="432" y2="330" />
    <line x1="80" y1="400" x2="432" y2="400" />
    <line x1="120" y1="80" x2="120" y2="432" />
    <line x1="190" y1="80" x2="190" y2="432" />
    <line x1="260" y1="80" x2="260" y2="432" />
    <line x1="330" y1="80" x2="330" y2="432" />
    <line x1="400" y1="80" x2="400" y2="432" />
  </g>

  <!-- Decorative Corner Cyber Brackets -->
  <path d="M 52 110 L 52 52 L 110 52" fill="none" stroke="#00F0FF" stroke-width="3" opacity="0.3" />
  <path d="M 460 110 L 460 52 L 402 52" fill="none" stroke="#00F0FF" stroke-width="3" opacity="0.3" />
  <path d="M 52 402 L 52 460 L 110 460" fill="none" stroke="#00F0FF" stroke-width="3" opacity="0.3" />
  <path d="M 460 402 L 460 460 L 402 460" fill="none" stroke="#00FF88" stroke-width="3" opacity="0.3" />

  <!-- Ambient Radial Glow behind the central logo -->
  <circle cx="240" cy="256" r="130" fill="#00F0FF" opacity="0.12" filter="blur(40px)" />

  <!-- Core Logo Glyph: Stylized Futuristic 'linkpc' Monogram -->
  <!-- Represents: 'L' and High-Speed Tunnel Beam Link '>' with active secure node -->
  <g filter="url(#neonGlow)">
    <!-- Primary Vertical Stem of 'L' -->
    <path d="M 148 130 
             L 196 130 
             L 196 320 
             L 310 320 
             L 310 368 
             L 148 368 
             Z" 
          fill="url(#cyanGrad)" />

    <!-- Upper High-Speed Tunnel Beam (Data Wave entering) -->
    <path d="M 230 148 
             L 348 248 
             L 300 248 
             L 204 168 
             Z" 
          fill="url(#cyanGrad)" opacity="0.8" />

    <!-- Terminal Fast Node Chevron (Encrypted Egress) -->
    <path d="M 252 248 
             L 358 248 
             L 396 284 
             L 358 320 
             L 252 320 
             L 282 284 
             Z" 
          fill="url(#cyanGrad)" />

    <!-- Active Shield Node Point -->
    <circle cx="396" cy="284" r="14" fill="url(#neonGrad)" filter="url(#pulseGlow)" />
    <circle cx="396" cy="284" r="6" fill="#FFFFFF" />
  </g>
</svg>
'''

with open(os.path.join(BRANDING_DIR, "icon.svg"), "w") as f:
    f.write(svg_icon_content)

# 2. Generate Full Horizontal SVG Logo
svg_logo_content = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 240" width="800" height="240">
  <defs>
    <linearGradient id="cyanGradFull" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8" />
      <stop offset="50%" stop-color="#00F0FF" />
      <stop offset="100%" stop-color="#0284C7" />
    </linearGradient>
    <linearGradient id="neonGradFull" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00FF88" />
      <stop offset="100%" stop-color="#10B981" />
    </linearGradient>
    <filter id="neonGlowFull" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="8" result="blur1" />
      <feMerge>
        <feMergeNode in="blur1" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
  </defs>

  <!-- Left Icon Mark -->
  <g transform="translate(10, 10) scale(0.43)">
    <!-- Base Squircle -->
    <rect x="16" y="16" width="480" height="480" rx="108" fill="#080C14" stroke="#00F0FF" stroke-width="4" stroke-opacity="0.5" />
    <!-- Glyph -->
    <g filter="url(#neonGlowFull)">
      <path d="M 148 130 L 196 130 L 196 320 L 310 320 L 310 368 L 148 368 Z" fill="url(#cyanGradFull)" />
      <path d="M 230 148 L 348 248 L 300 248 L 204 168 Z" fill="url(#cyanGradFull)" opacity="0.8" />
      <path d="M 252 248 L 358 248 L 396 284 L 358 320 L 252 320 L 282 284 Z" fill="url(#cyanGradFull)" />
      <circle cx="396" cy="284" r="14" fill="url(#neonGradFull)" />
      <circle cx="396" cy="284" r="6" fill="#FFFFFF" />
    </g>
  </g>

  <!-- Text "linkpc" in Futuristic Monospace -->
  <g transform="translate(260, 138)">
    <text font-family="'JetBrains Mono', 'Consolas', monospace" font-size="94" font-weight="900" fill="#FFFFFF" letter-spacing="-1">
      link<tspan fill="#00F0FF">pc</tspan>
    </text>
    <!-- Subtitle / Tagline -->
    <text y="42" font-family="'JetBrains Mono', 'Consolas', monospace" font-size="16" font-weight="700" fill="#38BDF8" letter-spacing="4" opacity="0.85">
      // HIGH-SPEED SECURE GATEWAY
    </text>
  </g>
</svg>
'''

with open(os.path.join(BRANDING_DIR, "logo.svg"), "w") as f:
    f.write(svg_logo_content)


# 3. Render High-Resolution Antialiased PNG with Pillow (4x supersampling)
def generate_png_icon(size=512):
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = int(16 * (canvas_size / 512.0))
    corner_r = int(108 * (canvas_size / 512.0))

    # Dark squircle background
    # Multi-pass gradient simulation
    bg_rect = [pad, pad, canvas_size - pad, canvas_size - pad]
    draw.rounded_rectangle(bg_rect, radius=corner_r, fill=(8, 12, 20, 255), outline=(0, 240, 255, 120), width=int(5 * scale))

    # Inner subtle cyber border
    inner_pad = pad + int(10 * scale)
    inner_r = max(10, corner_r - int(10 * scale))
    draw.rounded_rectangle([inner_pad, inner_pad, canvas_size - inner_pad, canvas_size - inner_pad],
                           radius=inner_r, outline=(30, 41, 59, 140), width=int(2 * scale))

    # Coordinate mapping from 512 space to canvas_size
    def c(x, y):
        return (int(x * canvas_size / 512.0), int(y * canvas_size / 512.0))

    # Glow layer for the glyph
    glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # 1. Main L stem
    l_points = [c(148, 130), c(196, 130), c(196, 320), c(310, 320), c(310, 368), c(148, 368)]
    glow_draw.polygon(l_points, fill=(0, 240, 255, 200))

    # 2. Upper diagonal data beam
    beam_points = [c(230, 148), c(348, 248), c(300, 248), c(204, 168)]
    glow_draw.polygon(beam_points, fill=(56, 189, 248, 180))

    # 3. Forward node chevron
    chev_points = [c(252, 248), c(358, 248), c(396, 284), c(358, 320), c(252, 320), c(282, 284)]
    glow_draw.polygon(chev_points, fill=(0, 240, 255, 220))

    # 4. Active Node Circle
    pt_x, pt_y = c(396, 284)
    r_node = int(18 * scale)
    glow_draw.ellipse([pt_x - r_node, pt_y - r_node, pt_x + r_node, pt_y + r_node], fill=(0, 255, 136, 255))

    # Blur glow layer
    glow_blurred = glow.filter(ImageFilter.GaussianBlur(radius=int(14 * scale)))
    img.alpha_composite(glow_blurred)

    # Sharp top layer
    draw.polygon(l_points, fill=(0, 240, 255, 255))
    draw.polygon(beam_points, fill=(56, 189, 248, 230))
    draw.polygon(chev_points, fill=(0, 240, 255, 255))
    draw.ellipse([pt_x - r_node, pt_y - r_node, pt_x + r_node, pt_y + r_node], fill=(0, 255, 136, 255))

    # Inner bright white core of the node
    r_core = int(7 * scale)
    draw.ellipse([pt_x - r_core, pt_y - r_core, pt_x + r_core, pt_y + r_core], fill=(255, 255, 255, 255))

    # Downscale with high quality Lanczos filter for razor-sharp antialiasing
    final_icon = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_icon

# Render multiple sizes for multiplatform app stores and desktop icons
for s in [512, 192, 128, 64, 32]:
    icon = generate_png_icon(s)
    target_path = os.path.join(ICONS_DIR, f"app_icon_{s}.png" if s != 32 else "favicon.png")
    icon.save(target_path, "PNG")
    print(f"Generated {target_path}")

# Primary 512 icon as default app_icon.png
icon512 = generate_png_icon(512)
icon512.save(os.path.join(ICONS_DIR, "app_icon.png"), "PNG")
print("Icons generated successfully!")
