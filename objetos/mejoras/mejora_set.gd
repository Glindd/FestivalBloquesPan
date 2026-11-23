class_name MejoraSet
extends Resource

# El árbol de mejoras de la panadería. Se guarda como recurso para que el panel y el
# juego lean siempre la misma lista y no cada uno su propia copia, igual que el recetario.


## Las mejoras, en el orden en que se quieran recorrer. El dibujo del árbol no sale de
## este orden sino de la rama y el escalón de cada una.
@export var mejoras: Array[MejoraDef] = []


func buscar_por_id(id_mejora: StringName) -> MejoraDef:
	for mejora: MejoraDef in mejoras:
		if mejora and mejora.id == id_mejora:
			return mejora
	return null


## Las mejoras de una rama, ordenadas por escalón, que es como se dibujan de arriba
## hacia abajo en el panel.
func de_la_rama(numero: int) -> Array[MejoraDef]:
	var lista: Array[MejoraDef] = []
	for mejora: MejoraDef in mejoras:
		if mejora and mejora.rama == numero:
			lista.push_back(mejora)
	lista.sort_custom(func(a: MejoraDef, b: MejoraDef) -> bool: return a.escalon < b.escalon)
	return lista


## Cuántas ramas tiene el árbol.
func cuantas_ramas() -> int:
	var maximo: int = -1
	for mejora: MejoraDef in mejoras:
		if mejora and mejora.rama > maximo:
			maximo = mejora.rama
	return maximo + 1
