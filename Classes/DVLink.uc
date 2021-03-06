/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVLink extends TcpLink;


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/

var (DVLink) const int				MasterServerPort;

var (DVLink) const float			TimeoutLength;
var (DVLink) const float			ServerListUpdateFrequency;

var (DVLink) const string 			MasterServerIP;

var (DVLink) string					CurrentID;

var (DVLink) string					Separator;
var (DVLink) string					Escapement;

var (DVLink) localized string 		lOK;
var (DVLink) localized string 		lNOK;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var bool							bIsOpened;
var bool							bIsConnected;
var bool							bSending;

var string							LastCommandSent;
var array<string>					CommandBuffer;

var DVPlayerController				PC;


/*----------------------------------------------------------
	Game methods
----------------------------------------------------------*/

/*--- Initialization ---*/
simulated function InitLink(DVPlayerController LinkedController)
{
	`log("DVLINK > InitLink");
	PC = LinkedController;
	bSending = false;
	resolve(MasterServerIP);
}


/*--- Connect to server using player IDs
	CONNECT,Username,Password
---*/
simulated function ConnectToMaster(string Username, string Password)
{
	local array<string> Params;
	
	`log("DVLINK > ConnectToMaster");
	Params.AddItem(Repl(Username, Separator, Escapement));
	Params.AddItem(Repl(Password, Separator, Escapement));
	SendServerCommand("CONNECT", Params, false);
}


/*--- Register at the master server : player version 
	REG_USER,Username,Email,Password
---*/
reliable client simulated function RegisterUser(string Username, string Email, string Password)
{
	local array<string> Params;
	Params.AddItem(Repl(Username, Separator, Escapement));
	Params.AddItem(Repl(Email, Separator, Escapement));
	Params.AddItem(Repl(Password, Separator, Escapement));
	SendServerCommand("REG_USER", Params, false);
}


/*--- Register at the master server : game server version
	DEC_SERVER,ServerName,Email,Password,bUsePassword
---*/
reliable server simulated function RegisterServer(string ServerName, string Email, string Password, bool bUsePassword)
{
	local array<string> Params;
	Params.AddItem(Repl(ServerName, Separator, Escapement));
	Params.AddItem(Email);
	Params.AddItem(Repl(Password, Separator, Escapement));
	Params.AddItem(bUsePassword ? "1":"0");
	SendServerCommand("DEC_SERVER", Params, false);
}


/*--- Server heartbeat
	HEARTBEAT,ServerID,MapName,GameName,PlayerCount,PlayerMax
---*/
reliable server simulated function Heartbeat(string MapName, string GameName, int PlayerCount, int PlayerMax)
{
	local array<string> Params;
	
	if (WorldInfo.NetMode == NM_DedicatedServer)
	{
		Params.AddItem(CurrentID);
		Params.AddItem(MapName);
		Params.AddItem(GameName);
		Params.AddItem(""$PlayerCount);
		Params.AddItem(""$PlayerMax);
		SendServerCommand("HEARTBEAT", Params, true);
	}
}


/*--- Get servers
	GET_SERVERS[,GameName[,MapName]]
---*/
reliable client simulated function GetServers(optional string GameName, optional string MapName)
{
	local array<string> Params;

	`log("DVLINK > GetServers");
	if (GameName != "")
		Params.AddItem(Repl(GameName, Separator, Escapement));
	if (MapName != "")
		Params.AddItem(Repl(MapName, Separator, Escapement));
	SendServerCommand("GET_SERVERS", Params, false);
}


/*--- Get the best players
	TOP_PLAYERS,PlayerCount
	LOC_PLAYERS,PlayerCount,ID
---*/
reliable client simulated function GetLeaderboard(int PlayerCount, string ID)
{
	local array<string> Params;
	
	PC.CleanBestPlayer();
	Params.AddItem(""$PlayerCount);
	SendServerCommand("TOP_PLAYERS", Params, false);
	//Params.AddItem(""$ID);
	//SendServerCommand("LOC_PLAYERS", Params, false);
}


/*--- Save the current game statistics : the command is sent by the server for each client
	SAVE_GAME,ServerID,ClientID,kills,deaths,teamkills,rank,shots,headshots
	
---*/
reliable server simulated function SaveGame(int kills, int deaths, int teamkills, int rank, int shots, int headshots, array<int> WeaponScores, string clientID)
{
	local array<string> Params;
	
	// Server + client ID
	Params.AddItem(CurrentID);
	Params.AddItem(clientID);
	
	// Data
	Params.AddItem(""$kills);
	Params.AddItem(""$deaths);
	Params.AddItem(""$teamkills);
	Params.AddItem(""$rank);
	Params.AddItem(""$shots);
	Params.AddItem(""$headshots);
	
	// Saving
	`log("DVLINK > SaveGame for" @clientID);
	SendServerCommand("SAVE_GAME", Params, true);
	SaveWeaponsStats(WeaponScores, clientID);
}


/*--- Save the current game's weapon statistics
	SAVE_WGAME,ClientID,{8*WeaponScores}
---*/
reliable server simulated function SaveWeaponsStats(array<int> WeaponScores, string clientID)
{
	local array<string> Params;
	local int i;
	
	// Server + client ID
	Params.AddItem(CurrentID);
	Params.AddItem(clientID);
	
	// Data
	for (i = 0; i < WeaponScores.Length; i++)
	{
		Params.AddItem("" $ WeaponScores[i]);
	}
	
	// Saving
	`log("DVLINK > SaveWeaponsStats for" @clientID);
	SendServerCommand("SAVE_WGAME", Params, true);
}


/*--- Get all statistics
	GET_GSTATS,ClientID
	GET_WSTATS,ClientID
---*/
reliable client simulated function GetStats()
{
	local array<string> Params;

	Params.AddItem(""$CurrentID);
	SendServerCommand("GET_GSTATS", Params, true);
	SendServerCommand("GET_WSTATS", Params, true);
}


/*--- Disarm timeout ---*/
simulated function AbortTimeout()
{
	ClearTimer('SignalTimeout');
}


/*----------------------------------------------------------
	Private methods
----------------------------------------------------------*/

/*--- Send a command to the master server ---*/
simulated function SendServerCommand(string Command, array<string> Params, bool bRequireNet)
{
	local string ParamsString;
	
	// If failed connexion, retry...
	if (!bIsOpened)
	{
		`log("DVLINK > Reconnecting");
		resolve(MasterServerIP);
	}
	
	// Not yet connected
	else if (CurrentID == "0" && bRequireNet)
	{
		`log("DVLINK > Cannot send commands while disconnected");
		return;
	}
	
	// Good to go
	else
	{
		if (Params.Length > 0)
		{
			`log("DVLINK > CMD >" @Command);
			JoinArray(Params, ParamsString, Separator);
			Command $= Separator;
			Command $= ParamsString;
		}

		WriteText(Command);
	}
}


/*--- Command writing ---*/
simulated function WriteText(string data)
{
	local array<string> OutputArray;

	if (bSending)
	{
		CommandBuffer.AddItem(data);
	}
	else
	{
		bSending = true;
		SetTimer(TimeoutLength, false, 'SignalTimeout');
		SendText(data $"\n");
		ParseStringIntoArray(data, OutputArray, Separator, false);
		LastCommandSent = OutputArray[0];
	}
}

/*--- TImer version */
simulated function WriteTextOnBuffer()
{
	local string data;
	if (CommandBuffer.Length > 0 && !bSending)
	{
		data = CommandBuffer[0];
		CommandBuffer.RemoveItem(data);
		if (data != "")
		{
			WriteText(data);
		}
	}
}

/*--- Command reception ---*/
simulated function array<string> GetServerCommand(string Input)
{
	local array<string> OutputArray;
	ParseStringIntoArray(Input, OutputArray, Separator, false);
	return OutputArray;
}


/*--- Command timeout ---*/
simulated function SignalTimeout()
{
	`log("DVLINK > Command timeout...");
	SignalController("NET", false, "Serveur indisponible");
	bSending = false;
}


/*--- Server OK processing ---*/
simulated function ProcessACK(string Param)
{
	SignalController(LastCommandSent, true, lOK);
	AbortTimeout();
	bSending = false;
}


/*--- Call back the controller to inform it ---*/
simulated function SignalController(string Command, bool bIsOK, optional string Msg)
{
	if (WorldInfo.NetMode == NM_DedicatedServer)
		return;
	else if (PC != None)
		PC.TcpCallback(Command, bIsOK, Msg);
	else
		`log("DVLINK > Could not inform the controller because it does not exist");
}


/*----------------------------------------------------------
	Events
----------------------------------------------------------*/

/*--- TCP connexion answer ---*/
event Resolved(IpAddr Addr)
{
	`log("DVLINK > Successfully resolved master server" @IpAddrToString(Addr));
	
	Addr.Port = MasterServerPort;
	AbortTimeout();
	
	`log("DVLINK > Bound to port" @BindPort());
	if (!Open(Addr))
	{
		`log("DVLINK > Could not connect to master server...");
	}
}


/*--- No connexion ! ---*/
event ResolveFailed()
{
	`log("DVLINK > Failed to resolve master server");
	bIsOpened = false;
	SignalController("NET", false, "Hors ligne");
}


/*--- Server accepted the connexion ---*/
event Opened()
{
	local bool bUsePassword;
	bIsOpened = true;
	`log("DVLINK > Successfully opened master server");
	
	// On client : get the server list
	if (WorldInfo.NetMode != NM_DedicatedServer)
	{
		if (GH_Menu(PC.myHUD) != None)
		{
			SetTimer(0.2, true, 'WriteTextOnBuffer');
		}
		SignalController("INIT", true, "");
	}
	
	// On server : register
	else
	{
		bUsePassword = WorldInfo.Game.AccessControl.RequiresPassword();
		RegisterServer(
				DVGame(WorldInfo.Game).ServerName,
				DVGame(WorldInfo.Game).ServerEmail,
				DVGame(WorldInfo.Game).ServerPassword,
				bUsePassword);
	}
}


/*--- Closed connexion ---*/
event Closed()
{
	`log("DVLINK > Closed master server");
	bIsConnected = false;
	bIsOpened = false;
	SignalController("NET", false);
}


/*--- Text mode : we need to clean this shit up ---*/
event ReceivedText(string Text)
{
	local array<string> InputArray;
	local int i;
	
	ParseStringIntoArray(Text, InputArray, "\n", false);
	for (i = 0; i < InputArray.Length; i++)
	{
		if (Len(InputArray[i]) > 0)
			ReceivedLine(InputArray[i]);
	}
}


/*--- Main event callback : get all server commands and answers ---*/
event ReceivedLine(string Line)
{
	// Init
	local array<string> Command;
	Command = GetServerCommand(Line);
	if (Command.Length == 0)
		return;
	`log("DVLINK > CMD < " $ Command[0]);
	
	// Error management
	if (IsEqual(Command[0], "NOK"))
	{
		SignalController(LastCommandSent, false, lNOK);
		bSending = false;
		return;
	}
	
	// Error management
	else if (IsEqual(Command[0], "DOWN"))
	{
		Close();
		bSending = false;
		return;
	}

	// Standard ACK for successful commands
	else if (IsEqual(Command[0], "OK"))
	{
		// Connection speficic case
		if ((IsEqual(LastCommandSent, "CONNECT") || IsEqual(LastCommandSent, "DEC_SERVER")) && Command[1] != "0")
		{
			bIsConnected = true;
			CurrentID = Left(Command[1], 20);
			if (IsEqual(LastCommandSent, "CONNECT") && GH_Menu(PC.myHUD) != None)
			{
				SetTimer(ServerListUpdateFrequency, true, 'GetServers');
			}
			`log("DVLINK > Connection validated");
		}
		
		// Save game
		else if (IsEqual(LastCommandSent, "SAVE_GAME"))
		{
			DVGame(WorldInfo.Game).PrepareRestart();
		}

		// Server list
		else if (IsEqual(LastCommandSent, "GET_SERVERS"))
		{
			GH_Menu(PC.myHUD).DisplayServerInfo();
		}

		// Default case
		ProcessACK(Command[1]);
		return;
	}
		
	// Leaderboards
	if (IsEqual(Command[0], "TOP_PLAYER"))
	{
		PC.AddBestPlayer(Command[2], int(Command[6]), int(Command[7]), true);
		return;
	}
	else if (IsEqual(Command[0], "LOC_PLAYER"))
	{
		PC.AddBestPlayer(Command[2], int(Command[6]), int(Command[7]), false);
		return;
	}
	
	// Server list
	else if (IsEqual(Command[0], "SERVER") && PC != None)
	{
		if (GH_Menu(PC.myHUD) != None)
		{
			//SERVER,ServerName,Level,IP,Game,Players,MaxPlayers,bIsPassword
			GH_Menu(PC.myHUD).AddServerInfo(
				Command[1],
				Command[2],
				Command[3],
				Command[4], 
				int(Command[5]),
				int(Command[6]),
				Left(Command[7],1) != "0"
			);
		}
		return;
	}

	// Player statistics
	if (  InStr(Command[0], "GET_GSTATS") != -1
			|| InStr(Command[0], "GET_LSTATS") != -1
			|| InStr(Command[0], "GET_WSTATS") != -1
	){
		PC.TcpGetStats(Command);
		bSending = false;
	}
}


/*--- Check if command is as expected ---*/
simulated function bool IsEqual(string Data, string Command)
{
	return (InStr(Data, Command) != -1);
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	bIsOpened=false
	bIsConnected=false
	
	Separator=","
	Escapement=""
	CurrentID="0"

	TimeoutLength=5.0
	ServerListUpdateFrequency=5.0
	LinkMode=MODE_Text
	ReceiveMode=RMODE_Event
	
	MasterServerIP="master.deepvoid.eu"
	MasterServerPort=9999
}
