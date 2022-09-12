/// obj_NetworkManager : Init

// Networking variables
timeout = 5;				// in seconds
pingFrequency = 2;			// in seconds
bufferDefaultSize = 32;		// in bytes
bufferInt = buffer_s32;
bufferFloat = buffer_f32;


// ===== Network Functions =====

type = 0; // 0 (None), 1 (Host), 2 (Client)

create_server = function(_port, _maxClients)
{
	if (type == 0)
	{
		type = 1;
		port = _port;
		maxClients = _maxClients;
		server = network_create_server(network_socket_tcp, port, maxClients);
		clientList = ds_list_create();
		recoverableInstances = ds_list_create();
		return true;
	}
	return false;
}

close_server = function()
{
	if (type == 1)
	{
		type = 0;
		network_destroy(server);
		if (ds_exists(clientList, ds_type_list)) ds_list_destroy(clientList);
		return true;
	}
	return false;
}

join_server = function(_ip, _port)
{
	if (type == 0)
	{
		network_set_config(network_config_connect_timeout, timeout * 1000);
		
		type = 2;
		client = network_create_socket(network_socket_tcp);
		var connect = network_connect(client, _ip, _port);
		if (connect < 0)
		{
			type = 0;
			return false;
		}
		idList = ds_list_create();
		idListCleanTimer = room_speed;
		ping = -1;
		pingTimer = pingFrequency * room_speed;
		return true;
	}
	return false;
}

leave_server = function()
{
	if (type == 2)
	{
		type = 0;
		network_destroy(client);
		if (ds_exists(idList, ds_type_list)) ds_list_destroy(idList);
		return true;
	}
	return false;
}

is_connected = function()
{
	if (type > 0) return true;
	else return false;
}

is_host = function()
{
	if (type == 1) return true;
	else return false;
}

is_client = function()
{
	if (type == 2) return true;
	else return false;
}

get_client_count = function()
{
	if (type == 1) return ds_list_size(clientList);
	return -1;
}

send_ping = function()
{
	if (type == 2)
	{
		var buffer = buffer_create(1, buffer_grow, 1);
		buffer_seek(buffer, buffer_seek_start, 0);
		buffer_write(buffer, buffer_u8, 30);			// packet ID
		network_send_packet(client, buffer, buffer_get_size(buffer));
		buffer_delete(buffer);
		return true;
	}
	return false;
}

get_ping = function()
{
	if (type == 2) return ping;
	return -1;
}

instance_create_network = function(_x, _y, _obj)
{
	if (type > 0)
	{
		var inst = instance_create_depth(_x, _y, 0, _obj);
		
		var buffer = buffer_create(20, buffer_grow, 1);
		buffer_seek(buffer, buffer_seek_start, 0);
		buffer_write(buffer, buffer_u8, 10);			// packet ID
		buffer_write(buffer, buffer_s32, _x);			// x
		buffer_write(buffer, buffer_s32, _y);			// y
		buffer_write(buffer, buffer_s32, _obj);			// object
		buffer_write(buffer, buffer_s32, inst);			// instance
		if (type == 1)
		{
			for (var i = 0; i < ds_list_size(clientList); i++) network_send_packet(clientList[| i], buffer, buffer_get_size(buffer));
		}
		else if (type == 2) network_send_packet(client, buffer, buffer_get_size(buffer));
		buffer_delete(buffer);
		
		return inst;
	}
	return false;
}

//instance_create_network_recoverable = function(_id, clientSocket)
//{
//	if (type == 1)
//	{	
//		var buffer = buffer_create(20, buffer_grow, 1);
//		buffer_seek(buffer, buffer_seek_start, 0);
//		buffer_write(buffer, buffer_u8, 10);					// packet ID
//		buffer_write(buffer, buffer_s32, _id.x);				// x
//		buffer_write(buffer, buffer_s32, _id.y);				// y
//		buffer_write(buffer, buffer_s32, _id.object_index);		// object
//		buffer_write(buffer, buffer_s32, _id);					// instance
		
//		network_send_packet(clientSocket, buffer, buffer_get_size(buffer));
//		buffer_delete(buffer);
		
//		return true;
//	}
//	return false;
//}

instance_sync_variables = function(_id)
{
	if (type > 0)
	{
		var args = [];
		
		// Permit a single array containing all the variable names to be used instead
		if (argument_count == 2 and typeof(argument[1]) == "array") args = argument[1];
		else { for (var i = 1; i < argument_count; i++) args[i - 1] = argument[i]; }
		
		// Store all variable types in a string
		// Additionally, create a new array without invalid variables
		var type_string = "";
		var _vars = [];
		for (var i = 0; i < array_length(args); i++)
		{
			var var_name = args[i];
			if (variable_instance_exists(_id, var_name))
			{
				var val = variable_instance_get(_id, var_name);
				
				if (typeof(val) == "bool") type_string += "b";
				else if (typeof(val) == "string") type_string += "s";
				else if (abs(frac(val)) > 0) type_string += "f";
				else if (typeof(val) == "number" or typeof(val) == "int32" or typeof(val) == "int64") type_string += "i";
				else type_string += "?";
				
				_vars[array_length(_vars)] = [var_name, val];
			}
		}
		
		// Convert local ID to host ID (if client)
		if (type == 2) _id = instance_local_to_host(_id);
		
		// Create buffer and write instance ID and type_string to it
		var buffer = buffer_create(bufferDefaultSize, buffer_grow, 1);
		buffer_seek(buffer, buffer_seek_start, 0);
		buffer_write(buffer, buffer_u8, 20);	// packet ID
		buffer_write(buffer, buffer_s32, _id);
		buffer_write(buffer, buffer_string, type_string);
	
		// Write all variable names and values to the buffer
		for (var i = 0; i < array_length(_vars); i++)
		{
			buffer_write(buffer, buffer_string, _vars[i][0]);					// Variable name
			
			var val = _vars[i][1];
			var val_type = string_copy(type_string, i + 1, 1);
			
			if (val_type == "b") buffer_write(buffer, buffer_bool, val);		// Boolean
			else if (val_type == "s") buffer_write(buffer, buffer_string, val);	// String
			else if (val_type == "i") buffer_write(buffer, bufferInt, val);		// Integer
			else if (val_type == "f") buffer_write(buffer, bufferFloat, val);	// Float
		}
	
		if (type == 1)
		{
			for (var i = 0; i < ds_list_size(clientList); i++) network_send_packet(clientList[| i], buffer, buffer_get_size(buffer));
		}
		else if (type == 2) network_send_packet(client, buffer, buffer_get_size(buffer));
		buffer_delete(buffer);
		return true;
	}
	return false;
}

//instance_set_recoverable = function(_id)
//{
//	var mark = true;
//	if (argument_count >= 2 and argument[1] == false) mark = false;
	
//	if (type == 1)
//	{
//		var pos = ds_list_find_value(recoverableInstances, _id);
//		if (mark)
//		{
//			if (is_undefined(pos)) ds_list_add(recoverableInstances, _id);
//		}
//		else
//		{
//			if (!is_undefined(pos)) ds_list_delete(recoverableInstances, pos);
//		}
//		return true;
//	}
//	else if (type == 2)
//	{
//		_id = instance_local_to_host(_id);
			
//		// Send mark request to host
//		var buffer = buffer_create(10, buffer_grow, 1);
//		buffer_seek(buffer, buffer_seek_start, 0);
//		buffer_write(buffer, buffer_u8, 50);	// packet ID
//		buffer_write(buffer, buffer_s32, _id);
//		buffer_write(buffer, buffer_bool, mark);
		
//		return true;
//	}
//	return false;
//}

instance_host_to_local = function(_id)	// Used by instance_sync_variables()
{
	if (type == 2)
	{
		var __id = -1;
		for (var i = 0; i < ds_list_size(idList); i++)
		{
			if (idList[| i][0] == _id)
			{
				__id = idList[| i][1];
				break;
			}
		}
		return __id;
	}
	return -1;
}

instance_local_to_host = function(_id)	// Used by instance_sync_variables()
{
	if (type == 2)
	{
		var __id = -1;
		for (var i = 0; i < ds_list_size(idList); i++)
		{
			if (idList[| i][1] == _id)
			{
				__id = idList[| i][0];
				break;
			}
		}
		return __id;
	}
	return -1;
}

set_flag = function(flag, value)
{
	if (type > 0)
	{
		variable_instance_set(id, flag, value);
		
		var _type = "";
		if (typeof(value) == "bool") _type = "b";
		else if (typeof(value) == "string") _type = "s";
		else if (abs(frac(value)) > 0) _type = "f";
		else if (typeof(value) == "number" or typeof(value) == "int32" or typeof(value) == "int64") _type = "i";
		
		// Create buffer and write type and flag name to it
		var buffer = buffer_create(bufferDefaultSize, buffer_grow, 1);
		buffer_seek(buffer, buffer_seek_start, 0);
		buffer_write(buffer, buffer_u8, 40);	// packet ID
		buffer_write(buffer, buffer_string, _type);
		buffer_write(buffer, buffer_string, flag);
		
		// Write the value to the buffer
		if (_type == "b") buffer_write(buffer, buffer_bool, value);			// Boolean
		else if (_type == "s") buffer_write(buffer, buffer_string, value);	// String
		else if (_type == "i") buffer_write(buffer, bufferInt, value);		// Integer
		else if (_type == "f") buffer_write(buffer, bufferFloat, value);	// Float
	
		if (type == 1)
		{
			for (var i = 0; i < ds_list_size(clientList); i++) network_send_packet(clientList[| i], buffer, buffer_get_size(buffer));
		}
		else if (type == 2) network_send_packet(client, buffer, buffer_get_size(buffer));
		buffer_delete(buffer);
		return true;
	}
	return false;
}

set_flag_local = function(flag, value)
{
	if (type > 0)
	{
		variable_instance_set(id, flag, value);
		return true;
	}
	return false;
}

read_flag = function(flag)
{
	if (type > 0)
	{
		if (variable_instance_exists(id, flag)) return variable_instance_get(id, flag);
		return -1;
	}
	return -1;
}