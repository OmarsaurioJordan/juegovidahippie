extends Node2D

# constantes manipulables
const misionLuzSombra = 4
const misionConexion = 5
const misionLDiversa = 6
const misionMuerte = 4
const totalFichas = 19

# variables de funcionamiento
var direcciones = [] # listado de IP del jugador
var verMision = 0
var Raiz

func _ready():
	randomize()
	PintaHexagonos()
	for i in range(6):
		direcciones.append("")
	# abrir informacion del INI
	var config = ConfigFile.new()
	var err = config.load("user://config_juegovidahippie.cfg")
	if err == OK:
		$Cliente/IP.text = config.get_value("config", "serverIP", "")
		var nn
		for n in range(6):
			nn = config.get_value("jugadores", "j" + str(n + 1), "")
			get_node("Jugadores/P" + str(n + 1)).text = nn
	# informacion de misiones
	JuntaMisiones()
	verMision = randi_range(0, 5)
	get_node("Mision/M" + str(verMision + 1)).visible = true

func PintaHexagonos():
	for hex in $Hexagonos.get_children():
		hex.AleatorioEstetico()

func _process(_delta):
	while Raiz.socketUDP.get_available_packet_count() > 0:
		var data = Raiz.socketUDP.get_packet()
		var ip = Raiz.socketUDP.get_packet_ip()
		RecepcionUDP(ip, data.get_string_from_utf8())

func RecepcionUDP(ip, data):
	if data.count(",") >= 1:
		var pack = data.split(",")
		if pack[0] == str(Raiz.UDPport):
			match int(pack[1]):
				0: # c conecteme
					var nn
					var ok = true
					for i in range(6):
						nn = get_node("Jugadores/P" + str(i + 1)).text
						if nn != "" and pack[2 + i] != "":
							ok = false
							break
						elif nn == "" and pack[2 + i] != "":
							for n in range(6):
								nn = get_node("Jugadores/P" + str(n + 1)).text
								if nn == pack[2 + i]:
									ok = false
									break
							if !ok:
								break
					if ok:
						# poner cosas en su lugar
						for i in range(6):
							if pack[2 + i] != "":
								get_node("Jugadores/P" + str(i + 1)).text = pack[2 + i]
								get_node("Jugadores/P" + str(i + 1)).editable = false
								direcciones[i] = ip
						# envio conexion
						Raiz.socketUDP.set_dest_address(ip, Raiz.UDPport)
						var txt = str(Raiz.UDPport) + ",1," + ip
						Raiz.socketUDP.put_packet(txt.to_utf8_buffer())
					else:
						Raiz.socketUDP.set_dest_address(ip, Raiz.UDPport)
						var txt = str(Raiz.UDPport) + ",2"
						Raiz.socketUDP.put_packet(txt.to_utf8_buffer())
				1: # s conectado
					var config = ConfigFile.new()
					config.set_value("config", "esMaster", false)
					config.set_value("config", "miIP", pack[2])
					config.set_value("config", "serverIP", ip)
					config.save("user://config_juegovidahippie.cfg")
					# saltar al tablero
					var tab = load("res://Scenes/Tablero.tscn")
					var aux = tab.instantiate()
					get_node("/root/Game").add_child.call_deferred(aux)
					aux.Raiz = get_node("/root/Game")
					queue_free()
				2: # s error
					$SndError.play()

func _on_but_conectar_button_down():
	var ok = false
	if $Cliente/IP.text.is_valid_ip_address():
		for i in range(6):
			if get_node("Jugadores/P" + str(i + 1)).text != "":
				ok = true
				break
	if ok:
		# guardar informacion en INI
		var config = ConfigFile.new()
		var nn
		for n in range(6):
			nn = get_node("Jugadores/P" + str(n + 1)).text
			config.set_value("jugadores", "j" + str(n + 1), nn)
		config.set_value("config", "IP", $Cliente/IP.text)
		config.save("user://config_juegovidahippie.cfg")
		# enviar los datos
		Raiz.socketUDP.set_dest_address($Cliente/IP.text, Raiz.UDPport)
		var data = str(Raiz.UDPport) + ",0"
		for i in range(6):
			data += "," + get_node("Jugadores/P" + str(i + 1)).text
		Raiz.socketUDP.put_packet(data.to_utf8_buffer())
		$Cliente/ButConectar.disabled = true
		$Cooldown.start()

func _on_but_jugar_button_down():
	var uno = false
	for i in range(6):
		# verificar que halla almenos dos jugadores
		if get_node("Jugadores/P" + str(i + 1)).text != "":
			if !uno:
				uno = true
				continue
			# guardar informacion en INI
			var config = ConfigFile.new()
			var nn
			for n in range(6):
				nn = get_node("Jugadores/P" + str(n + 1)).text
				config.set_value("jugadores", "j" + str(n + 1), nn)
				config.set_value("jugadores", "d" + str(n + 1), direcciones[n])
			config.set_value("config", "esMaster", true)
			config.save("user://config_juegovidahippie.cfg")
			# saltar al tablero
			var tab = load("res://Scenes/Tablero.tscn")
			var aux = tab.instantiate()
			get_node("/root/Game").add_child.call_deferred(aux)
			aux.Raiz = get_node("/root/Game")
			queue_free()
			break

func _on_cooldown_timeout():
	$Cliente/ButConectar.disabled = false

func _on_but_ver_button_down():
	for i in range(6):
		get_node("Mision/M" + str(i + 1)).visible = false
	verMision += 1
	if verMision > 5:
		verMision = 0
	get_node("Mision/M" + str(verMision + 1)).visible = true

func JuntaMisiones():
	var aux
	for i in range(1, 7):
		aux = get_node("Mision/M" + str(i))
		aux.position = $Mision/M1.position
		aux.visible = false
	$Mision/M1.visible = false
	$Mision/ButVer.button_pressed = false
	# poner valores numericos
	var txt = $Mision/M1/Texto.text
	$Mision/M1/Texto.text = txt.replacen("$", str(misionLuzSombra))
	txt = $Mision/M2/Texto.text
	$Mision/M2/Texto.text = txt.replacen("$", str(misionLuzSombra))
	txt = $Mision/M3/Texto.text
	$Mision/M3/Texto.text = txt.replacen("$", str(misionConexion))
	txt = $Mision/M4/Texto.text
	$Mision/M4/Texto.text = txt.replacen("$", str(misionLDiversa))
	txt = $Mision/M6/Texto.text
	$Mision/M6/Texto.text = txt.replacen("$", str(misionMuerte))
