extends Node

# constantes de funcionamiento
const UDPport = 1818

# variables de funcionamiento
var socketUDP = PacketPeerUDP.new()

func _ready():
	if socketUDP.bind(UDPport) != OK:
		pass # get_tree().quit() this falls on web export
	$Menu.Raiz = self

func _exit_tree():
	socketUDP.close()
