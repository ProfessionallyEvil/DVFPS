extends Node

var queue = []

signal message_pushed(id)
signal message_popped(id, message)

func push_message(message):
	queue.push_front(message)
	emit_signal("message_pushed")
	
func pop_message():
	var message = queue.pop_back()
	emit_signal("message_popped")
	return message

