/// obj_NetworkManager : Init

// Modifiable values
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
		return true;
	}
	return false;
}

destroy_server = function()
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
		ping = "...";
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
		return true;
	}
	return false;
}

instance_sync_variables = function(_id)
{
	if (type > 0)
	{
		// Store all variable types in a string
		// Additionally, create a new array without invalid variables
		var type_string = "";
		var _vars = [];
		for (var i = 1; i < argument_count; i++)
		{
			var var_name = argument[i];
			if (variable_instance_exists(_id, var_name))
			{
				var val = variable_instance_get(_id, var_name);
				
				if (typeof(val) == "string") type_string += "s";
				else if (frac(val) > 0) type_string += "f";
				else if (typeof(val) == "number" or typeof(val) == "int32") type_string += "i";
				
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
			
			if (val_type == "s") buffer_write(buffer, buffer_string, val);		// String
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

instance_host_to_local = function(_id)
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

instance_local_to_host = function(_id)
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