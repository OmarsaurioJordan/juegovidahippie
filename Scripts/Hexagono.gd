extends Area2D

const EXPLOS = [
	preload("res://Scenes/ExtallidoLuz.tscn"),
	preload("res://Scenes/ExtallidoSombra.tscn")
]

const VACIO = 0
const SOMBRA = 1
const LUZ = 2
const size = 45.0 # talla de centro a punta superior

var tipo = VACIO
var foco = false # cuando esta apuntado por el mouse
var vecinos = []
var indices = [] # direccion del vecino, 0:derecha, giro contra reloj

# creacion de hexagono

func _ready():
	CambioTipo(VACIO)
	CambioFoco(false)

func CambioTipo(elTipo):
	tipo = elTipo
	$Imagen.frame = tipo
	if tipo == VACIO:
		$Imagen.self_modulate = Color(Color.WHITE, 0.25)
	else:
		$Imagen.self_modulate = Color(Color.WHITE, 1.0)

func CambioFoco(enFoco, seleccion=VACIO):
	foco = enFoco
	if foco:
		$Imagen.scale = Vector2(0.6, 0.6)
		z_index = 1
		$Imagen.frame = seleccion
		var ok = true
		if tipo == VACIO and seleccion != VACIO:
			if !GetVida():
				$Imagen.self_modulate = Color(Color.WHITE, 0.5)
				ok = false
		elif tipo != VACIO and seleccion == VACIO:
			if GetVida():
				$Imagen.self_modulate = Color(Color.WHITE, 0.5)
				ok = false
		if ok:
			$Imagen.self_modulate = Color(Color.WHITE, 1.0)
	else:
		$Imagen.scale = Vector2(0.5, 0.5)
		z_index = 0
		CambioTipo(tipo)

func AleatorioEstetico():
	if randf() < 0.5:
		$Imagen.frame = SOMBRA
	else:
		$Imagen.frame = LUZ
	$Imagen.self_modulate = Color(Color.WHITE, 1.0)

func NewVecino(veci):
	vecinos.append(veci)

func DireccionesVecinos():
	var ang
	var pdz = PI / 6.0
	for hex in vecinos:
		ang = position.direction_to(hex.position).angle()
		if ang < pdz or ang > 11 * pdz:
			indices.append(0)
		elif ang < 3 * pdz:
			indices.append(1)
		elif ang < 5 * pdz:
			indices.append(2)
		elif ang < 7 * pdz:
			indices.append(3)
		elif ang < 9 * pdz:
			indices.append(4)
		else:
			indices.append(5)

# obtener informacion

func GetVecinoDireccion(ind):
	# 0,1,2,3,4,5 siendo 0 derecha, giro contra reloj
	for i in range(indices.size()):
		if indices[i] == ind:
			return vecinos[i]
	return null

func GetTipo():
	return tipo

func IsVacio():
	return tipo == VACIO

func GetFoco():
	return foco

func NumVecinos():
	var total = 0
	for veci in vecinos:
		if veci.GetTipo() != VACIO:
			total += 1
	return total

func GetVida():
	var total = NumVecinos()
	return total >= 2 and total <= 4

func NumVecinosTipo(elTipo):
	var total = 0
	for veci in vecinos:
		if veci.GetTipo() == elTipo:
			total += 1
	return total

# accion principal al hacer clic, crear o destruir

func Accion(tipoMouse):
	# devuelve VACIO si falla, sino LUZ o SOMBRA independiente de muerte o vida
	if tipoMouse == VACIO:
		if tipo != VACIO and !GetVida():
			var t = tipo
			var explo = EXPLOS[0]
			if tipo == SOMBRA:
				explo = EXPLOS[1]
			explo = explo.instantiate()
			get_parent().get_parent().add_child(explo)
			explo.global_position = global_position
			CambioTipo(VACIO)
			return t
	else:
		if tipo == VACIO and GetVida():
			CambioTipo(tipoMouse)
			return tipo
	return VACIO

# comprobacion de formas

func FormaAro():
	# true si esta ficha ha sido puesta para completar un aro
	if tipo == VACIO:
		return false
	for veci in vecinos:
		# a partir de aqui se observa la forma del aro
		if veci.NumVecinosTipo(tipo) == 6:
			return true
	return false

func FormaLinea(linMax, esDiversa=false):
	# true si esta ficha ha sido puesta para completar una linea
	if tipo == VACIO:
		return false
	var linea = [0, 0, 0, 0, 0, 0]
	var aux
	var tp
	for i in range(6):
		# cada una de las lineas que salen de la ficha
		tp = tipo
		aux = GetVecinoDireccion(i)
		while aux != null:
			if esDiversa:
				if tp == LUZ:
					tp = SOMBRA
				else:
					tp = LUZ
			if aux.GetTipo() == tp:
				linea[i] += 1
			else:
				break
			aux = aux.GetVecinoDireccion(i)
	# conteo de lineas
	if 1 + linea[0] + linea[3] >= linMax:
		return true
	elif 1 + linea[1] + linea[4] >= linMax:
		return true
	elif 1 + linea[2] + linea[5] >= linMax:
		return true
	else:
		return false
