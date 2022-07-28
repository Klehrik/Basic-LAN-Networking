/// obj_NetworkManager : Async

var _type = async_load[? "type"];

switch (_type)
{
	case network_type_connect:
		if (type == 1) ds_list_add(clientList, async_load[? "socket"]);
		break;
		
	
	case network_type_disconnect:
		if (type == 1) ds_list_delete(clientList, ds_list_find_index(clientList, async_load[? "socket"]));
		break;
		
	
	case network_type_data:
		var buffer = async_load[? "buffer"];
		buffer_seek(buffer, buffer_seek_start, 0);
		var packet_id = buffer_read(buffer, buffer_u8);
		
		switch (packet_id)
		{
			case 10:	// instance_create_network - receiving
			
				// Create instance locally
				var _x = buffer_read(buffer, buffer_s32);
				var _y = buffer_read(buffer, buffer_s32);
				var _obj = buffer_read(buffer, buffer_s32);
				var inst = instance_create_depth(_x, _y, 0, _obj);
				
				var _id = buffer_read(buffer, buffer_s32);
				if (type == 1)
				{
					// Send host instance id back to client who created the instance
					// The host's ids are to be treated as the "real" ones, and all clients convert their local ones to host
					var buffer2 = buffer_create(10, buffer_grow, 1);
					buffer_seek(buffer2, buffer_seek_start, 0);
					buffer_write(buffer2, buffer_u8, 11);			// packet ID
					buffer_write(buffer2, buffer_s32, inst);		// instance (host)
					buffer_write(buffer2, buffer_s32, _id);			// instance (client)
					
					var socket = async_load[? "id"];
					network_send_packet(socket, buffer2, buffer_get_size(buffer2));
					buffer_delete(buffer2);
					
					// Resend this packet ID to all other clients
					var buffer2 = buffer_create(20, buffer_grow, 1);
					buffer_seek(buffer2, buffer_seek_start, 0);
					buffer_write(buffer2, buffer_u8, 10);			// packet ID
					buffer_write(buffer2, buffer_s32, _x);			// x
					buffer_write(buffer2, buffer_s32, _y);			// y
					buffer_write(buffer2, buffer_s32, _obj);		// object
					buffer_write(buffer2, buffer_s32, inst);		// instance
					
					for (var i = 0; i < ds_list_size(clientList); i++)
					{
						if (clientList[| i] != socket) network_send_packet(clientList[| i], buffer2, buffer_get_size(buffer2));
					}
					buffer_delete(buffer2);
				}
				else if (type == 2) ds_list_add(idList, [_id, inst]);
				break;
				
				
			case 11:		// instance_create_network - host sending back their instance id
				if (type == 2)
				{
					var hostID = buffer_read(buffer, buffer_s32);
					var clientID = buffer_read(buffer, buffer_s32);
					ds_list_add(idList, [hostID, clientID]);
				}
				break;
				
			
			case 20:		// instance_sync_variables - receiving
				var _id = buffer_read(buffer, buffer_s32);
				var _types = buffer_read(buffer, buffer_string);
				
				if (type == 1)
				{
					var socket = async_load[? "id"];
					for (var i = 0; i < ds_list_size(clientList); i++)
					{
						if (clientList[| i] != socket) network_send_packet(clientList[| i], buffer, buffer_get_size(buffer));
					}
				}
				else if (type == 2) _id = instance_host_to_local(_id);
				
				if (instance_exists(_id))
				{
					// Read all variable values from the buffer
					for (var i = 0; i < string_length(_types); i++)
					{
						var var_name = buffer_read(buffer, buffer_string);					// Variable name
						var val_type = string_copy(_types, i + 1, 1);
							
						var val = 0;
						if (val_type == "b") val = buffer_read(buffer, buffer_bool);		// Boolean
						else if (val_type == "s") val = buffer_read(buffer, buffer_string);	// String
						else if (val_type == "i") val = buffer_read(buffer, bufferInt);		// Integer
						else if (val_type == "f") val = buffer_read(buffer, bufferFloat);	// Float
							
						variable_instance_set(_id, var_name, val);
					}
				}
				break;
				
			
			case 30:		// send_ping - receiving
				if (type == 1)
				{
					var socket = async_load[? "id"];
					network_send_packet(socket, buffer, buffer_get_size(buffer));
				}
				else if (type == 2)
				{
					ping = round(abs(pingTimer) / room_speed * 1000);
					pingTimer = pingFrequency * room_speed;
				}
				break;
				
			
			case 40:		// set_flag - receiving
				if (type == 1)
				{
					var socket = async_load[? "id"];
					for (var i = 0; i < ds_list_size(clientList); i++)
					{
						if (clientList[| i] != socket) network_send_packet(clientList[| i], buffer, buffer_get_size(buffer));
					}
				}
				
				var _type = buffer_read(buffer, buffer_string);
				var flag = buffer_read(buffer, buffer_string);
				
				var value = -1;
				if (_type == "b") value = buffer_read(buffer, buffer_bool);			// Boolean
				else if (_type == "s") value = buffer_read(buffer, buffer_string);	// String
				else if (_type == "i") value = buffer_read(buffer, bufferInt);		// Integer
				else if (_type == "f") value = buffer_read(buffer, bufferFloat);	// Float
							
				variable_instance_set(id, flag, value);
				break;
		}
		break;
}