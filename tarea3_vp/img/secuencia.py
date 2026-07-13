#!/usr/bin/env python3
"""Diagrama de secuencias del VP (RgbToGrayAccel) — genera secuencia.png/.svg.
Regenerar:  python3 secuencia.py"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, Rectangle

actors = ["Programa C\n(ARM64)", "Gem5ToTlmBridge32", "RgbToGrayAccel", "DRAM (gem5)"]
X = {a: i for i, a in enumerate(["C", "BR", "ACC", "DRAM"])}
xs = [0, 3.0, 6.0, 9.0]
top, bot = 0.0, -13.0

fig, ax = plt.subplots(figsize=(11.5, 7.2))
ax.set_xlim(-1.2, 10.2); ax.set_ylim(bot - 1.2, top + 1.4); ax.axis("off")

# cabeceras + líneas de vida
for a, x in zip(actors, xs):
    ax.add_patch(Rectangle((x - 1.05, top + 0.15), 2.1, 0.75, facecolor="#D6E8F7",
                           edgecolor="#33506b", linewidth=1.2, zorder=3))
    ax.text(x, top + 0.52, a, ha="center", va="center", fontsize=10.5, zorder=4,
            fontweight="bold")
    ax.plot([x, x], [top + 0.15, bot], ls=(0, (4, 3)), color="#9aa6b2", lw=1.0, zorder=1)

def msg(y, xa, xb, label, dashed=False, note_above=True, color="#1f3b57"):
    a, b = xs[xa], xs[xb]
    style = "-|>"
    ap = FancyArrowPatch((a, y), (b, y), arrowstyle=style, mutation_scale=14,
                         lw=1.4, color=color, ls="--" if dashed else "-", zorder=5)
    ax.add_patch(ap)
    mid = (a + b) / 2
    ax.text(mid, y + (0.22 if note_above else -0.34), label, ha="center",
            va="bottom" if note_above else "top", fontsize=9, zorder=6, color=color)

def selfnote(y, xa, label, color="#5a5a5a"):
    ax.text(xs[xa], y, label, ha="center", va="center", fontsize=8.5,
            style="italic", color=color, zorder=6,
            bbox=dict(boxstyle="round,pad=0.2", fc="#f3f3f3", ec="#cccccc", lw=0.8))

# --- cara de control (MMIO) ---
msg(-1.0, 0, 1, "write ADDR_INPUT/OUTPUT/NUM_PIXELS  (MMIO, 4 B)")
msg(-1.8, 1, 2, "b_transport  (cfg)")
msg(-2.7, 0, 1, "write CONTROL = START")
msg(-3.5, 1, 2, "b_transport  (START)")
selfnote(-4.2, 2, "notify start_event → do_process")

# --- cara de memoria (DMA troceado) ---
msg(-5.2, 2, 3, "DMA READ RGB  —  N × b_transport de ≤64 B", color="#7a4a12")
msg(-6.0, 3, 2, "datos RGB", dashed=True, note_above=False, color="#7a4a12")
selfnote(-6.7, 2, "convierte BT.709 (píxel a píxel)")
msg(-7.6, 2, 3, "DMA WRITE gris  —  N × b_transport de ≤64 B", color="#7a4a12")
msg(-8.4, 3, 2, "TLM OK", dashed=True, note_above=False, color="#7a4a12")
selfnote(-9.1, 2, "set DONE = 1")

# --- polling de DONE ---
msg(-10.0, 0, 1, "read CONTROL  (poll DONE)")
msg(-10.8, 1, 2, "b_transport  (read)")
msg(-11.7, 2, 0, "DONE = 1", dashed=True, note_above=False)
ax.text(4.5, -12.6, "La imagen gris queda en DRAM en ADDR_OUTPUT (la CPU la lee / persiste)",
        ha="center", fontsize=8.5, style="italic", color="#444")

ax.text(4.5, top + 1.15, "Diagrama de secuencias — programa en C manejando el acelerador (VP full-system)",
        ha="center", fontsize=12, fontweight="bold")
plt.tight_layout()
fig.savefig("img/secuencia.png", dpi=150, bbox_inches="tight", facecolor="white")
fig.savefig("img/secuencia.svg", bbox_inches="tight", facecolor="white")
print("secuencia generada")
