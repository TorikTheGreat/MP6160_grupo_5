#!/usr/bin/env python3
"""Generador de datasets para los experimentos de entropía

Genera 5 imágenes 256x256 de 8 bits (formato PGM P5), deterministas
(semilla fija) => reproducibles sin descargar nada. Cubren el espectro
de correlación espacial, de máxima (flat) a nula (noise), para mostrar
cuando y cuanto la WHT ayuda y cuando no.

Nota: se usó un patrón sintético con espectro 1/f como sustituto
"natural" (tiene la correlación espacial de una imagen real). Si se
agrega una foto real, basta convertirla a PGM 8-bit y el experimento
la toma igual.
"""


import numpy as np

W = H = 256
OUT = __file__.rsplit("/", 1)[0]

def write_pgm(name, arr):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    path = f"{OUT}/{name}.pgm"
    with open(path, "wb") as f:
        f.write(f"P5\n{W} {H}\n255\n".encode())
        f.write(arr.tobytes())
    print(f"{name:10s}  {path}   min={arr.min():3d} max={arr.max():3d}")

# 1) flat: constante. Correlación total; caso degenerado (entropía ~0).
write_pgm("flat", np.full((H, W), 128))

# 2) ramp: gradiente horizontal 0..255. Muy suave (alta correlación).
write_pgm("ramp", np.tile(np.linspace(0, 255, W), (H, 1)))

# 3) edges: regiones constantes con bordes filosos (mayormente liso).
edges = np.zeros((H, W))
edges[:H//2, :W//2] = 40
edges[:H//2, W//2:] = 110
edges[H//2:, :W//2] = 185
edges[H//2:, W//2:] = 225
write_pgm("edges", edges)

# 4) natural: superficie con espectro 1/f (correlación espacial tipo
#    imagen natural). Ruido blanco filtrado en frecuencia.
rng = np.random.default_rng(42)
white = rng.standard_normal((H, W))
F = np.fft.fftshift(np.fft.fft2(white))
fx = np.fft.fftshift(np.fft.fftfreq(W))
fy = np.fft.fftshift(np.fft.fftfreq(H))
FX, FY = np.meshgrid(fx, fy)
radius = np.sqrt(FX**2 + FY**2)
radius[radius == 0] = 1e-6
F = F / (radius ** 1.2)                       # 1/f^1.2
surf = np.real(np.fft.ifft2(np.fft.ifftshift(F)))
surf = (surf - surf.min()) / (surf.max() - surf.min()) * 255
write_pgm("natural", surf)

# 5) noise: ruido blanco uniforme. Sin correlación => la WHT NO ayuda
#    (caso honesto de control).
write_pgm("noise", rng.integers(0, 256, (H, W)))
