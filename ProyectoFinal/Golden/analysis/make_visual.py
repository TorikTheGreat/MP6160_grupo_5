#!/usr/bin/env python3
"""Render de la figura: original -> coeficientes -> reconstruccion + diferencia.

Toma las PGM que emite make_visual (C++) y arma una figura de 2x2 paneles.

Los rotulos van en INGLES a proposito: el destino de esta figura es el
articulo IEEE. La disposicion es 2x2 y no 1x4 porque en una columna IEEE
(~0.48\\textwidth) cuatro paneles en fila quedan ilegibles.

Lo que muestra, y conviene tenerlo claro antes de escribir el pie de figura:
  - Por defecto la transformada es la WHT 1D con bloques de N=8 por filas, que
    es EXACTAMENTE lo que hace el nucleo sintetizado. (make_visual acepta "2d"
    para la variante separable, que es solo software.)
  - El panel de coeficientes es un remosaico POR SUBBANDAS con escala sqrt de
    la magnitud, no los coeficientes crudos: en 1D son 8 franjas verticales, la
    primera el DC.
  - El panel de diferencia es negro porque el lifting es exactamente
    reversible; su "max = 0" es el resultado, no un panel vacio por error.

Uso: make_visual.py <base>   (lee <base>_orig.pgm, <base>_coef.pgm, <base>_recon.pgm)
"""
import sys
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

base = sys.argv[1] if len(sys.argv) > 1 else "vis"
orig = np.asarray(Image.open(base + "_orig.pgm"))
coef = np.asarray(Image.open(base + "_coef.pgm"))
recon = np.asarray(Image.open(base + "_recon.pgm"))
diff = np.abs(orig.astype(int) - recon.astype(int))

fig, axs = plt.subplots(2, 2, figsize=(6.2, 6.6))
ax = axs.ravel()
ax[0].imshow(orig, cmap="gray", vmin=0, vmax=255)
ax[0].set_title("(a) Original", fontsize=10)
ax[1].imshow(coef, cmap="magma")
ax[1].set_title("(b) WHT coefficients\n(8 subbands, DC leftmost)", fontsize=10)
ax[2].imshow(recon, cmap="gray", vmin=0, vmax=255)
ax[2].set_title("(c) Reconstruction", fontsize=10)
ax[3].imshow(diff, cmap="gray", vmin=0, vmax=255)
ax[3].set_title("(d) |Original - Reconstruction|\nmax = %d" % diff.max(), fontsize=10)
for a in ax:
    a.axis("off")
fig.tight_layout()
out = base + ".png"
fig.savefig(out, dpi=160, bbox_inches="tight")
print("escrito:", out, " | diferencia maxima:", int(diff.max()))
