# Resultados de reducción de entropía 
Este documento se puede quedar en el feature branch. Cuando hagamos un merge a
main, el compañero responsable de la integración puede tomar lo que considere
importante para el readme del proyecto. Además nos servirá para la discución
del paper.

**Reproducir:**
```
python3 Golden/data/gen_datasets.py         # genera los 5 PGM (deterministas)
g++ -std=c++17 -Wno-unknown-pragmas -I Source -I Golden/compat -I Golden/src \
    Golden/src/wht_golden.cpp Golden/analysis/entropy_experiment.cpp -o entropy
./entropy Golden/data/{flat,ramp,edges,natural,noise}.pgm
```

## Metodología 
- Entropía orden-0: (Shannon sobre el histograma de valores), en bits/símbolo.
- Bloqueo 1D N=8 por filas: exactamente lo que hace el hardware. Métrica principal.
- Bloqueo 2D separable: (WHT por filas y luego por column0as) = extensión solo del golden en software (el HW aún no la hace, future work).
- Pooled (todos los coeficientes en un histograma) vs por-banda (una entropía por posición de frecuencia, promediada: el costo efectivo de un encoder que modela cada banda; métrica más principled).
- Transformada length-preserving (N píxeles -> N coeficientes) -> comparación bits/símbolo es apples-to-apples.
- Datasets (256×256, 8-bit, deterministas): `flat` (constante), `ramp` (gradiente), `edges` (regiones constantes), `natural` (superficie 1/f, correlación tipo imagen natural), `noise` (ruido blanco, control sin correlación).

## Tabla principal (bits/símbolo)

| dataset | H_píxeles | 1D pool | 1D band | red. 1D band | 2D pool | 2D band | red. 2D band |
|---|---|---|---|---|---|---|---|
| flat    | 0.000 | 0.544 | 0.000 | — (degenerado) | 0.116 | 0.000 | — |
| ramp    | 8.000 | 2.625 | 0.625 | 92 % | 0.540 | 0.078 | 99 % |
| edges   | 2.000 | 0.794 | 0.250 | 87 % | 0.147 | 0.031 | 98 % |
| natural | 7.304 | 6.546 | 5.808 | 20 % | 5.864 | 5.309 | 27 % |
| noise   | 7.997 | 8.751 | 8.200 | −2.5 % (control) | 8.774 | 7.844 | +1.9 % |

## Entropía por banda 1D (b0 = DC/baja frec … b7 = alta frec)

| dataset | b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7 |
|---|---|---|---|---|---|---|---|---|
| flat    | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| ramp    | 5.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| edges   | 2.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| natural | 7.21 | 4.27 | 5.12 | 5.64 | 5.94 | 5.46 | 6.28 | 6.55 |
| noise   | 6.74 | 7.73 | 7.72 | 8.68 | 7.73 | 8.70 | 8.69 | 9.63 |

## Lectura
- La reducción escala con la correlación espacial: ramp/edges (muy suaves) 87–92 %; natural (realista) ~20% en 1D, ~27% en 2D; noise (sin correlación) no mejora. Esto lo podemos usar como un control, como el peor caso posible.
- El desglose por banda muestra la compactación de energía: en ramp/edges toda la información queda en el DC (b0) y los detalles (b1–b7) caen a 0. En natural el DC concentra la energía (7.21) y los detalles son más comprimibles.
- El 2D casi duplica el beneficio (natural 20% -> 27%). Esto nos sirve de argumento para extensión 2D como trabajo futuro.
- Natural, 1D por-banda, ~20% de reducción de entropía (con el HW real N=8); 2D ~27% como extensión. Creo que este número podría llamar la atención en el paper.
