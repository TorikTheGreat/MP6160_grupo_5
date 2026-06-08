# Compilación del artículo IEEE con latexmk.
DOC = conference_101719

pdf:
	latexmk -pdf -halt-on-error $(DOC).tex

# Recompila automáticamente al guardar (Ctrl-C para salir).
watch:
	latexmk -pdf -pvc $(DOC).tex

# Borra TODOS los artefactos, incluido el PDF generado.
clean:
	latexmk -C

.PHONY: pdf watch clean
