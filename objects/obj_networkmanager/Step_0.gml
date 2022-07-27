/// obj_NetworkManager : Step

if (type == 2)
{
	// Send ping (disconnect if timed out)
	pingTimer -= 1;
	if (pingTimer == 0) send_ping();
	else if (pingTimer < -timeout * room_speed) leave_server();
	
	// Clear idList of deleted instances
	if (idListCleanTimer > 0) idListCleanTimer -= 1;
	else
	{
		idListCleanTimer = room_speed;
		var i = 0;
		while (i < ds_list_size(idList))
		{
			if (!instance_exists(idList[| i][1])) ds_list_delete(idList, i);
			else i++;
		}
	}
}