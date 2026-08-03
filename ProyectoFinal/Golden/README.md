# Golden WHT — modelo de referencia, verificación y entropía

Contiene el **modelo de referencia (golden) en SystemC** del núcleo WHT, los **testbenches de 
verificación bit-exacta** contra los núcleos HLS (Forward e Inverso), y los **experimentos de
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
tb/        testbenches en C++: equivalencias, round-trip + overflow
systemc/   módulo golden en SystemC + testbench de demostración
data/      generador de datasets (determinista) + los 5 PGM
analysis/  experimento de entropía + RESULTS.md (resultados)
Makefile   build y ejecución de todo
```

## Uso
```
make test      # verificación completa: equivalencia + round-trip + entropía
make verify    # solo equivalencia vs núcleos HLS + round-trip lossless
make systemc   # demo del golden en SystemC (entrada -> coeficientes -> reconstrucción)
make entropy   # experimento de reducción de entropía sobre los 5 datasets
make datasets  # (re)genera los PGM
make clean
```

## Qué se verifica
- **Equivalencia bit-exacta** entre el golden y los núcleos HLS, sobre un
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
- El golden implementa el **forward** y el **inverse**. Ambos tienen su respectiva contraparte en hardware (HLS), logrando el round-trip lossless de extremo a extremo.
- La aritmética está en **funciones puras** (`src/`); SystemC es solo la cáscara
  del testbench, para no mezclar la matemática con tipos de simulación.
- Entrada asumida en 8 bits `[0,255]`; el rango es parametrizable.

## Notas sobre el análisis de los resultados
Ver `ProyectoFinal/Golden/analysis/RESULTS.md` donde están documentados los resultados finales.

## Uso de IA

En el desarrollo de esta parte se utilizó un asistente de IA (Claude, de Anthropic) en sesiones
interactivas con acceso al repositorio. 

**Clases de uso:**

- **Generación de código**
- **Consulta de conceptos**
- **Revisión crítica**
- **Depuración**
- **Redacción**

**Prompts representativos:**

- «verifica si este test puede fallar alguna vez, y demuéstralo con un experimento en vez de
  razonarlo»
- «extiende el experimento de entropía a N = 8, 16 y 32 sin tocar ficheros de otros roles»
- «haz una pasada adversaria sobre estos resultados y refuta lo que puedas»
- «revisa contra el enunciado si todo lo que se exige de este rol está cubierto»

**Verificación de lo generado.** Todo el código entregado se comprobó ejecutándolo: `make verify`
pasa 100 001 / 100 001 / 400 001 casos, y las cifras de `analysis/RESULTS.md` se reproducen con
`make entropy` y `make sweep`. Varias propuestas del asistente se rechazaron por no resistir esa
comprobación —entre ellas una explicación incorrecta de por qué el *lifting* es biyectivo, que un
contraejemplo tumbó—. Se declara que se comprende el funcionamiento del código entregado.
