#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < fun >
#include < csx >
#include < fakemeta >
#include < hamsandwich >
#include < sqlx >

#define m_iMenuCode 205
#define m_iMenu 205

#define CSMENU_JOINCLASS 3

#define CONNECT_TASK	1024

#define MAX_PLAYERS 32

#define MAX_CLASSES	6
#define MAX_LEVELS	6
#define MAX_PONTUATION	10000 // max skillpoints per player

#define MIN_AFK_TIME 40
#define WARNING_TIME 10
#define CHECK_FREQ 5

new g_bIgnored

#define SetUserIgnored(%1)	( g_bIgnored |=  ( 1 << ( %1 & 31 ) ) )
#define ClearUserIgnored(%1)	( g_bIgnored &= ~( 1 << ( %1 & 31 ) ) )
#define CheckUserIgnored(%1)	( g_bIgnored &   ( 1 << ( %1 & 31 ) ) )

#define IsPlayer(%1)		( 1 <= %1 <= g_iMaxPlayers )

new const STATUS_TABLE[] = 	"server"
new const PREFIX[ ]	=	"[#gather]"
new const SQL_TABLE[ ]	=	"ranking"
new const SQL_GTABLE[ ]	=	"gathers"

new const TagsT[][] = 
{
"LOVE",
"DOGS",
"BEER",
"RED",
"WHITE",
"LOGIC",
"DARK",
"POSITIVE",
"NORTH",
"ORDER",
"WAR",
"LIFE"
};

new const TagsCT[][] = 
{
"HATE",
"CATS",
"VODKA",
"BLUE",
"BLACK",
"EMOTION",
"LIGHT",
"NEGATIVE",
"SOUTH",
"DISORDER",
"PEACE",
"DEATH"
};

new TagsNum

new const CLASSES[ MAX_CLASSES ][ ] = {
"BRONZE",
"SILVER",
"GOLD",
"PLATINUM",
"DIAMOND",
"CHALLENGER"
};

new const LEVELS[ MAX_LEVELS ] = {
1000,
1800,
2500,
3000,
3400,
100000 /* high value (not reachable) */
};

new g_iK
new const g_ChatAdvertise[ ][ ] = {
"%s Write .cmds to see the available commands.",
"%s Follow us at www.youtube.com/piccgamer",
"%s Write .cmds to see the available commands.",
"%s Like us at www.facebook.com/piccgathers",
"%s Join us in teamspeak IP: 37.10.107.10:9988",
"%s Visit our website at www.piccgathers.com"
};

new Trie:g_tIgnoredAuthID // hltv, bots and non-steam users

new g_szAuthID[ MAX_PLAYERS + 1 ][ 35 ]
new g_szName[ MAX_PLAYERS + 1 ][ 32 ]

new Handle:g_SqlTuple

new g_pcvarHost
new g_pcvaruUser
new g_pcvarPass
new g_pcvarDB

new Frags[33], Deaths[33]

new g_iPoints[ MAX_PLAYERS + 1 ]
new g_iPointsGather[ MAX_PLAYERS + 1 ]
new g_szNick[ MAX_PLAYERS + 1 ][32]
new g_iLevels[ MAX_PLAYERS + 1 ]
new g_iClasses[ MAX_PLAYERS + 1 ]
new g_iBanPoints[ MAX_PLAYERS + 1 ]

new g_iKills[ MAX_PLAYERS + 1 ]
new g_iDeaths[ MAX_PLAYERS + 1 ]
new g_iHeadShots[ MAX_PLAYERS + 1 ]
new g_iKnifeKills[ MAX_PLAYERS + 1 ]
new g_iGatherWins[ MAX_PLAYERS + 1 ]
new g_iGatherLosses[ MAX_PLAYERS + 1 ]
new g_iGatherPlayed[ MAX_PLAYERS + 1 ]

new szAddress[32]
new p_Address

new g_TimeBetweenAds

new bool:g_bRoundEnded


new gKillerID[33]

new playersleft
new pug_ini_file[64]

new g_iScore[2]
new g_iStatus=0
new g_iGathersPlayed
new g_iLastTeamScore[2]
new bool:g_bIsReady[33]
new bool:g_bIsLoaded[33]
new g_LeftKills[33]
new g_LeftVotes[33]
new g_iTimeLeft[33]


new bool:g_IsStarted
new bool:g_AfterRdy
new bool:g_MapChanged
new bool:g_Twon
new bool:Stop
new bool:Stop2

new szTeamName[2]
new iTeam
new iScore
new iScoreOffset
new bool:didscore
new bool:secondhalf
new notbalanced
new didwaitenough

new cvar_playersleft

new g_oldangles[33][3]
new g_afktime[33]
new bool:g_spawned[33] = {true, ...};

new gVoteMenu
new gVotes[5]
new maps_ini_file[64]
new mapscounter
new mapsavailable[30][20]
new mapschosen[4][20]
new donemaps
new changemapto

new szMapName[ 32 ]

new g_max_players, g_sync_creat_list

public plugin_init() 
{
register_plugin("piccgathers.com", "2.0", "candy")

cvar_playersleft = register_cvar("pug_players", "10")

register_cvar("afk_version", "1.0b")
register_cvar("mp_afktime", "40.0")  // Kick people AFK longer than this time
register_cvar("mp_afkminplayers", "8")  // Only kick AFKs when there is atleast this many players on the server
set_task(float(CHECK_FREQ),"checkPlayers",_,_,_,"b")
register_event("ResetHUD", "playerSpawned", "be")

playersleft = get_pcvar_num(cvar_playersleft)

get_configsdir(pug_ini_file, 63)
format(pug_ini_file, 63, "%s/pug.ini", pug_ini_file)

register_clcmd("say", "cmdSay")
register_clcmd("say_team", "cmdSay")

register_clcmd("chooseteam", "handled")
register_clcmd("jointeam", "handled")
register_clcmd(".score", "showscore")
register_clcmd("!score", "showscore")
register_event("TeamScore", "Event_TeamScore", "a")

register_event( "DeathMsg", "Event_DeathMsg", "a" )
register_clcmd( ".hp", "cmdGetInfo" )
register_clcmd( "!hp", "cmdGetInfo" )

register_forward(FM_GetGameDescription, "Change" )

register_clcmd( ".skillpoints", "ShowPoints" )
register_clcmd( "!skillpoints", "ShowPoints" )

register_clcmd( ".sk", "ShowPoints" )
register_clcmd( "!sk", "ShowPoints" )

register_clcmd( ".sp", "ShowPoints" )
register_clcmd( "!sp", "ShowPoints" )

register_clcmd( ".banpoints", "ShowBanPoints" )
register_clcmd( "!banpoints", "ShowBanPoints" )

register_clcmd( ".bp", "ShowBanPoints" )
register_clcmd( "!bp", "ShowBanPoints" )

register_clcmd( ".gp", "ShowGathersPlayed" )
register_clcmd( "!gp", "ShowGathersPlayed" )

register_clcmd( ".cmds", "cmds" )
register_clcmd( "!cmds", "cmds" )

register_clcmd(".rr", "cmdRestart")
register_clcmd("!rr", "cmdRestart")

register_clcmd(".live", "cmdLive")
register_clcmd("!live", "cmdLive")

register_clcmd(".end", "cmdEnd")
register_clcmd("!end", "cmdEnd")

register_clcmd(".servers", "cmdServers")
register_clcmd("!servers", "cmdServers")

RegisterHam( Ham_Spawn, "player", "FwdPlayerSpawnPost", 1 )

register_clcmd( "joinclass", "ClCmd_joinclass" )
register_clcmd( "menuselect", "ClCmd_joinclass" ) // for old style text menu 

register_event( "SendAudio", "TerroristsWin", "a", "2&%!MRAD_terwin" )
register_event( "SendAudio", "CounterTerroristsWin", "a", "2&%!MRAD_ctwin" )

register_event( "HLTV", "EventNewRound", "a", "1=0", "2=0" )
register_logevent( "EventRoundEnd", 2, "1=Round_End" )

g_max_players = get_maxplayers()
g_sync_creat_list = CreateHudSyncObj()

p_Address = get_cvar_pointer("net_address")

TagsNum = random_num(0,10)

set_task(2.0, "warmupcfg")

g_tIgnoredAuthID = TrieCreate( )
TrieSetCell( g_tIgnoredAuthID, "VALVE_ID_LAN", 1 )
TrieSetCell( g_tIgnoredAuthID, "VALVE_ID_PENDING", 1 )
TrieSetCell( g_tIgnoredAuthID, "STEAM_ID_LAN", 1 )
TrieSetCell( g_tIgnoredAuthID, "STEAM_ID_PENDING", 1 )
TrieSetCell( g_tIgnoredAuthID, "BOT", 1 )
TrieSetCell( g_tIgnoredAuthID, "HLTV", 1 )

RegisterCvars( )
SqlInit( )
}

public plugin_precache()
{
set_cvar_string("humans_join_team", "")
get_configsdir(pug_ini_file, 63);
format(pug_ini_file, 63, "%s/pug.ini", pug_ini_file);

if (!file_exists(pug_ini_file))
{
client_print(0, print_chat, "%s ERROR! Pug.ini file not found.", PREFIX)
return PLUGIN_HANDLED
}

if (get_pug_state() == 0) { 
return PLUGIN_HANDLED
}

else if (get_pug_state() == 1)
{
g_MapChanged = true
set_task(30.0, "RandomTeams")
return PLUGIN_CONTINUE
}
else if (get_pug_state() == 2) { 
set_pug_state(0)
return PLUGIN_CONTINUE
}

return PLUGIN_CONTINUE
}

public warmupcfg()
{
server_cmd("mp_friendlyfire 0")
server_cmd("mp_freezetime 0")
server_cmd("mp_startmoney 16000")
}

public RegisterCvars( )
{
g_TimeBetweenAds = register_cvar( "gthr_time", "120.0" )	
g_pcvarHost = register_cvar( "gthr_sql_host", "37.59.3.175", FCVAR_PROTECTED )
g_pcvaruUser = register_cvar( "gthr_sql_user", "joserodr_gthpicc", FCVAR_PROTECTED )
g_pcvarPass = register_cvar( "gthr_sql_pass", "qwertypiccgathers1320", FCVAR_PROTECTED )
g_pcvarDB = register_cvar( "gthr_sql_db", "joserodr_piccgtr", FCVAR_PROTECTED )

set_task( get_pcvar_float( g_TimeBetweenAds ), "ChatAdvertisements", _, _, _, "b" )
}

public SqlInit( )
{
new szHost[ 32 ]
new szUser[ 32 ]
new szPass[ 32 ]
new szDB[ 32 ]

get_pcvar_string( g_pcvarHost, szHost, charsmax( szHost ) )
get_pcvar_string( g_pcvaruUser, szUser, charsmax( szUser ) )
get_pcvar_string( g_pcvarPass, szPass, charsmax( szPass ) )
get_pcvar_string( g_pcvarDB, szDB, charsmax( szDB ) )

g_SqlTuple = SQL_MakeDbTuple( szHost, szUser, szPass, szDB )

new g_Error[ 512 ]
new ErrorCode
new Handle:SqlConnection = SQL_Connect( g_SqlTuple, ErrorCode, g_Error, charsmax( g_Error ) )
log_amx("SQL Initialized...")

if( SqlConnection == Empty_Handle )
{
set_fail_state( g_Error )
}

set_task(2.0, "LoadGathersPlayed")

SQL_FreeHandle( SqlConnection )
}

public UpdateStatus()
{
get_pcvar_string(p_Address,szAddress,charsmax(szAddress))

new szTemp[ 512 ]
formatex( szTemp, charsmax( szTemp ),
"UPDATE `%s` SET `score_T`='%d', `score_CT`='%d', `status`='%d', `gathers`='%d' WHERE `ip`='%s'",
STATUS_TABLE, g_iScore[0], g_iScore[1], g_iStatus, g_iGathersPlayed, szAddress )

SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )
}

public UpdateBanPoints(id)
{
new szTemp[ 512 ]
formatex( szTemp, charsmax( szTemp ),
"UPDATE `%s` SET `banpoints`='%d' WHERE `steamid`='%s'",
SQL_TABLE, g_iBanPoints[ id ], g_szAuthID[ id ] )

SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )	
}

public plugin_end( )
{
TrieDestroy( g_tIgnoredAuthID )
SQL_FreeHandle( g_SqlTuple )
}

public client_authorized( id )
{
set_task( 4.0, "Delayed_client_authorized", id + CONNECT_TASK )	
}

public Delayed_client_authorized( id )
{	
id -= CONNECT_TASK

get_user_authid( id , g_szAuthID[ id ], charsmax( g_szAuthID[ ] ) )
get_user_info( id, "name", g_szName[ id ], charsmax( g_szName[ ] ) )

replace_all( g_szName[ id ], charsmax( g_szName[ ] ), "'", "*" )
replace_all( g_szName[ id ], charsmax( g_szName[ ] ), "^"", "*" )
replace_all( g_szName[ id ], charsmax( g_szName[ ] ), "`", "*" )
replace_all( g_szName[ id ], charsmax( g_szName[ ] ), "�", "*" )

if( TrieKeyExists( g_tIgnoredAuthID, g_szAuthID[ id ] ) )
{
SetUserIgnored( id )
return
}

else
{
ClearUserIgnored( id )
}


LoadPoints( id )
}

public LoadPoints(id)
{
new szSteamId[32], szTemp[512]
get_user_authid(id, szSteamId, charsmax(szSteamId))

new Data[1]
Data[0] = id

format(szTemp,charsmax(szTemp),"SELECT skillpoints, level , kills, deaths, headshots, knife_kills, gather_wins, gather_looses, gathers_played, banpoints FROM %s WHERE steamid = '%s'",SQL_TABLE, g_szAuthID[ id ])
SQL_ThreadQuery(g_SqlTuple,"register_client",szTemp,Data,1)
}

public register_client(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
if(FailState == TQUERY_CONNECT_FAILED)
{
log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
}
else if(FailState == TQUERY_QUERY_FAILED)
{
log_amx("Load Query failed. [%d] %s", Errcode, Error)
}

new id
id = Data[0]

if(SQL_NumResults(Query) < 1) 
{
static name[32]
get_user_name(id, name, 31)

new szTemp[ 512 ]
format( szTemp, charsmax( szTemp ),
"INSERT INTO %s ( steamid, nick, skillpoints, level, kills, deaths, headshots, knife_kills, gather_wins, gather_looses, banpoints, ulevel )\
VALUES( '%s', '%s', '100', '1', '0', '0', '0', '0', '0', '0', '0', '0' )",
SQL_TABLE, g_szAuthID[ id ], name)

SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )

log_amx("New user! SteamID: %s | Name: %s", g_szAuthID[ id ], name)
set_task(3.0, "LoadPoints", id)
} 
else 
{
g_iPoints[ id ] = SQL_ReadResult( Query, 0 )
g_iLevels[ id ] = SQL_ReadResult( Query, 1 )
g_iKills[ id ] = SQL_ReadResult( Query, 2 )
g_iDeaths[ id ] = SQL_ReadResult( Query, 3 )
g_iHeadShots[ id ] = SQL_ReadResult( Query, 4 )
g_iKnifeKills[ id ] = SQL_ReadResult( Query, 5 )
g_iGatherWins[ id ] = SQL_ReadResult( Query, 6 )
g_iGatherLosses[ id ] = SQL_ReadResult( Query, 7 )
g_iGatherPlayed[ id ] = SQL_ReadResult( Query, 8 )
g_iBanPoints[ id ] = SQL_ReadResult( Query, 9 )

client_print(id, print_chat, "%s Your stats have been loaded...", PREFIX	)

g_bIsLoaded[id] = true
ShowPoints(id)
}

return PLUGIN_HANDLED
}

public LoadGathersPlayed()
{
new szTemp[512]
get_pcvar_string(p_Address,szAddress,charsmax(szAddress))

format(szTemp,charsmax(szTemp),"SELECT gathers FROM %s WHERE ip = '%s'",STATUS_TABLE, szAddress)
SQL_ThreadQuery(g_SqlTuple,"loadgplayed",szTemp)
}

public loadgplayed(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
if(FailState == TQUERY_CONNECT_FAILED)
{
log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
}
else if(FailState == TQUERY_QUERY_FAILED)
{
log_amx("Load Query failed. [%d] %s", Errcode, Error)
}

if(SQL_NumResults(Query) < 1) 
{
log_amx("Couldn't find ip adress on the table...")
} 
else { g_iGathersPlayed = SQL_ReadResult( Query, 0 ); }

return PLUGIN_HANDLED
}

public IgnoreHandle( FailState, Handle:Query, Error[ ], Errcode, Data[ ], DataSize )
SQL_FreeHandle( Query );

public client_death( iKiller, iVictim, weapon, hitplace )
{	
if( g_IsStarted) 
{
	
	if(iKiller == iVictim) { g_iDeaths[iVictim]++; }
	else
	{
		switch(g_iLevels[iKiller])
		{
			case 0: { g_iPointsGather[ iKiller ] += 9; }
			case 1: { g_iPointsGather[ iKiller ] += 8; } 
			case 2:	{ g_iPointsGather[ iKiller ] += 7; }
			case 3:	{ g_iPointsGather[ iKiller ] += 6; }
			case 4:	{ g_iPointsGather[ iKiller ] += 5; }
			case 5:	{ g_iPointsGather[ iKiller ] += 4; }
		}
		
		switch(g_iLevels[iVictim])
		{
			case 0: { g_iPointsGather[ iVictim ] -= 1; }
			case 1: { g_iPointsGather[ iVictim ] -= 2; }
			case 2:	{ g_iPointsGather[ iVictim ] -= 3; }
			case 3:	{ g_iPointsGather[ iVictim ] -= 4; }
			case 4:	{ g_iPointsGather[ iVictim ] -= 5; }
			case 5:	{ g_iPointsGather[ iVictim ] -= 6; }
		}
		
		g_iKills[ iKiller ]++
		g_iDeaths[ iVictim ]++
		
		if(hitplace == HIT_HEAD) { g_iHeadShots[ iKiller ]++; }
		if(weapon == CSW_KNIFE) { g_iKnifeKills[ iKiller ]++; }
	}
}
}

public TerroristsWin( )
{
if( g_bRoundEnded )
{
	return	
}

new Players[ MAX_PLAYERS ]
new iNum
new i

get_players( Players, iNum, "ch" )

for( --iNum; iNum >= 0; iNum-- )
{
	i = Players[ iNum ]
	switch( cs_get_user_team( i ) )
	{
		case( CS_TEAM_T ):
		{
			if( g_IsStarted )
			{
				switch(g_iLevels[ i ])
				{
					case 0: { g_iPointsGather[ i ] += 14; }
					case 1: { g_iPointsGather[ i ] += 13; } 
					case 2:	{ g_iPointsGather[ i ] += 12; }
					case 3:	{ g_iPointsGather[ i ] += 11; }
					case 4:	{ g_iPointsGather[ i ] += 10; }
					case 5:	{ g_iPointsGather[ i ] += 9; }
				}
			}
		}
		
		case( CS_TEAM_CT ):
		{
			if( g_IsStarted )
			{
				switch(g_iLevels[ i ])
				{
					case 0: { g_iPointsGather[ i ] -= 6; }
					case 1: { g_iPointsGather[ i ] -= 7; } 
					case 2:	{ g_iPointsGather[ i ] -= 8; }
					case 3:	{ g_iPointsGather[ i ] -= 9; }
					case 4:	{ g_iPointsGather[ i ] -= 10; }
					case 5:	{ g_iPointsGather[ i ] -= 11; }
				}
			}
		}
	}
}
if(secondhalf)
{
cs_set_team_score(CS_TEAM_T , g_iScore[1])
cs_set_team_score(CS_TEAM_CT , g_iScore[0])
}
g_bRoundEnded = true
}

public CounterTerroristsWin( )
{
if( g_bRoundEnded )
{
	return	
}

new Players[ MAX_PLAYERS ]
new iNum
new i

get_players( Players, iNum, "ch" )

for( --iNum; iNum >= 0; iNum-- )
{
	i = Players[ iNum ]
	
	switch( cs_get_user_team( i ) )
	{
		case( CS_TEAM_T ):
		{
			if( g_IsStarted )
			{
				switch(g_iLevels[ i ])
				{
					case 0: { g_iPointsGather[ i ] -= 6; }
					case 1: { g_iPointsGather[ i ] -= 7; } 
					case 2:	{ g_iPointsGather[ i ] -= 8; }
					case 3:	{ g_iPointsGather[ i ] -= 9; }
					case 4:	{ g_iPointsGather[ i ] -= 10; }
					case 5:	{ g_iPointsGather[ i ] -= 11; }
				}
			}
		}
		
		case( CS_TEAM_CT ):
		{
			if( g_IsStarted )
			{
				switch(g_iLevels[ i ])
				{
					case 0: { g_iPointsGather[ i ] += 14; }
					case 1: { g_iPointsGather[ i ] += 13; } 
					case 2:	{ g_iPointsGather[ i ] += 12; }
					case 3:	{ g_iPointsGather[ i ] += 11; }
					case 4:	{ g_iPointsGather[ i ] += 10; }
					case 5:	{ g_iPointsGather[ i ] += 9; }
				}
			}
		}
	}
}

if(secondhalf)
{
cs_set_team_score(CS_TEAM_T , g_iScore[1])
cs_set_team_score(CS_TEAM_CT , g_iScore[0])
}

g_bRoundEnded = true
}

public bomb_planted( planter )
{
if( g_IsStarted )
{
	switch(g_iLevels[planter])
	{
		case 0: { g_iPointsGather[ planter ] += 6; }
		case 1: { g_iPointsGather[ planter ] += 6; } 
		case 2:	{ g_iPointsGather[ planter ] += 5; }
		case 3:	{ g_iPointsGather[ planter ] += 4; }
		case 4:	{ g_iPointsGather[ planter ] += 3; }
		case 5:	{ g_iPointsGather[ planter ] += 2; }
		case 6:	{ g_iPointsGather[ planter ] += 1; }
	}
}
}

public bomb_explode( planter, defuser )
{
if( g_IsStarted )
{
	switch(g_iLevels[planter])
	{
		case 0: { g_iPointsGather[ planter ] += 3; }
		case 1: { g_iPointsGather[ planter ] += 3; } 
		case 2:	{ g_iPointsGather[ planter ] += 2; }
		case 3:	{ g_iPointsGather[ planter ] += 2; }
		case 4:	{ g_iPointsGather[ planter ] += 1; }
		case 5:	{ g_iPointsGather[ planter ] += 1; }
		case 6:	{ g_iPointsGather[ planter ] += 1; }
	}
}
}

public bomb_defused( defuser )
{
if( g_IsStarted )
{
	switch(g_iLevels[defuser])
	{
		case 0: { g_iPointsGather[ defuser ] += 9; }
		case 1: { g_iPointsGather[ defuser] += 9; } 
		case 2:	{ g_iPointsGather[ defuser ] += 7; }
		case 3:	{ g_iPointsGather[ defuser ] += 6; }
		case 4:	{ g_iPointsGather[ defuser ] += 4; }
		case 5:	{ g_iPointsGather[ defuser ] += 3; }
		case 6:	{ g_iPointsGather[ defuser ] += 2; }
	}
}
}

public client_damage(attacker,victim,damage,wpnindex,hitplace,TA){
if ( are_teammates ( attacker, victim ) ) {
	client_print(0, print_chat, "%s TK detected... Friendlyfire is now Off.", PREFIX)
	server_cmd("mp_friendlyfire 0")
	set_task(90.0, "TurnTKOn")
	return PLUGIN_CONTINUE
}
return PLUGIN_CONTINUE
}

public TurnTKOn()
server_cmd("mp_friendlyfire 1")

public EventNewRound( )
{
	g_bRoundEnded = false
	
	if(g_IsStarted && secondhalf)
	{
		cs_set_team_score(CS_TEAM_T , g_iScore[1])
		cs_set_team_score(CS_TEAM_CT , g_iScore[0])
	}
}

public show_money(client)
{
	static message[1024]
	static name[32]
	
	new money, id, len
	
	for (id = 1; id <= g_max_players; id++)
	{
		if (id != client && is_user_connected(id) && cs_get_user_team(id) == cs_get_user_team(client))
		{
			money = cs_get_user_money(id)
			get_user_name(id, name, 31)
			len = format(message[len], charsmax(message) - len, "%-22.22s: %d^n", name, money)
		}
	}
	set_hudmessage(0, 255, 0, 0.02, 0.27, 0, 6.0, 12.0)
	ShowSyncHudMsg(client, g_sync_creat_list, message)
}


public EventRoundEnd( )
{
	if (g_IsStarted)
	{
		
		new playersT[ 32 ] , numT , playersCt[ 32 ] , numCt
		get_players( playersT , numT , "che" , "TERRORIST" )
		get_players( playersCt , numCt , "che" , "CT" )	
		
		if (numT < 4  || numCt < 4)
		{
			switch (notbalanced)
			{
				case 0:
				{
					client_print(0, print_chat, "%s One of the teams have 3 players or less.", PREFIX)
					client_print(0, print_chat, "%s This team will loose if noone enters the gather.", PREFIX)
					notbalanced++
				}
				case 1:
				{
					client_print(0, print_chat, "%s One of the teams have 3 players or less.", PREFIX)
					client_print(0, print_chat, "%s This team will loose if noone enters the gather.", PREFIX)
					notbalanced++
				}
				case 2:
				{
					if (numT > numCt)
					{
						client_print(0, print_chat, "%s Terrorists won the game.", PREFIX)
						client_print(0, print_chat, "%s Gather is ending in 5 seconds...", PREFIX)
						set_task(5.0, "EndMatch")
					}
					else if (numCt > numT)
					{
						client_print(0, print_chat, "%s Counter-Terrorists won the game.", PREFIX)
						client_print(0, print_chat, "%s Gather is ending in 5 seconds...", PREFIX)
						set_task(5.0, "EndMatch")
					}
					else if (numCt == numT)
					{
						client_print(0, print_chat, "%s This match was tied because both teams were with low amount of players.", PREFIX)
						client_print(0, print_chat, "%s Gather is ending in 5 seconds...", PREFIX)
						set_task(5.0, "EndMatch")
					}
					notbalanced = 0
				}
			}
		}
	}
	return PLUGIN_HANDLED  
}

public CheckLevelAndSave( id )
{
	if( !(is_user_connected( id )) )
		return;
	
	if( g_iPoints[ id ]+g_iPointsGather[ id ] < LEVELS[ g_iLevels[ id ] ] )
	{
		g_iClasses[ id ] -= 1
		g_iLevels[ id ] -= 1
		client_print(id, print_chat, "%s Level DOWN! You're now level %s.", PREFIX, CLASSES[ g_iLevels[ id ] ])
	}
	else if( g_iPoints[ id ]+g_iPointsGather[ id ] >= LEVELS[ g_iLevels[ id ] ] )
	{
		g_iLevels[ id ] += 1
		g_iClasses[ id ] += 1
		client_print(id, print_chat, "%s Level UP! You're now level %s.", PREFIX, CLASSES[ g_iLevels[ id ] ])
	}
	
	if( g_iPoints[ id ] < 0 )
	{
		g_iPoints[ id ] = 0
		g_iPointsGather[ id ] = 0
		g_iLevels[ id ] = 0
	}
	
	
	new szTemp[ 512 ]
	formatex( szTemp, charsmax( szTemp ),
	"UPDATE %s SET nick = '%s', skillpoints = '%i',	level = '%i',\
	kills = '%i', deaths = '%i', headshots = '%i', knife_kills = '%i', gather_wins = '%i', gather_looses = '%i', gathers_played = '%i'\
	WHERE steamid = '%s'",
	SQL_TABLE, g_szName[ id ], g_iPoints[ id ]+g_iPointsGather[ id ], g_iLevels[ id ],
	g_iKills[ id ], g_iDeaths[ id ], g_iHeadShots[ id ], g_iKnifeKills[ id ], g_iGatherWins[ id ], g_iGatherLosses[ id ], g_iGatherPlayed[ id ],
	g_szAuthID[ id ] )
	
	SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )
}

public ChatAdvertisements( )
{
	new Players[ MAX_PLAYERS ]
	new iNum
	new i
	
	get_players( Players, iNum, "ch" )
	
	for( --iNum; iNum >= 0; iNum-- )
	{
		i = Players[ iNum ]
		client_print( i, print_chat,  g_ChatAdvertise[ g_iK ], PREFIX )
	}
	
	g_iK++
	
	if( g_iK >= sizeof g_ChatAdvertise )
		g_iK = 0;
}

public FwdPlayerSpawnPost( id )
{	
	if( !is_user_alive( id ) )
	{
		return
	}
	
	if (g_IsStarted)
	{	
		if (secondhalf)
		{
			if(cs_get_user_team(id) == CS_TEAM_T)
				ChangeTagB(id);
			
			if(cs_get_user_team(id) == CS_TEAM_CT) 
				ChangeTagA(id);
		}
		else
		{
			if(cs_get_user_team(id) == CS_TEAM_CT) 
				ChangeTagB(id);
			
			if(cs_get_user_team(id) == CS_TEAM_T)
				ChangeTagA(id);
		}
	}	
}

public Event_DeathMsg()
{
	if(g_IsStarted)
	{
		new killer = read_data( 1 )
		new victim = read_data( 2 )
		
		if( !killer ) return PLUGIN_HANDLED
		
		gKillerID[victim] = killer	
		
		cmdGetInfo(victim)
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public cmdGetInfo( id )
{
	if( g_IsStarted ) {
		if( is_user_alive( id ) )
		{
			client_print( id, print_chat, "%s You must be dead to use this command.", PREFIX )
			return PLUGIN_HANDLED
		}
		
		new stats[8], bodyhits[8]
		
		get_user_vstats( id, gKillerID[id], stats, bodyhits, _, _ )
		
		if( !gKillerID[id] )
		{
			client_print( id, print_chat, "%s You have not been killed yet!", PREFIX	 )
			return PLUGIN_HANDLED
		}
		
		new killerName[32], killerHealth = get_user_health( gKillerID[id] )
		get_user_name( gKillerID[id], killerName, 31 )
		
		client_print( id, print_chat, "%s %s killed you! He still has %i HP (You hit him with %i damage)", PREFIX, killerName, killerHealth, stats[6] )
		return PLUGIN_HANDLED
	}
	else
	{
		client_print( id, print_chat, "%s Gather is not started yet!", PREFIX )
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}  

public showscore(id)
{
	if (g_IsStarted)
	{		
		if (secondhalf)
		{
			client_print(id, print_chat, "%s [ Score: %s %d - %s %d ]", PREFIX, TagsT[TagsNum], g_iScore[1], TagsCT[TagsNum], g_iScore[0])
			didscore = false
		}
		
		else
		{
			client_print(id, print_chat, "%s [ Score: %s %d - %s %d ]", PREFIX, TagsT[TagsNum], g_iScore[0], TagsCT[TagsNum], g_iScore[1])
			didscore = false
		}
	}
	
	else
	{
		client_print(id, print_chat, "%s Gather is not Live yet!", PREFIX)
	}
	return PLUGIN_CONTINUE
}

public handled(id)
{
	if (g_IsStarted || g_AfterRdy) {
		client_print(id, print_chat, "%s You cant change team!", PREFIX)
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public scndhalf()
{
	if (get_playersnum() <= 0)
	{
		client_print(0, print_chat, "%s There are 6 or less players... Restarting gather.", PREFIX)
		g_IsStarted = false
		g_AfterRdy = false
		set_task(3.0, "MatchIsOver")
		return PLUGIN_HANDLED
	}
	else if (get_playersnum() <= 0)
	{
		client_print(0, print_chat, "%s Some players left the game... Waiting for 10 players.", PREFIX)
		set_task(10.0, "scndhalf")
		return PLUGIN_HANDLED
	}
	else{
		server_cmd("sv_restart 1")
		set_task(2.0, "scndhalf1")
	}
	return PLUGIN_CONTINUE
}
public scndhalf1()
{
	server_cmd("sv_restart 1")
	set_task(2.0, "scndhalf2")
}
public scndhalf2()
{
	server_cmd("sv_restart 1")
	set_task(2.0, "showscnd")
}

public showscnd()
{	
	set_hudmessage(255, 255, 255, -1.0, 0.11, 0, 6.0, 5.0)
	show_hudmessage(0, "LIVE LIVE LIVE^nGood Luck & Have Fun")
	UserScoreInsert()
}

public UserScoreSave()
{
	new players[32], pnum, tempid
	get_players(players, pnum, "ch")		
	for( new i; i<pnum; i++ )
	{
		tempid = players[i]
		
		Frags[tempid] = get_user_frags(tempid)
		Deaths[tempid] = cs_get_user_deaths(tempid)
	}
}

public UserScoreInsert()
{
	new players[32], pnum, tempid
	get_players(players, pnum, "ch")		
	for( new i; i<pnum; i++ )
	{
		tempid = players[i]
		
		set_user_frags(tempid, Frags[tempid])
		cs_set_user_deaths(tempid, Deaths[tempid])
		
	}
}

public Event_TeamScore()
{
	if (g_IsStarted)
	{
		read_data(1, szTeamName, 1)
		
		iTeam = (szTeamName[0] == 'T') ? 0 : 1
		iScore = read_data(2)
		iScoreOffset = iScore - g_iLastTeamScore[iTeam]
		
		if(iScoreOffset > 0)
			g_iScore[iTeam] += iScoreOffset
		
		g_iLastTeamScore[iTeam] = iScore
		
		if (g_iScore[0] + g_iScore[1] == 15)
		{
			if (Stop2) { return PLUGIN_HANDLED; }
			
			UpdateStatus()
			client_print(0, print_chat, "%s Good Half! Switching teams...", PREFIX)
			UserScoreSave()
			set_task(10.0, "scndhalf")
			Stop2 = true
			SwitchTeams()
				
		}
		
		else if ((g_iScore[0] == 16) || (g_iScore[1] == 16))
		{
			if (Stop) { return PLUGIN_HANDLED; }
			
			Stop = true
			EndMatch()
			UpdateStatus()
			return PLUGIN_CONTINUE
		}
		
		else if ((g_iScore[0] == 15) & (g_iScore[1] == 15))
		{
			if (Stop) { return PLUGIN_HANDLED; }
			
			Stop = true
			EndMatch()
			UpdateStatus()
			return PLUGIN_CONTINUE
		}
		
		else if ((g_iScore[0] == 15) || (g_iScore[1] == 15))
		{
			ClientCommand_SayScore()
			UpdateStatus()
			return PLUGIN_CONTINUE
		}	
		
		ClientCommand_SayScore()
		UpdateStatus()
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

public EndMatch()
{
	set_hudmessage(255, 255, 255, -1.0, 0.11, 0, 6.0, 5.0)
	show_hudmessage(0, "^n^nThanks for playing^n^n%s %d - %s %d",TagsT[TagsNum], g_iScore[0],TagsCT[TagsNum], g_iScore[1])
	client_print(0, print_chat, "%s Thanks for playing, another match will start in 20 secs, stay tuned.", PREFIX)
	g_iGathersPlayed++
	set_task(20.0, "MatchIsOver")
	set_task(3.0, "GatherToSqlE")
	GathersStats()
	g_IsStarted = false
}

public SwitchTeams()
{
	
	new supportvariable
	
	supportvariable = g_iScore[0]
	g_iScore[0] = g_iScore[1]
	g_iScore[1] = supportvariable
	
	new players[32], pnum, tempid;
	
	get_players(players, pnum, "ch");
	for( new i; i<pnum; i++ )
	{
		tempid = players[i];
		
		if (cs_get_user_team(tempid) == CS_TEAM_T)
			cs_set_user_team(tempid, CS_TEAM_CT)
		
		else
			cs_set_user_team(tempid, CS_TEAM_T)
	}
	
	secondhalf = true
	
	return PLUGIN_HANDLED
}

public ClientCommand_SayScore()
{	
	if (g_Twon)
	{
		if (secondhalf)
		{
			if (didscore)
			{
				client_print(0, print_chat, "%s [ Score: %s %d - %s %d ]",PREFIX,TagsT[TagsNum], g_iScore[0],TagsCT[TagsNum], g_iScore[1])
				didscore = false
			}
			
			else
			{
				didscore = true
			}
		}
		
		else
		{
			if (didscore)
			{
				
				client_print(0, print_chat, "%s [ Score: %s %d - %s %d ]",PREFIX,TagsT[TagsNum], g_iScore[1],TagsCT[TagsNum], g_iScore[0])
				didscore = false
			}
			
			else
			{
				didscore = true
			}
		}
	}
	
	else
	{
		
		if (secondhalf)
		{
			if (didscore)
			{
				client_print(0, print_chat, "%s [ Score: %s %d - %s %d ]",PREFIX,TagsT[TagsNum], g_iScore[1],TagsCT[TagsNum], g_iScore[0])
				didscore = false
			}
			
			else
			{
				didscore = true
			}
		}
		
		else
		{
			if (didscore)
			{
				client_print(0, print_chat, "%s [ Score: %s %d - %s %d ]",PREFIX,TagsT[TagsNum], g_iScore[0],TagsCT[TagsNum], g_iScore[1])
				didscore = false
			}
			
			else
			{
				didscore = true
			}
		}
	}
	
	return PLUGIN_HANDLED
	
}

public ClCmd_joinclass( id )
{
	if( get_pdata_int( id, m_iMenu ) == CSMENU_JOINCLASS )
	{
		if(g_IsStarted) { 
			RecordDemo(id)
			set_task(1.0, "rate_menu", id)
			return PLUGIN_CONTINUE
		}
		if(g_AfterRdy || g_MapChanged || g_bIsReady[id]) { return PLUGIN_CONTINUE; }
		else
		{
			set_task(1.0, "rate_menu", id)
			client_print(id, print_chat, "%s You will be automatically set as ready after 10 seconds.", PREFIX)
			set_task(10.0, "Prepare", id)
			return PLUGIN_CONTINUE
		}
	}
	return PLUGIN_CONTINUE
}  

public rate_menu(id)
{	
	new Menu = menu_create("\rRate Menu^n\wDo you want to use our rates?^n\yrate 100000, cl_updaterate 102, cl_cmdrate 105, ex_interp 0.01", "func_menu")
	menu_additem(Menu, "Yes", "1", 0)
	menu_additem(Menu, "No", "2", 0)
	menu_setprop(Menu, MPROP_EXIT, MEXIT_NEVER)
	menu_display(id, Menu)
	return PLUGIN_HANDLED
}

public func_menu(id, Menu, item)
{
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED
	new iData[6];  
	new iAccess; 
	new iCallback; 
	new iName[64]; 
	menu_item_getinfo(Menu , item , iAccess , iData , 5 , iName, 63 , iCallback )
	
	switch (str_to_num(iData)) 
	{ 
		case 1 :
		{
			client_cmd(id, "rate 100000")
			client_cmd(id, "cl_cmdrate 105")
			client_cmd(id, "cl_updaterate 102")
			client_cmd(id, "ex_interp 0.01")
		}
		case 2 : return PLUGIN_HANDLED
		}
	
	menu_destroy(Menu)
	return PLUGIN_HANDLED 
}

public client_disconnect(id)
{
	if(g_IsStarted) {
		g_iPoints[id]-=15
		CheckLevelAndSave(id)
		new name[32]
		get_user_name(id, name, 31)
		client_print(0, print_chat, "%s The player %s lost 15 points for leaving the gather.", PREFIX, name)
		return PLUGIN_CONTINUE
	}
	
	g_LeftVotes[id] = 0
	
	if(g_bIsReady[id])
		playersleft++
	
	g_bIsReady[id] = false
	remove_task(id)
	return PLUGIN_HANDLED
}

public CheckandBan(id)
{
	g_iBanPoints[id]++
	UpdateBanPoints(id)
	
	new name[32]
	get_user_name(id, name, 31)
	if(g_iBanPoints[id] == 2) { 
		server_cmd("amx_ban ^"%s^" ^"60^" ^"Leaving^"", g_szAuthID[ id ])
	}
	else if(g_iBanPoints[id] == 3) { 
		server_cmd("amx_ban ^"240^" ^"%s^" ^"Leaving^"", g_szAuthID[ id ])
	}
	else if(g_iBanPoints[id] == 4) { 
		server_cmd("amx_ban ^"960^" ^"%s^" ^"Leaving^"", g_szAuthID[ id ])
	}
	else if(g_iBanPoints[id] == 5) { 
		server_cmd("amx_ban ^"1440^" ^"%s^" ^"Leaving^"", g_szAuthID[ id ])
	}
	else if(g_iBanPoints[id] == 6) { 
		server_cmd("amx_ban ^"2880^" ^"%s^" ^"Leaving^"", g_szAuthID[ id ])
	}
	else if(g_iBanPoints[id] >= 7) { 
		server_cmd("amx_ban ^"5760^" ^"%s^" ^"Leaving^"", g_szAuthID[ id ])
	}	
}

public client_connect(id)
{	
	if (is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_HANDLED;
	
	g_afktime[id] = 0
	g_LeftVotes[id] = 0
	
	if (!file_exists(pug_ini_file))
	{
		client_print(0, print_chat, "%s ERROR! Pug.ini file not found.", PREFIX)
		return PLUGIN_HANDLED
	}
	
	if (get_pug_state() == 1)
	{
		g_LeftKills[id] = 0
		return PLUGIN_HANDLED
	}
	
	if (g_AfterRdy || g_IsStarted)
	{
		g_iPointsGather[id]=0
		return PLUGIN_HANDLED
	}
	
	else
	{
		g_iTimeLeft[id] = 130
		g_LeftKills[id] = 0
	}
	
	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	g_afktime[id] = 0
	
	if (is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_HANDLED;
	
	if (g_IsStarted || g_AfterRdy)
	{
		g_LeftKills[id] = 0
		MoveFromSpec(id)
		return PLUGIN_HANDLED
	} 
	
	g_bIsReady[id] = false
	remove_task(id)
	set_task(30.0, "CheckUnAssigned", id)
	return PLUGIN_HANDLED
}

public MoveFromSpec(id)
{
	new playersT[ 32 ] , numT , playersCt[ 32 ] , numCt
	get_players( playersT , numT , "che" , "TERRORIST" )
	get_players( playersCt , numCt , "che" , "CT" )	
	
	if (g_Twon)
	{
		if (secondhalf)
		{
			if (numT == 5)
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}	
			
			else if (numCt == 5)
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
			
			if( numT > numCt )
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
		}
		
		else
		{
			if (numT == 5)
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else if (numCt == 5)
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
			
			if( numT > numCt )
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}	
		}
	}
	
	else
	{
		if (secondhalf)
		{
			if (numT == 5)
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else if (numCt == 5)
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
			
			if( numT > numCt )
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
		}
		
		else
		{
			if (numT == 5)
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}	
			
			else if (numCt == 5)
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}
			
			if( numT > numCt )
			{
				set_cvar_string("humans_join_team", "CT")
				client_cmd(id, "slot1")
				
			}
			
			else
			{
				set_cvar_string("humans_join_team", "T")
				client_cmd(id, "slot1")
				
			}	
		}
	}
	
	return PLUGIN_CONTINUE
}

public ShowPoints( id )
{
	if(g_bIsLoaded[id])
	{
		if( g_IsStarted ) {
			if( g_iLevels[ id ] < ( MAX_LEVELS - 1 ) )
				client_print( id, print_chat, "%s Total points: %d | This gather: %d | Level: %s [%d/%d]", PREFIX, g_iPoints[ id ]+g_iPointsGather[ id ],g_iPointsGather[ id ], CLASSES[ g_iLevels[ id ] ],g_iLevels[ id ]+1,MAX_LEVELS);
			
			else
				client_print( id, print_chat, "%s Total points: %d | This gather: %d | Level: %s [%d/%d]", PREFIX, g_iPoints[ id ]+g_iPointsGather[ id ],g_iPointsGather[ id ], CLASSES[ g_iLevels[ id ] ],g_iLevels[ id ]+1,MAX_LEVELS);
			
		}
		else 
			client_print( id, print_chat, "%s Total points: %d | This gather: Not Live | Level: %s [%d/%d]", PREFIX, g_iPoints[ id ]+g_iPointsGather[ id ],CLASSES[ g_iLevels[ id ] ],g_iLevels[ id ]+1,MAX_LEVELS);
		
	}
	else 
		client_print(id, print_chat, "%s Your stats haven't been loaded yet. Wait...", PREFIX)
}

public ShowBanPoints( id )
	client_print( id, print_chat, "%s You have %d Ban Points.", PREFIX, g_iBanPoints[ id ]);

public ShowGathersPlayed( id )
	client_print( id, print_chat, "%s %d gathers have been played on this server.", PREFIX, g_iGathersPlayed);

public MessageShowMenu(iMsgID, iDest, iReceiver)
{
	new const Team_Select[] = "#Team_Select";
	new szMenu[sizeof(Team_Select)];
	
	get_msg_arg_string(4, szMenu, charsmax(szMenu));
	
	if(!equal(szMenu, Team_Select))
	{
		return PLUGIN_CONTINUE;
	}
	
	// reset CS menu code
	set_pdata_int(iReceiver, m_iMenuCode, 0);
	
	// show your own menu
	
	return PLUGIN_HANDLED;
}

public MessageVGUIMenu(iMsgID, iDest, iReceiver)
{
	if(get_msg_arg_int(1) != 2)
	{
		return PLUGIN_CONTINUE;
	}
	
	// show your own menu
	
	return PLUGIN_HANDLED;
} 	

public CheckUnAssigned(id)
{
	if (cs_get_user_team(id) == CS_TEAM_UNASSIGNED)
	{
		server_cmd("kick # %d Away", get_user_userid(id))
	}
	
	return PLUGIN_HANDLED
}

public Prepare(id)
{
	if (g_AfterRdy || g_IsStarted || g_MapChanged)
		return PLUGIN_HANDLED
	
	if( g_bIsReady[id] )
		return PLUGIN_HANDLED
	
	else
	{
		g_bIsReady[id] = true
		playersleft--
		remove_task(id)
	}
	
	if (playersleft != 0)
		client_print(0, print_chat, "%s %d Players left to gather start.", PREFIX, playersleft)
	
	else
	{
		g_AfterRdy = true
		remove_task()
		client_print(0, print_chat, "%s The votemap will start in 5 seconds..", PREFIX)
		set_task(5.0, "StartVote")
	}
	
	return PLUGIN_HANDLED
}

public StartVote()
{ 
	getmaps()
	new rnd
	
	while (donemaps != 4 && mapscounter > 0)
	{
		rnd = random(mapscounter)
		copy(mapschosen[donemaps++], 19, mapsavailable[rnd])
		mapsavailable[rnd] = mapsavailable[--mapscounter]
	}        
	
	gVoteMenu = menu_create("\wWhich map do you want?:", "votemap");
	
	new num[11]
	for(new i = 0; i < donemaps; i++)
	{
		num_to_str(i, num, 10)
		menu_additem(gVoteMenu, mapschosen[i], num, 0)
	}
	menu_additem(gVoteMenu, "\nExtend", "4", 0)
	
	new players[32], pnum, tempid;
	
	get_players(players, pnum, "ch");
	
	for( new i; i<pnum; i++ )
	{
		tempid = players[i];
		menu_display(tempid, gVoteMenu);
	}
	
	set_task(8.0, "EndVote"); 
	return PLUGIN_HANDLED;
}


public votemap(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_display(id, gVoteMenu)
		return PLUGIN_HANDLED;
	}
	
	new data[6], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);
	
	new voteid = str_to_num(data);	
	gVotes[voteid]++;
	return PLUGIN_HANDLED;
}

public getmaps()
{
	get_configsdir(maps_ini_file, 63);
	format(maps_ini_file, 63, "%s/maps.ini", maps_ini_file);
	
	new mapsfile = fopen(maps_ini_file, "r")
	new linefortest[50]
	
	while (mapscounter < sizeof(mapsavailable) && !feof(mapsfile))
	{
		fgets(mapsfile, linefortest, 49)
		trim(linefortest)
		
		new getcurrentmap[32]
		get_mapname(getcurrentmap, 31)
		
		if ((is_map_valid(linefortest)) && (!equali(linefortest, getcurrentmap)))
		{
			copy(mapsavailable[mapscounter++], 24, linefortest)
		}
	}
	
	fclose(mapsfile)
} 

public EndVote()
{
	show_menu(0, 0, "^n", 1);
	new best = 0;
	for(new i = 1; i < sizeof(gVotes); i++)
	{
		if(gVotes[i] > gVotes[best])
			best = i;
	}
	
	gVotes[0] = 0
	gVotes[1] = 0
	gVotes[2] = 0
	gVotes[3] = 0
	gVotes[4] = 0
	
	if(best == 4)
	{
		client_print(0, print_chat, "%s Map will be extended in this game.", PREFIX)
		set_task(5.0, "RandomTeams")
	}
	else
	{
		
		ChangingMap()
		client_print(0, print_chat, "%s Map will be changed in 5 seconds to %s.", PREFIX, mapschosen[best])
		changemapto = best
		set_pug_state(1)
		set_task(5.0, "ChangeMap")
	}
	
	return PLUGIN_HANDLED
} 

public ChangingMap()
{
	set_hudmessage(0, 255, 0, -1.0, 0.35, 0, 0.02, 7.0, 0.1, 0.2, 2)	
	show_hudmessage(0, "Changing map in 10 seconds, dont disconnect.")
	
	set_task(1.0, "ChangingMap")		
}

public ChangeMap()
{
	new maptochangeto[25]
	
	remove_task()
	copy(maptochangeto, 24, mapschosen[changemapto])
	server_cmd("changelevel %s", maptochangeto)
	return PLUGIN_CONTINUE
}

public RandomTeams()
{
	if (get_playersnum() <= 6)
	{
		client_print(0, print_chat, "%s There are 6 or less players... Restarting gather.", PREFIX)
		g_IsStarted = false
		g_AfterRdy = false
		set_task(3.0, "MatchIsOver")
		return PLUGIN_HANDLED
	}
	else if (get_playersnum() < 10)
	{
		client_print(0, print_chat, "%s Some players left the game... Waiting for 10 players.", PREFIX)
		set_task(10.0, "RandomTeams")
		return PLUGIN_HANDLED
	}
	else{
		new players[32], pnum, tempid
		
		get_players(players, pnum, "ch")
		for( new i; i<pnum; i++ )
		{
			tempid = players[i]
			user_kill(tempid)
			
			if (cs_get_user_team(tempid) == CS_TEAM_UNASSIGNED)
			{
				continue
			}
			
			cs_set_user_team(tempid, CS_TEAM_SPECTATOR)
		}
		
		new topick, idop
		
		while (AnyoneInSpec())
		{
			if (cs_get_user_team(players[idop]) == CS_TEAM_UNASSIGNED)
			{
				idop++
				continue
			}
			
			topick = random(2)
			
			if (topick == 1)
			{
				cs_set_user_team(players[idop], CS_TEAM_T)
			}
			
			else
			{
				cs_set_user_team(players[idop], CS_TEAM_CT)
			}
			
			new pplayers[32], ppnum, tempid
			new ppplayers[32], pppnum
			new temppnum
			
			get_players(players, pnum, "ch");
			get_players(pplayers, ppnum, "che", "CT")
			get_players(ppplayers, pppnum, "che", "TERRORIST")
			
			if (ppnum == pnum/2)
			{
				get_players(players, temppnum, "ch")
				
				for( new i; i<temppnum; i++ )
				{
					tempid = players[i]
					
					if (cs_get_user_team(tempid) == CS_TEAM_SPECTATOR)
					{
						cs_set_user_team(tempid, CS_TEAM_T)
					}
				}
			}
			
			else if (pppnum == pnum/2)
			{
				get_players(players, temppnum, "ch")
				
				for( new i; i<temppnum; i++ )
				{
					tempid = players[i]
					
					if (cs_get_user_team(tempid) == CS_TEAM_SPECTATOR)
					{
						cs_set_user_team(tempid, CS_TEAM_CT)
					}
				}
			}
			
			idop++
		}
		set_task(2.0, "StartMatch")
	}
	return PLUGIN_CONTINUE
}

public AnyoneInSpec()
{
	new players[32], pnum, tempid;
	
	get_players(players, pnum, "ch");
	for( new i; i<pnum; i++ )
	{
		tempid = players[i];
		
		if (cs_get_user_team(tempid) == CS_TEAM_SPECTATOR)
		{
			return true
		}
	}
	
	return false
}

public StartMatch()
{	
	new players[32], pnum, tempid;
	
	get_players(players, pnum, "ch")
	
	if (pnum < get_pcvar_num(cvar_playersleft) - 2)
	{
		if (didwaitenough < 8)
		{
			didwaitenough++
			set_task(15.0, "StartMatch")
			return PLUGIN_HANDLED
		}
		
		set_cvar_string("humans_join_team", "")
		g_iScore[0] = 0
		g_iScore[1] = 0
		g_AfterRdy = false
		g_IsStarted = false
		didwaitenough = 0
		playersleft = get_maxplayers()
		
		client_print(0, print_chat, "%s There are no players to play the gather. Restarting.", PREFIX)
		set_task(5.0, "MatchIsOver")
		
		for( new i; i<pnum; i++ )
		{
			tempid = players[i];
			g_bIsReady[tempid] = false
			remove_task(tempid)
			g_iTimeLeft[tempid] = 130
			g_LeftKills[tempid] = 0
			secondhalf = false
		}
		return PLUGIN_HANDLED
	}
	
	for (new x ; x<pnum ; x++)
	{
		tempid = players[x]
		
		if (cs_get_user_team(tempid) == CS_TEAM_UNASSIGNED)
		{
			continue;
		}
		
		if (cs_get_user_team(tempid) == CS_TEAM_SPECTATOR)
		{
			server_cmd("kick #%d", get_user_userid(tempid))
		}
		
		else if(cs_get_user_team(tempid) == CS_TEAM_T)
		{
			ChangeTagA(tempid)
		}
		
		else if (cs_get_user_team(tempid) == CS_TEAM_CT)
		{
			ChangeTagB(tempid)
		}
	}
	
	set_task(1.0, "Settings")
	GatherToSqlS()
	
	return PLUGIN_HANDLED
}

public GatherToSqlS()
{
	get_mapname( szMapName, charsmax( szMapName ) )
	get_pcvar_string(p_Address,szAddress,charsmax(szAddress))
	
	new szTemp[ 512 ]
	format( szTemp, charsmax( szTemp ),
	"INSERT INTO `%s` ( ip, sgid, map, team1, team2 )\
	VALUES( '%s', '%d', '%s', '%s', '%s' )",
	SQL_GTABLE, szAddress, g_iGathersPlayed+1,szMapName, TagsT[TagsNum], TagsCT[TagsNum] )
	
	SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )
}

public GatherToSqlE()
{
	get_mapname( szMapName, charsmax( szMapName ) )
	get_pcvar_string(p_Address,szAddress,charsmax(szAddress))
	
	new szTemp[ 512 ]
	format( szTemp, charsmax( szTemp ),
	"UPDATE `%s` SET `status`='1', `score1`='%d', `score2`='%d'\
	WHERE `ip`='%s' AND `sgid`='%d'",
	SQL_GTABLE, g_iScore[1], g_iScore[0], szAddress, g_iGathersPlayed)
	
	SQL_ThreadQuery( g_SqlTuple, "IgnoreHandle", szTemp )
}

public ChangeTagA(id)
{
	new pname[100]
	new newname[70]
	
	get_user_info(id, "name", pname, 49)
	
	pname = RemoveOldTag(pname)
	
	format(newname, 69, "%s %s", TagsT[TagsNum], pname)
	set_user_info(id, "name", newname)
	return PLUGIN_CONTINUE
}
public ChangeTagB(id)
{
	new pname[100]
	new newname[70]
	
	get_user_info(id, "name", pname, 49)
	
	pname = RemoveOldTag(pname)
	
	format(newname, 69, "%s %s",TagsCT[TagsNum], pname)
	set_user_info(id, "name", newname)
	return PLUGIN_CONTINUE
}
public RemoveOldTag(pname[100])
{
	replace_all(pname, 69, "YOLO ", "")
	replace_all(pname, 69, "SWAG ", "")
	replace_all(pname, 69, "RED ", "")
	replace_all(pname, 69, "BLUE ", "")
	replace_all(pname, 69, "DOGS ", "")
	replace_all(pname, 69, "CATS ", "")
	replace_all(pname, 69, "NINJAS ", "")
	replace_all(pname, 69, "PIRATES ", "")
	replace_all(pname, 69, "VAGINA ", "")
	replace_all(pname, 69, "PENIS ", "")
	replace_all(pname, 69, "VODKA ", "")
	replace_all(pname, 69, "BEER ", "")
	replace_all(pname, 69, "HATE ", "")
	replace_all(pname, 69, "LOVE ", "")
	replace_all(pname, 69, "BOOBS ", "")
	replace_all(pname, 69, "ASS ", "")
	replace_all(pname, 69, "LEETS ", "")
	replace_all(pname, 69, "NOOBS ", "")
	replace_all(pname, 69, "HATERS ", "")
	replace_all(pname, 69, "FANS ", "")
	replace_all(pname, 69, "FAKE ", "")
	replace_all(pname, 69, "REAL ", "")
	replace_all(pname, 69, "BLACK ", "")
	replace_all(pname, 69, "WHITE ", "")
	replace_all(pname, 69, "POSITIVE ", "")
	replace_all(pname, 69, "NEGATIVE ", "")
	replace_all(pname, 69, "DEATH ", "")
	replace_all(pname, 69, "LIFE", "")
	replace_all(pname, 69, "PEACE ", "")
	replace_all(pname, 69, "WAR ", "")
	replace_all(pname, 69, "LOGIC ", "")
	replace_all(pname, 69, "EMOTION ", "")
	replace_all(pname, 69, "NORTH ", "")
	replace_all(pname, 69, "SOUTH ", "")
	replace_all(pname, 69, "DISORDER ", "")	
	replace_all(pname, 69, "ORDER ", "")
	replace_all(pname, 69, "DARK ", "")	
	replace_all(pname, 69, "LIGHT ", "")
	trim(pname)
	
	return pname
}

public cmds(id) {
	client_print(id, print_chat, "%s Commands: .sk, .score, .hp", PREFIX)
	client_print(id, print_chat, "%s Commands: .bp, .gp", PREFIX)
	client_print(id, print_chat, "%s Commands: .voteban, .servers", PREFIX)
}

public cmdServers(id) {
	client_print(id, print_chat, "%s All servers IP at our website www.piccgathers.com", PREFIX)
	client_print(id, print_chat, "%s Teamspeak3 IP: 37.10.107.10:9988", PREFIX)
}

public cmdRestart(id){
	if(get_user_flags(id) & ADMIN_KICK)
		server_cmd("sv_restart 1")		
}

public cmdLive(id){
	if(get_user_flags(id) & ADMIN_KICK)
	{
		StartMatch()	
	}
}

public cmdEnd(id){
	if(get_user_flags(id) & ADMIN_KICK)
	{
		EndMatch()
	}	
}

public Settings()
{
	server_cmd("mp_startmoney 800")
	server_cmd("mp_freezetime 10")
	server_cmd("mp_roundtime 1.75")
	server_cmd("mp_c4timer 35")
	server_cmd("mp_friendlyfire 1")
	
	server_cmd("sv_restart 1")
	set_task(2.0, "firsthalf1")
	set_task(2.0, "Lo3")
}

public firsthalf1()
{
	server_cmd("sv_restart 1")
	set_task(2.0, "firsthalf2")
}
public firsthalf2()
{
	server_cmd("sv_restart 1")
	set_task(2.0, "Lo3")
}

public Lo3()
{
	client_cmd(0 , "spk radio/com_go")
	client_print(0, print_chat, "%s Go Go Go!", PREFIX)
	client_print(0, print_chat, "%s Match is now LIVE!", PREFIX)
	client_print(0, print_chat, "%s You're now recording a demo. You can stop it by writting stop in console.", PREFIX)
	RecordDemos()
	Started()
}

public Started()
{
	set_pug_state(2)
	g_iStatus=1
	set_hudmessage(255, 255, 255, -1.0, 0.11, 0, 6.0, 5.0)
	show_hudmessage(0, "LIVE LIVE LIVE^nGood Luck & Have Fun")
	g_IsStarted = true
	g_AfterRdy = false
	UpdateStatus()
	return PLUGIN_HANDLED
}

public RecordDemos()
{
	new szTimedata[9]
	new szSName[128]
	get_time ( "%H:%M:%S", szTimedata, 8 )
	
	replace_all( szTimedata, 8, ":", "_" )
	
	formatex(szSName, charsmax( szSName ), "piccgathers_%d-%s", g_iGathersPlayed+1, szTimedata)
	
	new playersnum = get_playersnum()
	
	for(new i = 1; i < playersnum; i++)
	{
		client_cmd( i, "stop; record ^"%s^"", szSName )
		client_print( i, print_chat, "%s Recording to ^"%s.dem^"", PREFIX, szSName )
	}
}

public RecordDemo(id)
{
	new szTimedata[9]
	new szSName[128]
	get_time ( "%H:%M:%S", szTimedata, 8 )
	
	replace_all( szTimedata, 8, ":", "_" )
	
	formatex(szSName, charsmax( szSName ), "piccgathers_%d-%s", g_iGathersPlayed+1, szTimedata)
	
	client_cmd( id, "stop; record ^"%s^"", szSName )
	client_print( id, print_chat, "%s Recording to ^"%s.dem^"", PREFIX, szSName )
}

public GathersStats()
{
	new players[32], pnum, tempid
	new Float:points[33]
	
	get_players(players, pnum, "ch")
	for( new i; i<pnum; i++ )
	{
		tempid = players[i]
		new Float:valor
		if((g_iScore[0] == 16))
		{
			if((cs_get_user_team(tempid) == CS_TEAM_CT)) 
			{ 
				points[tempid] = g_iPointsGather[tempid] * 0.5
				valor = points[tempid]
				g_iPointsGather[tempid] = floatround(valor)
				g_iGatherWins[tempid]++ 
				g_iGatherPlayed[tempid]++ 
				CheckLevelAndSave(tempid) 
				EndMessage(tempid) 
			}
			else if((cs_get_user_team(tempid) == CS_TEAM_T)) 
			{ 
				points[tempid] = g_iPointsGather[tempid] * 0.3
				valor = points[tempid]
				g_iPointsGather[tempid] = floatround(valor)
				g_iGatherLosses[tempid]++ 
				g_iGatherPlayed[tempid]++ 
				CheckLevelAndSave(tempid) 
				EndMessage(tempid) 
			}
		}
		else if((g_iScore[1] == 16))
		{
			if((cs_get_user_team(tempid) == CS_TEAM_T)) 
			{
				points[tempid] = g_iPointsGather[tempid] * 0.3
				valor = points[tempid]
				g_iPointsGather[tempid] = floatround(valor)
				g_iGatherWins[tempid]++ 
				g_iGatherPlayed[tempid]++ 
				CheckLevelAndSave(tempid)
				EndMessage(tempid)
			}
			else if((cs_get_user_team(tempid) == CS_TEAM_CT)) 
			{ 
				points[tempid] = g_iPointsGather[tempid] * 0.3
				valor = points[tempid]
				g_iPointsGather[tempid] = floatround(valor)
				g_iGatherLosses[tempid]++
				g_iGatherPlayed[tempid]++
				CheckLevelAndSave(tempid)
				EndMessage(tempid)
			}
		}
		else
		{
			g_iGatherPlayed[tempid]++
			CheckLevelAndSave(tempid)
			EndMessage(tempid)
		}
		
	}
}

public EndMessage(id)
{
	set_hudmessage(255, 255, 255, 0.02, 0.50, 0, 15.0, 1.0)
	show_hudmessage(id, "Thanks for playing %s^nYou had %d points, you made %i points in this gather^nYou have now %d points and you are %s [%d/%d]^nYou can join another gather when map restart (20 sec)", g_szNick[id], g_iPoints[id], g_iPointsGather[id], g_iPoints[id]+g_iPointsGather[id],CLASSES[ g_iLevels[ id ] ],g_iLevels[ id ]+1,MAX_LEVELS)
	
	set_task(1.0, "EndMessage", id)
}

public MatchIsOver()
{
	ResetAll()
	
	new szMapName[ 32 ]
	get_mapname( szMapName, charsmax( szMapName ) )
	
	if(equali( szMapName, "de_dust2" )) server_cmd("changelevel de_inferno")
	else server_cmd("changelevel de_dust2")
	return PLUGIN_CONTINUE
}

public ResetAll()
{
	g_iScore[0] = 0
	g_iScore[1] = 0
	g_iStatus=0
	didwaitenough = 0
	g_IsStarted = false
	g_AfterRdy = false
	remove_task()
	g_Twon = false
	playersleft = get_pcvar_num(cvar_playersleft)
	set_cvar_string("humans_join_team", "")
	UpdateStatus()
	set_pug_state(0)
	return PLUGIN_CONTINUE
}

stock replace_it(string[], len, const what[], const with[])
{
	new pos = 0;
	
	if ((pos = contain(string, what)) == -1)
	{
		return 0;
	}
	
	new total = 0;
	new with_len = strlen(with);
	new diff = strlen(what) - with_len;
	new total_len = strlen(string);
	new temp_pos = 0;
	
	while (replace(string[pos], len - pos, what, with) != 0)
	{
		total++;
		pos += with_len;
		
		total_len -= diff;
		
		if (pos >= total_len)
		{
			break;
		}
		
		temp_pos = contain(string[pos], what);
		
		if (temp_pos == -1)
		{
			break;
		}
		
		pos += temp_pos;
	}
	
	return total;
}

public checkPlayers() {
	for (new i = 1; i <= get_maxplayers(); i++) {
		if (is_user_alive(i) && is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i) && g_spawned[i]) {
			new newangle[3]
			get_user_origin(i, newangle)
			if ( newangle[0] == g_oldangles[i][0] && newangle[1] == g_oldangles[i][1] && newangle[2] == g_oldangles[i][2] ) {
				g_afktime[i] += CHECK_FREQ
				check_afktime(i)
				} else {
				g_oldangles[i][0] = newangle[0]
				g_oldangles[i][1] = newangle[1]
				g_oldangles[i][2] = newangle[2]
				g_afktime[i] = 0
			}
		}
	}
	return PLUGIN_HANDLED
}

check_afktime(id) {
	new numplayers = get_playersnum()
	new minplayers = get_cvar_num("mp_afkminplayers")
	
	if (numplayers >= minplayers) {
		new maxafktime = get_cvar_num("mp_afktime")
		if (maxafktime < MIN_AFK_TIME) {
			log_amx("cvar mp_afktime %i is too low. Minimum value is %i.", maxafktime, MIN_AFK_TIME)
			maxafktime = MIN_AFK_TIME
			set_cvar_num("mp_afktime", MIN_AFK_TIME)
		}
		if ( maxafktime-WARNING_TIME <= g_afktime[id] < maxafktime) {
			new timeleft = maxafktime - g_afktime[id]
			client_print(id, print_chat, "%s You have %i seconds to move.", PREFIX, timeleft)
			} else if (g_afktime[id] > maxafktime) {
			new name[32]
			get_user_name(id, name, 31)
			log_amx("%s was kicked for being afk", name, maxafktime)
			server_cmd("kick #%d Away", get_user_userid(id))
		}
	}
}

public playerSpawned(id) {
	g_spawned[id] = false
	new sid[1]
	sid[0] = id
	set_task(0.75, "delayedSpawn",_, sid, 1)    // Give the player time to drop to the floor when spawning
	return PLUGIN_HANDLED
}

public delayedSpawn(sid[]) {
	get_user_origin(sid[0], g_oldangles[sid[0]])
	g_spawned[sid[0]] = true
	return PLUGIN_HANDLED
}

public cmdSay(id) {
	new Args[192]
	read_args(Args,charsmax(Args))
	remove_quotes(Args)
	
	if(Args[0] == '.' || Args[0] == '!')
	{
		client_cmd(id, Args)
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public get_pug_state()
{
	new file = fopen(pug_ini_file, "r")
	fseek(file, -1, SEEK_END)
	new getchar = fgetc(file)
	fclose(file)
	return getchar - '0'
}

public set_pug_state(iState)
{
	new file = fopen(pug_ini_file, "w")
	fseek(file, -1, SEEK_END)
	fputc(file, iState + '0')
	fclose(file)
}

public Change()
{ 
	forward_return(FMV_STRING, "[#gather v2.0.3]");
	return FMRES_SUPERCEDE;
}

stock bool:are_teammates ( e_Index1, e_Index2 ) {
	if ( get_user_team ( e_Index1 ) != get_user_team ( e_Index2 ) )
		return false;
	
	return true;
}

stock Team_Info(id, type, team[])
{
	message_begin(type, TeamInfo, _, id);
	write_byte(id);
	write_string(team);
	message_end();
	return 1;
}

stock FindPlayer()
{
	new i = -1;
	while(i <= MaxSlots)
	{
		if(IsConnected[++i])
		{
			return i;
		}
	}
	return -1;
}

stock cs_set_team_score(CsTeams:iTeam,iScore)
{     
    if(!(CS_TEAM_T <= iTeam <= CS_TEAM_CT)) return PLUGIN_CONTINUE;

    message_begin(MSG_ALL,get_user_msgid("TeamScore"),{0,0,0});
    write_string(iTeam == CS_TEAM_T ? "TERRORIST" : "CT");
    write_short(iScore);
    message_end();

    return PLUGIN_HANDLED;
}  
