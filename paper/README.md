# Artículo científico — Proyecto final (MP-6160)

Artículo en **formato de conferencia IEEE** que documenta el proyecto del curso. El documento
es `articulo.tex` (clase `IEEEtran`) y se va completando por avances.

## Qué debe contener el artículo (del enunciado)

- **Formato IEEE conference**, máximo **6 páginas** (sin contar referencias), calidad de
  producción científica, figuras legibles y resultados reproducibles.
- Secciones mínimas recomendadas:
  - **Abstract** (≤ 250 palabras)
  - **Introducción** — problema, motivación y contribución
  - **Background and Related Work** — estado del arte y comparación
  - **Propuesta de Solución / Arquitectura** — arquitectura propuesta y funcionamiento
  - **Resultados y Análisis** — métricas, diseño del experimento, resultados y discusión
  - **Conclusiones y Trabajo Futuro**
- El artículo se va construyendo por avances (estado del arte → Avance I → Avance II →
  entrega final); incluir una **citación al repositorio** en la Propuesta de Solución.

> El artículo se escribe en `articulo.tex` (basado en la clase `IEEEtran`). Las secciones de
> avances futuros (Propuesta, Resultados, Conclusiones) están como esqueleto comentado.

---

## LaTeX — que todos usemos las mismas herramientas

LaTeX no se instala por subproyecto: TeX Live es un paquete de sistema. Para compilar igual
entre todos, usen **una** de estas dos opciones.

### Opción A — TeX Live local (recomendada)

```bash
sudo apt update
sudo apt install -y \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-science texlive-publishers latexmk
```

Cubre lo que usa la plantilla: `IEEEtran` (texlive-publishers), `algorithmic`
(texlive-science), `cite`, `amsmath/amssymb/amsfonts`, `graphicx`, `textcomp`, `xcolor`. Si en
algún momento falta un paquete, `sudo apt install texlive-full` lo trae todo (~5 GB).

Compilar:

```bash
cd paper
make          # genera articulo.pdf
make watch    # recompila automáticamente al guardar (latexmk -pvc)
make clean    # borra los artefactos de compilación
```

### Opción B — Overleaf (cero instalación)

Suban esta carpeta `paper/` a un proyecto de Overleaf. Incluye `IEEEtran.cls`, así que compila
sin configurar nada y permite edición simultánea.

> Los artefactos intermedios de LaTeX (`.aux`, `.log`, `.fls`, etc.) están en el `.gitignore`
> y no se commitean. El **PDF del artículo (`articulo.pdf`) sí se versiona** para tenerlo
> disponible sin recompilar; recuerden regenerarlo con `make` antes de commitear.

---

## Organización de la carpeta

```
paper/
  articulo.tex            # el artículo (clase IEEEtran)
  articulo.pdf            # PDF compilado (se versiona; regenerar con make)
  IEEEtran.cls            # clase IEEE (se versiona; garantiza el formato entre todos)
  fig1.png                # figura de ejemplo de la plantilla (reemplazar)
  Makefile                # compilación con latexmk (make / make watch / make clean)
  .gitignore              # ignora artefactos de compilación (no el PDF)
  IEEEtran_HOWTO.pdf      # manual oficial de IEEEtran (referencia)
  ieee-taxonomy.pdf       # taxonomía de términos IEEE (referencia)
```

## Referencias útiles

- `IEEEtran_HOWTO.pdf` — guía oficial de la clase `IEEEtran` (estructura, figuras, tablas,
  bibliografía).
- Plantillas IEEE: <https://www.ieee.org/conferences/publishing/templates.html>

---

## Declaración de uso de Inteligencia Artificial

> Para finalizar por el grupo. El enunciado exige declarar el uso de IA, su clase de
> utilización y los prompts; mantener esta declaración fiel a lo realmente hecho.

En la preparación de este artículo se utilizó un asistente basado en IA. Su uso, por clase de
utilización, fue el siguiente:

- **Consulta de conceptos.** Aclaración de la teoría de la transformada de Walsh-Hadamard
  (WHT), de la WHT entera reversible para compresión sin pérdidas y de su mapeo a hardware.
- **Búsqueda y verificación del estado del arte.** Localización de trabajos candidatos
  (aceleradores WHT, compresión de imágenes sin pérdidas en FPGA) y **verificación del texto
  completo de cada fuente** para confirmar afirmaciones, nombres de autores y DOIs contra el
  documento original. Toda cita se cotejó con su PDF.
- **Redacción asistida.** Asistencia para el primer borrador de la sección *Background and Related
  Work* fundamentado únicamente en las fuentes verificadas. Los autores son responsables de la versión final del texto.
- **Formato.** Referencias en formato IEEE con DOIs, selección de *keywords* a partir del IEEE
  Thesaurus/Taxonomy, y configuración de la plantilla `IEEEtran`.
- **Revisión crítica.** Revisión adversaria del texto contra los criterios del enunciado
  (≥2 soluciones reproducibles + 5 de cobertura parcial, fuentes indexadas, antigüedad) y de
  la precisión factual de cada afirmación frente a sus fuentes.

**Responsabilidad.** Los autores verificaron todas las afirmaciones y citas contra las fuentes
originales; ninguna salida del asistente se incorporó sin esa verificación. El contenido final,
las decisiones de diseño y la interpretación de los resultados son responsabilidad de los
autores.

### Prompts representativos

*(Parafraseados; la interacción fue conversacional, no una lista de prompts aislados.)*

1. "Lee el enunciado del proyecto y evalúa si un acelerador de la transformada Walsh-Hadamard
   encaja como tema de investigación."
2. "Investiga el estado del arte de aceleradores WHT y de compresión de imágenes sin pérdidas
   en FPGA; identifica soluciones reproducibles y de cobertura parcial, con fuentes indexadas
   y recientes."
3. "Verifica, leyendo el texto completo de cada PDF, que las afirmaciones y citas de la sección
   coincidan con la fuente: nombres de autores, DOIs y datos numéricos."
4. "Para el borrador de la sección *Background and Related Work*: asegurate que esté fundamentado solo en las fuentes verificadas, con citas en formato IEEE."
5. "Revisa el borrador de forma adversaria contra el enunciado y señala incumplimientos o
   imprecisiones."
6. "Ayúdame a encontrar potenciales *keywords* usando la taxonomía/Thesaurus del IEEE."
7. "Evalúa si la redacción fluye de forma natural."
