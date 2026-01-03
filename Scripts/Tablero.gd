extends Node2D

# constantes de funcionamiento
const VACIO = 0
const SOMBRA = 1
const LUZ = 2

const CAM_SPEED = 200.0

# constantes manipulables
const misionLuzSombra = 4
const misionConexion = 5
const misionLDiversa = 6
const misionMuerte = 4
const totalFichas = 19

# variables de funcionamiento
var talla # ancho y alto de los hexagramas
var posClic = Vector2(0, 0) # para mover la camara
var miIP = "" # usado por cliente para comparar y borrar
var serverIP = "" # usado por cliente para conectar
var items = [] # listado de hexagramas
var seleccion = VACIO # el tipo de ficha a poner
var jugadores = [] # listado de nombres
var direcciones = [] # listado de IP del jugador
var misiones = [] # listado de mision para cada jugador
var killLuz = [] # cantidad de luz eliminada
var killSombra = [] # cantidad de sombra eliminada
var fichas = [0, totalFichas, totalFichas] # vacio, sombra, luz
var resultados = "" # se escribiran los sucesos del triunfo
var esMaster = true # servidor o sino es cliente
var enGUI = false # ver si el mouse esta en la GUI
var turnos = [] # indices para recorrer listas
var turno = 0 # indice actual dentro de turnos
var Raiz

# inicializacion

func _ready():
	var hex = load("res://Scenes/Hexagono.tscn")
	var aux = hex.instantiate()
	talla = Vector2(2.0 * aux.size, sqrt(3.0) * aux.size)
	aux.queue_free()
	CreaMalla()
	JuntaMisiones()
	Preparacion()
	$Camara/GUI/Acciones/SelVacio.button_pressed = true
	$Camara/GUI/Acciones/SelSombra.button_pressed = false
	$Camara/GUI/Acciones/SelLuz.button_pressed = false
	$Camara/GUI/Resultados.visible = false

func CreaMalla():
	var hex = load("res://Scenes/Hexagono.tscn")
	var aux
	var dos = [LUZ, SOMBRA]
	dos.shuffle()
	for x in range(-20, 21):
		for y in range(-20, 21):
			aux = hex.instantiate()
			$Hexagramas.add_child(aux)
			aux.position.x = x * talla.x
			aux.position.y = y * talla.y
			if y / 2.0 - int(y / 2.0) != 0:
				aux.position.x += talla.x / 2.0
			items.append(aux)
			# poner los primeros dos
			if x == 0 and y == 0:
				aux.CambioTipo(dos.pop_back())
			elif x == -1 and y == 0:
				aux.CambioTipo(dos.pop_back())
	# busca vecinos de hexagonos
	for hexa in items:
		for otro in items:
			if otro != hexa:
				if hexa.position.distance_to(otro.position) < talla.x + 10.0:
					hexa.NewVecino(otro)
	for hexa in items:
		hexa.DireccionesVecinos()

func JuntaMisiones():
	var aux
	for i in range(1, 7):
		aux = get_node("Camara/GUI/Mision/M" + str(i))
		aux.position = $Camara/GUI/Mision/M1.position
		aux.visible = false
	$Camara/GUI/Mision/M1.visible = false
	$Camara/GUI/Mision/ButVer.button_pressed = false
	# poner valores numericos
	var txt = $Camara/GUI/Mision/M1/Texto.text
	$Camara/GUI/Mision/M1/Texto.text = txt.replacen("$", str(misionLuzSombra))
	txt = $Camara/GUI/Mision/M2/Texto.text
	$Camara/GUI/Mision/M2/Texto.text = txt.replacen("$", str(misionLuzSombra))
	txt = $Camara/GUI/Mision/M3/Texto.text
	$Camara/GUI/Mision/M3/Texto.text = txt.replacen("$", str(misionConexion))
	txt = $Camara/GUI/Mision/M4/Texto.text
	$Camara/GUI/Mision/M4/Texto.text = txt.replacen("$", str(misionLDiversa))
	txt = $Camara/GUI/Mision/M6/Texto.text
	$Camara/GUI/Mision/M6/Texto.text = txt.replacen("$", str(misionMuerte))

func Preparacion():
	# inicializar cosas
	for i in range(6):
		jugadores.append("")
		direcciones.append("")
		misiones.append(i)
		killLuz.append(0)
		killSombra.append(0)
	misiones.shuffle()
	CambioTurno("")
	# abrir informacion del INI
	var config = ConfigFile.new()
	var err = config.load("user://config_juegovidahippie.cfg")
	if err == OK:
		esMaster = config.get_value("config", "esMaster", true)
		miIP = config.get_value("config", "miIP", "")
		serverIP = config.get_value("config", "serverIP", "")
		var nn
		for n in range(6):
			nn = config.get_value("jugadores", "j" + str(n + 1), "")
			jugadores[n] = nn
			nn = config.get_value("jugadores", "d" + str(n + 1), "")
			direcciones[n] = nn
	# comenzar el primer turno
	ActualizaDatos()
	if esMaster:
		for i in range(6):
			if jugadores[i] != "":
				turnos.append(i)
		turnos.shuffle()
		$Turnito.start()
		ActualizacionUDP()

# ciclo principal: mover mouse y entradas de comandos

func _process(delta):
	$Mouse.position = get_global_mouse_position()
	if Input.is_action_just_pressed("act_mouse_left"):
		if !enGUI and MiTurno():
			for hex in items:
				if hex.GetFoco():
					if esMaster:
						Accion(hex, seleccion, $Camara/GUI/Turno/TxtTurno.text)
					else:
						Raiz.socketUDP.set_dest_address(serverIP, Raiz.UDPport)
						# ID, 4, hexagono ind, seleccion, nombre
						var txt = str(Raiz.UDPport) + ",4,"
						for h in range(items.size()):
							if items[h] == hex:
								txt += str(h) + ","
								break
						txt += str(seleccion) + "," + $Camara/GUI/Turno/TxtTurno.text
						Raiz.socketUDP.put_packet(txt.to_utf8_buffer())
					break
	elif Input.is_action_just_released("act_mouse_up"):
		$Camara.zoom *= 1.1
		$Camara.zoom = $Camara.zoom.clamp(Vector2(0.25, 0.25), Vector2(1.5, 1.5))
		$Camara/GUI.scale = Vector2(1.0 / $Camara.zoom.x, 1.0 / $Camara.zoom.y)
	elif Input.is_action_just_released("act_mouse_down"):
		$Camara.zoom *= 0.9
		$Camara.zoom = $Camara.zoom.clamp(Vector2(0.25, 0.25), Vector2(1.5, 1.5))
		$Camara/GUI.scale = Vector2(1.0 / $Camara.zoom.x, 1.0 / $Camara.zoom.y)
	elif Input.is_action_just_released("act_mouse_right"):
		posClic = Vector2(0, 0)
	elif Input.is_action_just_pressed("act_mouse_right"):
		posClic = $Mouse.position
	elif posClic.x != 0 and posClic.y != 0:
		$Camara.position += posClic - $Mouse.position
	# movimiento de camara con botones
	if $Camara/GUI/Mover/ButUp.button_pressed:
		$Camara.position.y -= CAM_SPEED * delta
	elif $Camara/GUI/Mover/ButDown.button_pressed:
		$Camara.position.y += CAM_SPEED * delta
	if $Camara/GUI/Mover/ButLeft.button_pressed:
		$Camara.position.x -= CAM_SPEED * delta
	elif $Camara/GUI/Mover/ButRight.button_pressed:
		$Camara.position.x += CAM_SPEED * delta
	# manejar mensajes UDP
	while Raiz.socketUDP.get_available_packet_count() > 0:
		var data = Raiz.socketUDP.get_packet()
		RecepcionUDP(data.get_string_from_utf8())

func RecepcionUDP(data):
	if data.count(",") >= 1:
		var pack = data.split(",")
		if pack[0] == str(Raiz.UDPport):
			match int(pack[1]):
				3: # actualizacion
					var pk = 2
					for i in range(6):
						jugadores[i] = pack[pk]
						if pack[pk + 1] == miIP:
							direcciones[i] = ""
						else:
							direcciones[i] = serverIP
						misiones[i] = int(pack[pk + 2])
						killLuz[i] = int(pack[pk + 3])
						killSombra[i] = int(pack[pk + 4])
						pk += 5
					fichas[SOMBRA] = int(pack[pk])
					fichas[LUZ] = int(pack[pk + 1])
					var txt = pack[pk + 2]
					for h in range(items.size()):
						items[h].CambioTipo(int(txt[h]))
					if $Camara/GUI/Turno/TxtTurno.text != pack[pk + 3]:
						CambioTurno(pack[pk + 3])
				4: # comando: ID, 4, hexagono ind, seleccion, nombre
					Accion(items[int(pack[2])], int(pack[3]), pack[4])
				5: # resultados del juego
					if !$Camara/GUI/Resultados.visible:
						$Camara/GUI/Resultados.visible = true
						$Camara/GUI/Resultados/Texto.text = pack[2]
						$SndFin.play()

func ActualizacionUDP():
	# crear tira de datos
	var txt = str(Raiz.UDPport) + ",3"
	for i in range(6):
		txt += "," + jugadores[i] + "," + direcciones[i] + "," + str(misiones[i])
		txt += "," + str(killLuz[i]) + "," + str(killSombra[i])
	txt += "," + str(fichas[SOMBRA]) + "," + str(fichas[LUZ]) + ","
	for hex in items:
		txt += str(hex.GetTipo())
	txt += "," + $Camara/GUI/Turno/TxtTurno.text
	# enviar los datos a todos
	for i in range(6):
		if direcciones[i] != "":
			Raiz.socketUDP.set_dest_address(direcciones[i], Raiz.UDPport)
			Raiz.socketUDP.put_packet(txt.to_utf8_buffer())
	# ejecutar el reloj de emergencia
	$Watchdog.start()

func Accion(hex, sel, nombre):
	if $Camara/GUI/Turno/TxtTurno.text != nombre:
		return null
	if (sel == SOMBRA and fichas[SOMBRA] > 0) or (sel == LUZ and fichas[LUZ] > 0):
		var res = hex.Accion(sel)
		# devuelve VACIO si falla, sino LUZ o SOMBRA independiente de muerte o vida
		if res != VACIO:
			fichas[sel] -= 1
			Comprobacion(hex, sel, nombre)
	elif sel == VACIO:
		var res = hex.Accion(sel)
		# devuelve VACIO si falla, sino LUZ o SOMBRA independiente de muerte o vida
		if res != VACIO:
			for i in range(6):
				if jugadores[i] == nombre:
					if res == SOMBRA:
						killSombra[i] += 1
					else:
						killLuz[i] += 1
					Comprobacion(hex, sel, nombre)
					break

func NewTurno():
	$Camara/GUI/Turno/TxtTurno.text = ""
	ActualizaDatos()
	OcultaMisiones()
	$Turnito.start()
	ActualizacionUDP()

func _on_turnito_timeout():
	CambioTurno(jugadores[turnos[turno]])
	# mover el contador de turno
	turno += 1
	if turno >= turnos.size():
		turno = 0

func CambioTurno(nombre):
	$Camara/GUI/Turno/TxtTurno.text = nombre
	if nombre != "":
		$SndTurno.play()
	ActualizaSeleccion(VACIO)
	ActualizaDatos()
	OcultaMisiones()
	$Mouse.monitoring = MiTurno()
	if esMaster:
		ActualizacionUDP()

func MiTurno():
	var nn = $Camara/GUI/Turno/TxtTurno.text
	for i in range(6):
		if jugadores[i] == nn and direcciones[i] == "" and nn != "":
			return true
	return false

# ver si gano el juego o continua

func Comprobacion(hex, sel, nombre):
	# verificar si poniendo o quitando ficha gana
	var fin = false
	for i in range(jugadores.size()):
		if jugadores[i] == nombre:
			match misiones[i]:
				0: # Luz
					if FichasDeMas(LUZ):
						if resultados != "":
							resultados += "\n"
						resultados += "Luz por " + nombre
						fin = true
				1: # Sombra
					if FichasDeMas(SOMBRA):
						if resultados != "":
							resultados += "\n"
						resultados += "Sombra por " + nombre
						fin = true
				2: # Conexion
					for it in items:
						if it.IsVacio():
							continue
						if it.FormaAro():
							if resultados != "":
								resultados += "\n"
							resultados += "Conexión Aro por " + nombre
							fin = true
							break
						if it.FormaLinea(misionConexion):
							if resultados != "":
								resultados += "\n"
							resultados += "Conexión Línea por " + nombre
							fin = true
							break
				3: # L. Diversa
					for it in items:
						if it.IsVacio():
							continue
						if it.FormaLinea(misionLDiversa, true):
							if resultados != "":
								resultados += "\n"
							resultados += "L. Diversa por " + nombre
							fin = true
							break
				5: # Muerte
					if sel == VACIO:
						if Destructor(nombre):
							if resultados != "":
								resultados += "\n"
							resultados += "Muerte por " + nombre
							fin = true
			break
	# verificar si ha acabado el juego
	if fin or GameOver():
		# verificar si ganan por equilibrio
		var eq = Equilibrio()
		match eq:
			LUZ:
				for i in range(jugadores.size()):
					if jugadores[i] != "" and misiones[i] == 0:
						if resultados != "":
							resultados += "\n"
						resultados += "Luz por " + jugadores[i]
						break
			SOMBRA:
				for i in range(jugadores.size()):
					if jugadores[i] != "" and misiones[i] == 1:
						if resultados != "":
							resultados += "\n"
						resultados += "Sombra por " + jugadores[i]
						break
			VACIO:
				var suma = FichasTotales()
				if suma[LUZ] + suma[SOMBRA] > 0:
					for i in range(jugadores.size()):
						if jugadores[i] != "" and misiones[i] == 4:
							if resultados != "":
								resultados += "\n"
							resultados += "Equilibrio por " + jugadores[i]
							break
		# mostrar resultados
		$Camara/GUI/Resultados.visible = true
		$Camara/GUI/Resultados/Texto.text = resultados
		$Camara/GUI/Turno/TxtTurno.text = ""
		$SndFin.play()
		ActualizaDatos()
		OcultaMisiones()
		ActualizacionUDP()
		ResultadosUDP()
	else:
		NewTurno()

func ResultadosUDP():
	var txt = str(Raiz.UDPport) + ",5," + resultados
	for i in range(6):
		if direcciones[i] != "":
			Raiz.socketUDP.set_dest_address(direcciones[i], Raiz.UDPport)
			Raiz.socketUDP.put_packet(txt.to_utf8_buffer())

func GameOver():
	# verificar si se acabaron las fichas
	if fichas[LUZ] <= 0 and fichas[SOMBRA] <= 0:
		return true
	# verificar si no se pueden poner o quitar fichas
	var fin = true
	for hex in items:
		if hex.GetTipo() == VACIO:
			if hex.GetVida():
				fin = false
				break
		else:
			if !hex.GetVida():
				fin = false
				break
	return fin

func FichasTotales():
	var suma = [0, 0, 0]
	for hex in items:
		if hex.GetTipo() != VACIO:
			suma[hex.GetTipo()] += 1
	return suma

func FichasDeMas(elTipo):
	var suma = FichasTotales()
	if elTipo == SOMBRA:
		return suma[SOMBRA] - suma[LUZ] >= misionLuzSombra
	elif elTipo == LUZ:
		return suma[LUZ] - suma[SOMBRA] >= misionLuzSombra
	return false

func Equilibrio():
	var suma = FichasTotales()
	if suma[LUZ] < suma[SOMBRA]:
		return SOMBRA
	elif suma[LUZ] > suma[SOMBRA]:
		return LUZ
	else:
		return VACIO

func Destructor(nombre):
	for i in range(jugadores.size()):
		if jugadores[i] == nombre:
			if killLuz[i] >= misionMuerte and killSombra[i] >= misionMuerte:
				return true
			break
	return false

# seleccion con movimiento de mouse

func _on_mouse_area_entered(area):
	if area.name == "GUI":
		enGUI = true
	else:
		area.CambioFoco(true, seleccion)

func _on_mouse_area_exited(area):
	if area.name == "GUI":
		enGUI = false
	else:
		area.CambioFoco(false)

# cambio de seleccion con botones

func ActualizaSeleccion(newSel):
	seleccion = newSel
	if seleccion != VACIO:
		$Camara/GUI/Acciones/SelVacio.button_pressed = false
	if seleccion != SOMBRA:
		$Camara/GUI/Acciones/SelSombra.button_pressed = false
	if seleccion != LUZ:
		$Camara/GUI/Acciones/SelLuz.button_pressed = false

func _on_sel_vacio_button_down():
	ActualizaSeleccion(VACIO)

func _on_sel_sombra_button_down():
	ActualizaSeleccion(SOMBRA)

func _on_sel_luz_button_down():
	ActualizaSeleccion(LUZ)

# salir y volver al menu principal

func _on_but_menu_button_down():
	var menu = load("res://Scenes/Menu.tscn")
	var aux = menu.instantiate()
	get_node("/root/Game").add_child.call_deferred(aux)
	aux.Raiz = get_node("/root/Game")
	queue_free()

# ver las misiones y datos

func _on_but_ver_toggled(button_pressed):
	if button_pressed:
		var nn = $Camara/GUI/Turno/TxtTurno.text
		var aux
		for i in range(6):
			if jugadores[i] == nn:
				if direcciones[i] == "" and nn != "":
					aux = get_node("Camara/GUI/Mision/M" + str(misiones[i] + 1))
					aux.visible = true
					$Camara/GUI/Mision/Fondo.visible = true
				break
	else:
		OcultaMisiones()

func OcultaMisiones():
	var aux
	for i in range(6):
		aux = get_node("Camara/GUI/Mision/M" + str(i + 1))
		aux.visible = false
	$Camara/GUI/Mision/ButVer.button_pressed = false
	$Camara/GUI/Mision/Fondo.visible = false

func ActualizaDatos():
	$Camara/GUI/Estadisticas/TxtLuzTot.text = str(fichas[LUZ])
	$Camara/GUI/Estadisticas/TxtSombraTot.text = str(fichas[SOMBRA])
	var nn = $Camara/GUI/Turno/TxtTurno.text
	if nn == "":
		$Camara/GUI/Estadisticas/TxtLuzKill.text = ""
		$Camara/GUI/Estadisticas/TxtSombraKill.text = ""
	else:
		for i in range(6):
			if jugadores[i] == nn:
				$Camara/GUI/Estadisticas/TxtLuzKill.text = str(killLuz[i])
				$Camara/GUI/Estadisticas/TxtSombraKill.text = str(killSombra[i])
				break
	var suma = FichasTotales()
	$Camara/GUI/Estadisticas/TxtLuzPuesta.text = str(suma[LUZ])
	$Camara/GUI/Estadisticas/TxtSombraPuesta.text = str(suma[SOMBRA])

func _on_watchdog_timeout():
	ActualizacionUDP()
	if resultados != "":
		ResultadosUDP()

func _on_but_zoom_in_pressed() -> void:
	$Camara.zoom *= 1.1
	$Camara.zoom = $Camara.zoom.clamp(Vector2(0.25, 0.25), Vector2(1.5, 1.5))
	$Camara/GUI.scale = Vector2(1.0 / $Camara.zoom.x, 1.0 / $Camara.zoom.y)

func _on_but_zoom_out_pressed() -> void:
	$Camara.zoom *= 0.9
	$Camara.zoom = $Camara.zoom.clamp(Vector2(0.25, 0.25), Vector2(1.5, 1.5))
	$Camara/GUI.scale = Vector2(1.0 / $Camara.zoom.x, 1.0 / $Camara.zoom.y)
