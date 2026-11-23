class_name Mejoras
extends Node

# Qué mejoras lleva compradas la panadería. Vive como autoload porque el panel del árbol,
# la cocina, los clientes y los gatos necesitan la misma respuesta en todas las máquinas.
#
# La compra la decide siempre el servidor, igual que en el recetario. Cualquier jugador la
# pide, el servidor revisa que la mejora exista, que no esté comprada, que la anterior de
# su rama sí lo esté y que alcance la plata, recién ahí cobra y avisa a todos. Así dos
# gatos que aprietan el mismo medallón al mismo tiempo no la compran dos veces ni dejan
# el dinero en negativo.
#
# Las mejoras son de la panadería, no de cada gato: comprar patas ligeras las hace más
# rápidos a todos. Es lo mismo que pasa con las recetas y evita tener que repartir un
# estado distinto por jugador.

static var instance: Mejoras

## Todo el árbol, comprado o no.
@export var arbol: MejoraSet

## Se emite en todas las máquinas cuando una mejora pasa a estar comprada.
signal mejora_comprada(id_mejora: StringName)

var _compradas: Array[StringName] = []


func _ready() -> void:
	if instance == null:
		instance = self
	else:
		queue_free()
		return


func esta_comprada(id_mejora: StringName) -> bool:
	return id_mejora in _compradas


## Copia de lo comprado. Se entrega copiada para que nadie de afuera pueda desbloquear
## una mejora sin pasar por la compra.
func compradas() -> Array[StringName]:
	return _compradas.duplicate()


## Si ya se puede comprar: que exista, que no esté comprada y que la anterior de su rama
## sí lo esté. No mira el dinero, porque el panel necesita distinguir la que está
## bloqueada por el árbol de la que solo está cara.
func esta_disponible(id_mejora: StringName) -> bool:
	if arbol == null:
		return false
	var mejora: MejoraDef = arbol.buscar_por_id(id_mejora)
	if mejora == null or esta_comprada(id_mejora):
		return false
	return mejora.es_raiz() or esta_comprada(mejora.requiere)


## Por cuánto multiplica una mejora lo suyo. Sin comprar devuelve uno, que es el valor
## neutro, así que los lugares que la usan pueden multiplicar siempre sin preguntar.
func factor_de(id_mejora: StringName) -> float:
	if arbol == null or not esta_comprada(id_mejora):
		return 1.0
	var mejora: MejoraDef = arbol.buscar_por_id(id_mejora)
	return mejora.factor if mejora else 1.0


# ---- lo que el juego le pregunta al árbol ----
#
# Van como funciones con nombre y no como ids sueltos repartidos por el código, para que
# en el lugar donde se usan se lea qué significan y no haya que venir a buscar acá.

## Por cuánto se multiplica lo que paga cada pan. Las dos mejoras de la caja se acumulan.
func multiplicador_de_precio() -> float:
	return factor_de(&"buen_ojo") * factor_de(&"clientela_fiel")


## Por cuánto se alarga el plazo para encadenar la siguiente entrega.
func factor_de_ventana_de_racha() -> float:
	return factor_de(&"racha_larga")


## Por cuánto se alarga lo que un cliente aguanta antes de irse.
func factor_de_paciencia() -> float:
	return factor_de(&"clientes_pacientes")


## Por cuánto se acorta la espera entre un cliente y el siguiente. Va bajo uno.
func factor_de_llegada() -> float:
	return factor_de(&"boca_a_boca")


## Por cuánto se alarga el aguante de un gato cargando a otro.
func factor_de_aguante() -> float:
	return factor_de(&"lomo_firme")


## Por cuánto se acorta lo que tarda en recuperarse. Va bajo uno.
func factor_de_recuperacion() -> float:
	return factor_de(&"segundo_aire")


## Por cuánto se multiplica la velocidad al caminar y al correr.
func factor_de_velocidad() -> float:
	return factor_de(&"patas_ligeras")


# ---- la compra ----

# La pide cualquiera y el cuerpo solo corre en el servidor, que es el único que ve el
# dinero de verdad.
@rpc("any_peer", "call_local", "reliable")
func pedir_compra(id_mejora: StringName) -> void:
	if not multiplayer.is_server():
		return
	if not esta_disponible(id_mejora):
		return
	var mejora: MejoraDef = arbol.buscar_por_id(id_mejora)
	var gestor: GameManager = GameManager.instance
	if gestor == null or gestor.dinero_recaudado < mejora.precio:
		return
	gestor.quitar_dinero(mejora.precio)
	confirmar_compra.rpc(id_mejora)


@rpc("authority", "call_local", "reliable")
func confirmar_compra(id_mejora: StringName) -> void:
	if esta_comprada(id_mejora):
		return
	_compradas.push_back(id_mejora)
	mejora_comprada.emit(id_mejora)
