#include <sourcemod>

new Handle:g_hSQL = INVALID_HANDLE;
new g_iSQLReconnectCounter;
new String:sql_selectMaps[] = "SELECT map FROM mapzones WHERE type = 0 GROUP BY map ORDER BY map;";

public Plugin:myinfo = 
{
	name = "Maplist Helper",
	author = "Zipcore editted by myk",
	description = "Re-writes maplist.txt and mapcycle.txt with valid maps",
	version = "1.0"
}

public OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Check timer error logs.");
		return;
	}
	
	RegAdminCmd("sm_maplist_rewrite", Cmd_Rewrite, ADMFLAG_BAN);
	RegAdminCmd("sm_nav_create", Cmd_NavCreate, ADMFLAG_BAN);
	
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
}

public OnMapStart()
{
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
}

public Action:Cmd_Rewrite(client, args)
{
	ReWriteMaplist(client);
	return Plugin_Handled;
}

public Action:Cmd_NavCreate(client, args)
{
	CreateNavFiles(client);
	return Plugin_Handled;
}

ConnectSQL()
{
	if (g_hSQL != INVALID_HANDLE)
	{
		CloseHandle(g_hSQL);
	}

	g_hSQL = INVALID_HANDLE;

	if (SQL_CheckConfig("shavit"))
	{
		SQL_TConnect(ConnectSQLCallback, "shavit");
	}
	else
	{
		SetFailState("PLUGIN STOPPED - Reason: no config entry found for 'shavit' in databases.cfg - PLUGIN STOPPED");
	}
}

public ConnectSQLCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (g_iSQLReconnectCounter >= 5)
	{
		PrintToServer("PLUGIN STOPPED - Reason: reconnect counter reached max - PLUGIN STOPPED");
		return;
	}
	
	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Connection to SQL database has failed, Reason: %s", error);
		g_iSQLReconnectCounter++;
		ConnectSQL();
		return;
	}
	g_hSQL = CloneHandle(hndl);
	
	g_iSQLReconnectCounter = 1;
}

public ReWriteMaplist(client)
{
	decl String:Query[255];
	Format(Query, 255, sql_selectMaps);
	SQL_TQuery(g_hSQL, SQL_ReWriteMaplistCallback, Query, client);
}

public SQL_ReWriteMaplistCallback(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (hndl == INVALID_HANDLE)
	{
		return;
	}
	
	new iMapCount = 0;
	
	if(SQL_GetRowCount(hndl))
	{
		decl String:path[PLATFORM_MAX_PATH];
		decl String:path2[PLATFORM_MAX_PATH];
		decl String:path3[PLATFORM_MAX_PATH];
		decl String:path4[PLATFORM_MAX_PATH];
		Format(path, sizeof(path), "maplist.txt");
		Format(path2, sizeof(path2), "mapcycle.txt");
		Format(path3, sizeof(path3), "cfg/maplist.txt");
		Format(path4, sizeof(path4), "cfg/mapcycle.txt");
		new Handle:hfile = OpenFile(path, "w");
		new Handle:hfile2 = OpenFile(path2, "w");
		new Handle:hfile3 = OpenFile(path3, "w");
		new Handle:hfile4 = OpenFile(path4, "w");
		
		decl String:sMap[128];
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
			
			decl String:sBuffer[64];
			Format(sBuffer, 64, "maps/%s.bsp", sMap);
			
			if(FileExists(sBuffer))
			{
				WriteFileLine(hfile, sMap);
				WriteFileLine(hfile2, sMap);
				WriteFileLine(hfile3, sMap);
				WriteFileLine(hfile4, sMap);
				iMapCount++;
			}
		}
		
		CloseHandle(hfile);
		CloseHandle(hfile2);
		CloseHandle(hfile3);
		CloseHandle(hfile4);
	}
	
	PrintToChat(client, "New maplist contains %d maps.", iMapCount);
	
	if(GetEngineVersion() == Engine_CSGO)
		PrintToChat(client, "Don't forget to update your gamemodes_server.txt!", iMapCount);
}

public CreateNavFiles(client)
{
	decl String:Query[255];
	Format(Query, 255, sql_selectMaps);
	SQL_TQuery(g_hSQL, SQL_CreateNavFilesCallback, Query, client);
}

public SQL_CreateNavFilesCallback(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (hndl == INVALID_HANDLE)
	{
		return;
	}
	
	new iNavCount = 0;
	
	if(SQL_GetRowCount(hndl))
	{
		decl String:sMap[128];
		decl String:sNav[64];
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
			
			Format(sNav, 64, "maps/%s.nav", sMap);
			if(!FileExists(sNav))
			{
				File_Copy("maps/base.nav", sNav);
			}
		}
	}
	
	PrintToChat(client, "Copied %d missing Nav files", iNavCount);
}

/*
 * Copies file source to destination
 * Based on code of javalia:
 * http://forums.alliedmods.net/showthread.php?t=159895
 *
 * @param source		Input file
 * @param destination	Output file
 */
stock bool:File_Copy(const String:source[], const String:destination[])
{
	new Handle:file_source = OpenFile(source, "rb");

	if (file_source == INVALID_HANDLE) {
		return false;
	}

	new Handle:file_destination = OpenFile(destination, "wb");

	if (file_destination == INVALID_HANDLE) {
		CloseHandle(file_source);
		return false;
	}

	new buffer[32];
	new cache;

	while (!IsEndOfFile(file_source)) {
		cache = ReadFile(file_source, buffer, 32, 1);
		WriteFile(file_destination, buffer, cache, 1);
	}

	CloseHandle(file_source);
	CloseHandle(file_destination);

	return true;
}
