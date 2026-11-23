class_name MejoraDef
extends Resource

# Una mejora del árbol de la panadería. Igual que las recetas, las mejoras se describen
# como datos y no como código, así que agregar una es llenar una ficha en el inspector.
#
# Cada mejora toca una sola cosa del juego y la toca multiplicando. El significado del
# factor depende de qué mejora sea, y está anotado en la ficha de cada una: en las que
# suben algo el número va sobre uno, y en las que acortan una espera va bajo uno.


## Identificador corto que viaja por la red cuando alguien compra esta mejora.
@export var id: StringName = &""

## Nombre que se le muestra al jugador en el árbol.
@export var nombre: String = ""

## Una línea que explica qué hace, para el globo de ayuda del panel.
@export var descripcion: String = ""

## Dibujo que va dentro del medallón.
@export var icono: Texture2D

## Cuántas monedas cuesta comprarla.
@export var precio: int = 0

## Qué mejora hay que tener comprada antes de poder comprar esta. Vacío significa que es
## la primera de su rama y se puede comprar desde el primer día.
@export var requiere: StringName = &""

## En qué rama del árbol se dibuja, contando desde la izquierda, y en qué escalón dentro
## de esa rama. Solo sirven para armar el panel, no cambian nada del juego.
@export var rama: int = 0
@export var escalon: int = 0

## Por cuánto multiplica lo suyo cuando está comprada.
@export var factor: float = 1.0


func es_raiz() -> bool:
	return requiere == &""
