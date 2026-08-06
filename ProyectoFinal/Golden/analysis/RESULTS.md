# Resultados de reducción de entropía

**Reproducir:**
```
cd ProyectoFinal/Golden
make entropy      # tabla principal, N=8 (el tamaño del hardware)
make sweep        # barrido N = 8/16/32 + control de sesgo del estimador
make visual       # figura original / coeficientes / reconstrucción / diferencia
```

## Metodología
- Entropía orden-0 (Shannon sobre el histograma de valores), en bits/símbolo.
- Bloqueo 1D N=8 por filas: exactamente lo que hace el hardware. Métrica principal.
- Bloqueo 2D separable (WHT por filas y luego por columnas): extensión **solo software** del golden;
  el hardware no la hace.
- *Pooled* (todos los coeficientes en un histograma) vs **por-banda** (una entropía por posición de
  frecuencia, promediada). La segunda es el coste efectivo de un codificador que modela cada banda
  por separado, y es la métrica principal.
- Transformada *length-preserving* (N píxeles → N coeficientes), así que comparar bits/símbolo es
  apples-to-apples.
- Datasets (256×256, 8 bits, deterministas, semilla 42): `flat` (constante), `ramp` (gradiente),
  `edges` (regiones constantes), `natural` (superficie 1/f^1.2, correlación tipo imagen natural),
  `noise` (ruido blanco, **control**: sin correlación que explotar, ninguna transformada debería
  mejorarlo).

## Tabla principal, N=8 (bits/símbolo)

| dataset | H_píxeles | 1D pool | 1D band | red. 1D band | 2D pool | 2D band | red. 2D band |
|---|---|---|---|---|---|---|---|
| flat    | 0.000 | 0.544 | 0.000 | — (ver nota) | 0.116 | 0.000 | — |
| ramp    | 8.000 | 2.625 | 0.625 | 92 % | 0.540 | 0.078 | 99 % |
| edges   | 2.000 | 0.794 | 0.250 | 87 % | 0.147 | 0.031 | 98 % |
| natural | 7.304 | 6.546 | 5.808 | 20 % | 5.864 | 5.309 | 27 % |
| noise   | 7.997 | 8.751 | 8.200 | −2.5 % (control) | 8.774 | 7.844 | +1.9 % |

> **Nota sobre `flat`.** La imagen es constante, así que su entropía de píxeles ya es 0 y no hay nada
> que reducir: el «—» no es un fallo de medida, es que el porcentaje de reducción sería 0/0. Sirve
> como caso degenerado de control en el otro extremo de `noise`. Lo que sí dice algo es que el
> *pooled* sube a 0.544: mezclar la banda DC con las de detalle **infla** la entropía aunque cada
> banda por separado valga 0, que es justo el motivo por el que la métrica principal es la por-banda.

## Entropía por banda 1D, N=8 (b0 = DC/baja frec … b7 = alta frec)

| dataset | b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7 |
|---|---|---|---|---|---|---|---|---|
| flat    | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| ramp    | 5.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| edges   | 2.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| natural | 7.21 | 4.27 | 5.12 | 5.64 | 5.94 | 5.46 | 6.28 | 6.55 |
| noise   | 6.74 | 7.73 | 7.72 | 8.68 | 7.73 | 8.70 | 8.69 | 9.63 |

## Barrido de tamaño de bloque (`make sweep`)

Solo 1D, y solo software: el núcleo sintetizado es N=8. `M` son las muestras por banda y `techo` es
`log₂(M)`, la cota superior de lo que el estimador puede reportar.

| dataset | N=8 band | N=16 band | N=32 band | M (8/16/32) |
|---|---|---|---|---|
| flat    | 0.000 | 0.000 | 0.000 | 8192 / 4096 / 2048 |
| ramp    | 0.625 | 0.250 | 0.094 | 8192 / 4096 / 2048 |
| edges   | 0.250 | 0.125 | 0.062 | 8192 / 4096 / 2048 |
| natural | 5.808 | 5.721 | 5.674 | 8192 / 4096 / 2048 |
| noise   | 8.200 | 8.147 | 8.040 | 8192 / 4096 / 2048 |

**Sin overflow en ninguna combinación.** Comparando cada bloque contra aritmética de precisión
amplia, `ovf = 0` en las 15 corridas. El coeficiente de mayor magnitud es 1020 (N=8) y 2040 (N=16),
ambos exhaustivos sobre las esquinas `{0,255}ᴺ`; para N=32 el máximo observado es 3315. Contra el
límite 32767 de `ap_int<16>`, el margen es de 8× o más incluso en el peor caso: **el datapath de 16
bits sigue bastando si se sube el tamaño de bloque.**

### Control de sesgo — por qué el barrido es 1D y no 2D

La entropía empírica de un histograma con M muestras está **acotada por `log₂(M)`**. Al subir N, M
baja, y la subestimación del estimador se confunde con compresión. Con imágenes de 256×256:

| | N=8 | N=16 | N=32 |
|---|---|---|---|
| M por banda, 1D | 8192 | 4096 | 2048 |
| M por banda, 2D | 1024 | 256 | **64 → techo 6 bits** |

A N=32 en 2D el techo (6 bits) queda **por debajo** de la entropía real de una fuente sin correlación
(~8 bits): el número que saldría no mediría compresión, mediría falta de muestras. Por eso el barrido
se reporta en **1D**, y el **2D solo en N=8**.

Para saber cuánto de la caída del barrido es real, `make sweep` incluye un control: fija N=8 y
submuestrea los bloques hasta las mismas M del barrido. Los datos no cambian, así que **toda caída
ahí es sesgo puro**:

| dataset | caída del barrido (N=8→32) | caída por sesgo puro | efecto real |
|---|---|---|---|
| natural | 0.134 | **0.018** | ~0.116 bits — la tendencia es real |
| noise (control) | 0.160 | **0.138** | ~0.02 — **es artefacto, como debe ser** |
| edges | 0.188 | 0.000 | todo real |
| ramp | 0.531 | 0.250 | ~0.28 real |

El control funciona: la «mejora» del ruido blanco se explica casi entera por el sesgo, que es lo que
tiene que pasar con una fuente que no se puede comprimir. **El sesgo depende de la distribución** —es
mucho mayor en `noise`, casi uniforme, que en `natural`—, así que hay que compararlo dataset a
dataset, no aplicar un número global.

## Qué mide y qué no mide cada test de la suite

Importa porque la suite es la evidencia del artículo, y dos de sus cinco líneas no aportan
información:

| Test | Qué compara | ¿Enlaza el núcleo sintetizable? |
|---|---|---|
| **E4** | golden forward vs `wht_lossless_core`, 100 001 casos de 8 bits | **Sí** |
| **E4b** | golden inverso vs `wht_lossless_inverse`, 100 001 casos de 16 bits plenos | **Sí** |
| **E5** | round-trip del **modelo**, 400 001 casos | **No**: solo golden |
| **E6** | round-trip del **hardware**, `inv_core(fwd_core(x))==x`, 400 001 casos | **Sí** |
| **E5b** | forward de 16 bits vs precisión amplia, entrada de 8 bits | **No**: solo golden |
| **E5c** | inverso de 16 bits vs precisión amplia | **No**: solo golden |

**E6 es el que respalda la afirmación de reconstrucción del artículo.** Hace falta aparte de E4 y
E4b porque las dos equivalencias son disjuntas en la práctica: E4 ejercita el forward con entradas de
8 bits, cuyos coeficientes ocupan una región minúscula del espacio de 16 bits, y E4b ejercita el
inverso con vectores uniformes de 16 bits. Comprobado por mutación: rompiendo el núcleo inverso
(`d>>1` → `d>>2`) o el forward (patrón de etapa cambiado), **E5 sigue en verde y E6 falla**.

Dos matices que conviene tener claros antes de citar estos números:

- **E5b no puede fallar.** Con entrada en [0,255] el coeficiente máximo posible es 1020 contra el
  límite 32767: el forward no puede envolver, así que el 0 es por construcción, no por evidencia.
- **El inverso invierte al forward en todo `ap_int<16>`**, no solo sobre un «dominio alcanzable» —el
  forward es una biyección sobre todo el rango—. Lo que diverge fuera de la entrada de 8 bits es la
  comparación contra precisión amplia, porque `>>1` impide que un wrap intermedio se cancele
  módulo 2¹⁶.

Fuera de `make verify`, `make systemc` sí enlaza el núcleo, sobre 2001 casos.

## Lectura
- La reducción escala con la correlación espacial: `ramp`/`edges` (muy suaves) 87–92 %; `natural`
  (realista) ~20 % en 1D y ~27 % en 2D; `noise` (sin correlación) no mejora — es el control.
- El desglose por banda muestra la compactación de energía: en `ramp`/`edges` toda la información
  queda en el DC (b0) y los detalles (b1–b7) caen a 0. En `natural` el DC concentra la energía (7.21)
  y los detalles son más comprimibles.
- **El 2D añade 0.50 bits/símbolo sobre los 1.50 que ya gana el 1D** (7.304 → 5.808 → 5.309). Dicho
  como cociente de porcentajes serían 20 % → 27 %, un factor 1.33 — **no «casi el doble»**, que es
  como estaba escrito antes y no se sostiene. Es el argumento para una extensión 2D como trabajo
  futuro.
- El titular defendible: **`natural`, 1D por-banda, ~20 % de reducción con el hardware real (N=8)**;
  27 % en 2D como extensión software.
