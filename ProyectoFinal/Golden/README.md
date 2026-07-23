# Golden WHT (W3) — modelo de referencia, verificación y entropía

Parte de W3 del proyecto del acelerador WHT lossless. Contiene el **modelo de
referencia (golden) en SystemC** del núcleo WHT, los **testbenches de
verificación bit-exacta** contra el núcleo HLS de W1, y los **experimentos de
reducción de entropía**.

## Requisitos
- `g++` con soporte C++17.
- **SystemC** (`libsystemc`) — solo para `make systemc`. Se enlaza con la del
  sistema (`-lsystemc`), sin variables de entorno extra.
- `python3` + `numpy` — para generar los datasets.


## Estructura
```
compat/    shim de ap_int (solo para compilar sin Vitis; no se sintetiza)
src/       golden: forward + inverse (templado por tipo numérico)
tb/        testbenches en C++: equivalencia (E4), round-trip + overflow (E5/E5b)
systemc/   módulo golden en SystemC + testbench de demostración
data/      generador de datasets (determinista) + los 5 PGM
analysis/  experimento de entropía + RESULTS.md (resultados)
Makefile   build y ejecución de todo
```

## Uso
```
make test      # verificación completa: equivalencia + round-trip + entropía
make verify    # solo equivalencia vs núcleo W1 + round-trip lossless
make systemc   # demo del golden en SystemC (entrada -> coeficientes -> reconstrucción)
make entropy   # experimento de reducción de entropía sobre los 5 datasets
make datasets  # (re)genera los PGM
make clean
```

## Qué se verifica
- **Equivalencia bit-exacta** entre el golden y el núcleo HLS de W1, sobre un
  vector fijo y 100 000 bloques aleatorios de 8 bits (a nivel de fuente C++, no
  contra la RTL sintetizada).
- **Lossless:** `inverse(forward(x)) == x` sobre 400 000 bloques, incluyendo el
  rango de 16 bits con signo completo. Confirma que la construcción es
  exactamente reversible.
- **Suficiencia de 16 bits:** el forward en `ap_int<16>` coincide con una
  referencia de precisión amplia (sin wrap) → 0 overflow para entrada de 8 bits.
- **Reducción de entropía:** entropía orden-0 de los píxeles vs. los coeficientes
  de la WHT, sobre 5 datasets (de correlación espacial máxima a nula). Detalle y
  tablas en [`analysis/RESULTS.md`](analysis/RESULTS.md).

## Notas de diseño
- El golden implementa el **forward** (réplica exacta del lifting de W1) y el
  **inverse**. El núcleo de hardware es forward-only; el inverse vive solo en el
  golden y sirve para demostrar el round-trip lossless.
- La aritmética está en **funciones puras** (`src/`); SystemC es solo la cáscara
  del testbench, para no mezclar la matemática con tipos de simulación.
- Entrada asumida en 8 bits `[0,255]`; el rango es parametrizable.

## Notas sobre el análisis de los resultados
Ver ProyectoFinal/Golden/analysis/RESULTS.md, ahí están documentados los resultados 
para que el compañero a cargo de integración ponga lo que considere necesario en el readme final

## Uso de IA
En el desarrollo de esta parte (W3) se utilizó un asistente de IA (Claude) como
apoyo para el diseño y la implementación del modelo de referencia en SystemC, los
testbenches de verificación, los datasets y el experimento de entropía, así como
para redactar un borrador de la sección de resultados. El diseño, la revisión de
cada resultado, la verificación y la edición final estuvieron a cargo del autor.
<!-- W3: ajustar a lo que declares con exactitud; W5 unifica la declaración del grupo. -->
