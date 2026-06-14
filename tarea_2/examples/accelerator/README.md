Acelerador funcional + testbench. Lo pueden usar para **ejecutar y experimentar**. Conecta un "CPU"
de prueba, el acelerador y la RAM real:

```
ConfigDriver (CPU) --cfg--> Accelerator --mem--> RAM
```

## Archivos
- `../../include/accelerator.h` — el módulo del acelerador (target de config + initiator a RAM).
- `../../include/rgb_to_gray.h` — la conversión luma BT.709 (compartida por DUT y golden).
- `../../include/ram.h` — la RAM
- `tb_accelerator.cpp` — el testbench. Corre **dos trabajos** en una sola simulación:
  1. imagen sintética 8×8 → verifica la conversión contra un golden (`RESULTADO: PASA`);
  2. una imagen real → la convierte y guarda el gris en `output.pgm` para verla.

## Compilar y correr
```bash
source ../../activate.sh      # carga SystemC (o el Makefile usa ../../tools/systemc)
make run
```
Salida esperada: los 5 colores conocidos convertidos (negro 0, blanco 255, rojo 54, verde 182,
azul 18), `RESULTADO: PASA (N/N píxeles correctos)` y un `output.pgm`.

## Probar con una imagen propia
El testbench lee **PPM binario (P6)** desde `images/input.ppm` y escribe **PGM (P5)** en
`images/output.pgm`, abribles en cualquier visor (GIMP, `eog`, ImageMagick). El directorio
`images/` está gitignored (no se versionan las imágenes). Convierte tu foto a PPM y corre:
```bash
convert foto.jpg images/input.ppm    # ImageMagick (o: ffmpeg -i foto.jpg images/input.ppm)
make run
xdg-open images/output.pgm           # ver el gris  (o: convert images/output.pgm out.png)
```
Si no hay `images/input.ppm`, el ejemplo genera unas barras de color de muestra. Cambia los pesos en
`rgb_to_gray.h` (p. ej. BT.601 `0.299/0.587/0.114`), corre de nuevo y compara `output.pgm`:
verás cambiar el brillo de cada color (con BT.709 el verde sale muy claro y el azul muy oscuro)
y el `gris min/prom/max` que imprime el trabajo 2.

## Para experimentar (cambia y vuelve a correr)
- **Tamaño de imagen:** `WIDTH`/`HEIGHT` en `tb_accelerator.cpp` (prueba `1920`/`1080`).
- **La fórmula:** los pesos en `rgb_to_gray.h` (p. ej. BT.601 `0.299/0.587/0.114`) — verás
  cambiar los grises (y, como golden y DUT comparten el header, sigue dando PASA).
- **El tiempo:** quita el `wait(delay)` en `do_process` (accelerator.h) y mira que el tiempo de
  simulación deja de avanzar (`DONE en t=0`).
- **Errores de rango:** pon `DST_ADDR` cerca del final de los 64 MB y un tamaño grande; la RAM
  responde `TLM_ADDRESS_ERROR_RESPONSE` y el `sc_assert` lo caza.
- **Caso vacío:** `NUM=0` → el acelerador marca DONE sin emitir transacciones.

`make clean` borra el binario y los archivos generados (`input.rgb`, `output.gray`).
