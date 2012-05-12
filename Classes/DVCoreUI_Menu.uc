/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVCoreUI_Menu extends DVMovie;


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/

var (CoreUI) const array<string>		IgnoredMaps;
var (CoreUI) const array<string>		MenuListData;
var (CoreUI) const array<string>		ResListData;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var GFxClikWidget 						MapListMC;
var GFxClikWidget 						MenuListMC;
var GFxClikWidget 						ServerListMC;
var GFxClikWidget 						ResListMC;

var GFxClikWidget 						ServerConnect;
var GFxClikWidget 						PlayerConnect;
var GFxClikWidget 						SaveVideoSettings;

var array<UDKUIDataProvider_MapInfo> 	MapList;
var array<string>						ServerList;
var array<string>						IPList;

var bool 								bMapsInitialized;
var bool								bIsInRegisterPopup;

var string								ServerURL;


/*----------------------------------------------------------
	PAGE 1 : SERVERS
----------------------------------------------------------*/

/*--- Add a possibly new server to the local database ---*/
function AddServerInfo(string ServerName, string Level, string IP, string Game, int Players, int MaxPlayers)
{
	if (IPList.Find(IP) < 0)
	{
		ServerList.AddItem(FormatServerInfo(ServerName, Level, Game, Players, MaxPlayers));
		IPList.AddItem(IP);
	}
}


/*--- Server browser ---*/
function UpdateServerList()
{
	local byte 			i;
	local GFxObject 	TempObj;
	local GFxObject 	DataProvider;

	// Sending data to menu
	DataProvider = ServerListMC.GetObject("dataProvider");
	for (i = 0; i < ServerList.Length; i++)
	{
		TempObj = CreateObject("Object");
		TempObj.SetString("label", ServerList[i]);
		DataProvider.SetElementObject(i, TempObj);
	}
	ServerListMC.SetObject("dataProvider", DataProvider);
	ServerListMC.SetFloat("rowCount", i);
}


/*--- Return a formatted server string to be displayed in the server browser ---*/
function string FormatServerInfo(string ServerName, string Level, string Game, int Players, int MaxPlayers)
{
	ServerName = Caps(ServerName);
	Game = GetRightMost(Game);
	Level = Caps(Repl(Level, ".udk", "", false));
	return (ServerName $ "\n" $Players $"/" $MaxPlayers $" joueurs, " $Game $"\n" $Level);
}


/*--- Server selection ---*/
function OnServerItemClick(GFxClikWidget.EventData ev)
{
    local GFxObject button;
    local string ServerString;
    
    button = ev._this.GetObject("itemRenderer");
	ServerString = button.GetString("label");
	
	ServerURL = IPList[ServerList.Find(ServerString)];
	ServerConnect.SetBool("enabled", true);
}


/*--- Map list ---*/
function UpdateMapList()
{
	local byte 			i;
	local string 		TempMapName;
	local GFxObject 	TempObj;
	local GFxObject 	DataProvider;
	local array<UDKUIResourceDataProvider> ProviderList;

	// Checking data
	if (!bMapsInitialized)
	{
		class'UDKUIDataStore_MenuItems'.static.GetAllResourceDataProviders(class'UDKUIDataProvider_MapInfo', ProviderList);
		for (i = 0; i < ProviderList.length; i++)
		{
			TempMapName = UDKUIDataProvider_MapInfo(ProviderList[i]).MapName;
			if (!IsInArray(TempMapName, IgnoredMaps)) 
				MapList.AddItem(UDKUIDataProvider_MapInfo(ProviderList[i]));
		}
		bMapsInitialized = true;
	}
	
	// Sending data to menu
	DataProvider = MapListMC.GetObject("dataProvider");
	for (i = 0; i < MapList.Length; i++)
	{
		TempObj = CreateObject("Object");
		TempObj.SetString("label", Caps((MapList[i]).MapName));
		DataProvider.SetElementObject(i, TempObj);
	}
	MapListMC.SetObject("dataProvider", DataProvider);
	MapListMC.SetFloat("rowCount", i);
}


/*--- Map click ---*/
function OnMapItemClick(GFxClikWidget.EventData ev)
{
    local GFxObject button;
    button = ev._this.GetObject("itemRenderer");
	ServerURL = button.GetString("label");
	ServerConnect.SetBool("enabled", true);
}


/*--- Server connection ---*/
function OpenServer(GFxClikWidget.EventData evtd)
{
	ConsoleCommand("open " $ ServerURL);
}


/*--- Player connexion event ---*/
function OnPlayerConnect(GFxClikWidget.EventData evtd)
{
	OpenConnectionDialog(false);
}


/*--- Open the connection popup ---*/
function OpenConnectionDialog(bool bShowRegister)
{
	local string Text[7];
	
	`log("OpenConnectionDialog");
	if (!bShowRegister)
	{
		Text[0] = "Connexion DeepVoid";
		Text[1] = "Joueur";
		Text[2] = "Mot de passe";
		Text[3] = "";
		Text[4] = "";
		Text[5] = "Connexion";
		Text[6] = "Nouveau ?";
		SetPopup(Text, 2);
	}
	else
	{
		Text[0] = "Nouveau compte";
		Text[1] = "Joueur";
		Text[2] = "E-mail";
		Text[3] = "Mot de passe";
		Text[4] = "Mot de passe";
		Text[5] = "S'enregistrer";
		Text[6] = "Retour";
		SetPopup(Text, 3, 4);
	}
}


/*--- Language ---*/
simulated function GetServerContent()
{
	`log("GetServerContent");
	
	SetLabel("MenuTitle", "Parties en ligne", true);
	SetLabel("MapTitle", "Parties en solo", true);
	SetLabel("ServerTitle", "Parties en ligne", true);
	SetLabel("ButtonsTitle", "Actions", true);
	
	OpenConnectionDialog(false);
	HidePopup(true);
}


/*--- Popup button 1 : action ---*/
function OnPButton1(GFxClikWidget.EventData evtd)
{
	// Init
	local array<string> Result;
	super.OnPButton1(evtd);
	Result = GetPopupContent();
	
	// Checking
	if (Len(Result[0]) < 4 || Len(Result[1]) < 4)
		SetPopupStatus("Donn�es incorrectes");
	else if (Result[2] != Result[3])
		SetPopupStatus("Mots de passe diff�rents");
	
	// Actions
	else if (!bIsInRegisterPopup)
	{
		PC.MasterServerLink.ConnectToMaster(Result[0], Result[1]);
		PC.SaveIDs(Result[0], Result[1]);
		SetPopupStatus("Connexion...");
	}
	else
	{
		PC.MasterServerLink.RegisterUser(Result[0], Result[1], Result[2]);
		SetPopupStatus("Enregistrement...");
	}
}


/*--- Popup button 2 : change window ---*/
function OnPButton2(GFxClikWidget.EventData evtd)
{
	super.OnPButton2(evtd);
	bIsInRegisterPopup = !bIsInRegisterPopup;
	OpenConnectionDialog(bIsInRegisterPopup);
}


/*--- Show result on screen ---*/
function GetPopupResult(bool bSuccess, string Msg)
{
	`log("GetPopupResult");
	if (bSuccess)
	{
		HidePopup(true);
	}
	else	
	{
		SetPopupStatus((Msg != "") ? Msg : "Un probl�me s'est produit");
	}
}


/*----------------------------------------------------------
	PAGE 2 : STATS
----------------------------------------------------------*/

/*--- Content ---*/
simulated function GetStatsContent()
{
	// Init
	local DVUserStats LStats, GStats;
	local string RankInfo;
	LStats = DVHUD_Menu(PC.myHUD).LocalStats;
	GStats = DVHUD_Menu(PC.myHUD).GlobalStats;
	
	// General
	SetLabel("MenuTitle", "Statistiques de jeu", true);
	SetLabel("StatGenTitle1", "Statistiques globales", true);
	SetLabel("StatGenTitle2", "Derni�re partie", true);
	SetLabel("StatGenTitle3", "DeepVoid rank", true);
	
	// Stat block 1
	SetLabel("StatTitle1", "Efficacit�", true);
	SetAlignedLabel("Stat10", "Victimes", string(GStats.Kills));
	SetAlignedLabel("Stat11", "Pr�cision", string(GStats.Kills / GStats.ShotsFired) $ "%");
	SetAlignedLabel("Stat12", "Ratio K/D", string(GStats.Kills / GStats.Deaths));
	SetPieChart("PieStat1", "Stat13", "Team-kill", GStats.TeamKills / GStats.Kills);
	
	// Stat block 2
	SetLabel("StatTitle2", "Victimes par arme", true);
	SetAlignedLabel("Stat20", "Fusil d'assaut", string(GStats.WeaponScores[0]));
	SetAlignedLabel("Stat21", "Sniper",  string(GStats.WeaponScores[1]));
	SetAlignedLabel("Stat22", "Shotgun",  string(GStats.WeaponScores[2]));
	SetPieChart("PieStat2", "Stat23", "Headshots", GStats.Headshots / GStats.Kills);
	
	// Stat block 3
	SetLabel("Stat30", "Votre �quipe a gagn�", false);
	SetAlignedLabel("Stat31", "Rang final", string(LStats.Rank));
	SetAlignedLabel("Stat32", "Victimes", string(LStats.Kills));
	SetAlignedLabel("Stat33", "Tirs effect�", string(LStats.ShotsFired));
	
	// Stat block 4
	if (GStats.Rank > 0)
		RankInfo = "Vous �tes class� au rang " $ string(GStats.Rank);
	else
		RankInfo = "Vous n'�tes pas class�";
	SetLabel("Stat40", RankInfo, false);
	SetLabel("Stat41", "Vous avez " $ string(GStats.Points) $ " points", false);
}


/*----------------------------------------------------------
	PAGE 3 : SETTINGS
----------------------------------------------------------*/

/*--- Content ---*/
simulated function GetOptionsContent()
{
	local DVHUD_Menu HInfo;
	HInfo = DVHUD_Menu(PC.myHUD);
	
	// General
	SetLabel("MenuTitle", "Configuration du jeu", true);
	SetLabel("OptionGenTitle1", "Audio & Vid�o", true);
	SetLabel("OptionGenTitle2", "Gameplay", true);
	SetLabel("OptionGenTitle3", "Touches", true);
	
	// Option block 1
	SetWidgetLabel("OptionCB1", "Musique en jeu", false);
	SetWidgetLabel("OptionCB2", "Indicateur d'impact", false);
	SetWidgetLabel("OptionCB3", "Plein �cran", false);
	SetChecked("OptionCB1", HInfo.LocalStats.bBackgroundMusic);
	SetChecked("OptionCB2", HInfo.LocalStats.bUseSoundOnHit);
	SetChecked("OptionCB3", HInfo.LocalStats.bFullScreen);
	
	// Option block 2
	
	
	// Option block 3
	
}


/*--- Resolution list ---*/
function UpdateResList()
{
	local byte 			i;
	local GFxObject 	TempObj;
	local GFxObject 	DataProvider;
	
	// Sending data to menu
	DataProvider = ResListMC.GetObject("dataProvider");
	for (i = 0; i < ResListData.Length; i++)
	{
		TempObj = CreateObject("Object");
		TempObj.SetString("label", ResListData[i]);
		DataProvider.SetElementObject(i, TempObj);
	}
	ResListMC.SetObject("dataProvider", DataProvider);
	ResListMC.SetInt("selectedIndex", 0);
}


/*--- Settings saved ---*/
function ValidateSettings(GFxClikWidget.EventData ev)
{
	// Init
	local GFxObject button;
	local DVHUD_Menu HInfo;
	local string res, flag;
	HInfo = DVHUD_Menu(PC.myHUD);
	
	// Resolution
	button = GetSymbol("ResolutionList");
	res = Split(ResListData[int(button.GetString("selectedIndex"))], "(", false);
	`log("Clicked resolution " $ res);
	
	// Fullscreen
	flag = (IsChecked("OptionCB3") ? "f" : "w");
	
	// Application
	switch (res)
	{
		case ("(720p)"):
			ConsoleCommand("SetRes 1280x720" $flag);
			break;
		case ("(1080p)"):
			ConsoleCommand("SetRes 1920x1080" $flag);
			break;
		case ("(max)"):
			ConsoleCommand("SetRes 6000x3500" $flag);
			break;
	}
	
	// Options
	HInfo.LocalStats.SetBoolValue("bBackgroundMusic", IsChecked("OptionCB1"));
	HInfo.LocalStats.SetBoolValue("bUseSoundOnHit", IsChecked("OptionCB2"));
	HInfo.LocalStats.SetBoolValue("bFullScreen", IsChecked("OptionCB3"));
	HInfo.LocalStats.SaveConfig();
}


/*----------------------------------------------------------
	Common methods
----------------------------------------------------------*/

/*--- Initialization ---*/
event bool WidgetInitialized (name WidgetName, name WidgetPath, GFxObject Widget)
{		
	switch(WidgetName)
	{
		// Lists
		case ('MapList'):
			MapListMC = GFxClikWidget(Widget);
			UpdateMapList();
			MapListMC.AddEventListener('CLIK_itemClick', OnMapItemClick);
			break;
		case ('ServerList'):
			ServerListMC = GFxClikWidget(Widget);
			UpdateServerList();
			ServerListMC.AddEventListener('CLIK_itemClick', OnServerItemClick);
			break;
		case ('MenuList'):
			MenuListMC = GFxClikWidget(Widget);
			UpdateMenuList();
			MenuListMC.AddEventListener('CLIK_itemClick', OnMenuItemClick);
			break;
		
		// Buttons
		case ('OpenServerButton'):
			ServerConnect = GFxClikWidget(Widget);
			ServerConnect.AddEventListener('CLIK_click', OpenServer);
			ServerConnect.SetString("label", "Rejoindre la partie s�lectionn�e");
			ServerConnect.SetBool("enabled", false);
			break;
		case ('PlayerConnectButton'):
			PlayerConnect = GFxClikWidget(Widget);
			PlayerConnect.AddEventListener('CLIK_click', OnPlayerConnect);
			PlayerConnect.SetString("label", "Se connecter � DeepVoid.eu");
			break;
		case ('ResolutionList'):
			ResListMC = GFxClikWidget(Widget);
			UpdateResList();
			break;
		
		// Various
		case ('SaveVideoSettings'):
			SaveVideoSettings = GFxClikWidget(Widget);
			SaveVideoSettings.AddEventListener('CLIK_click', ValidateSettings);
			SaveVideoSettings.SetString("label", "Sauvegarder les r�glages");
			break;
			
		default:
			return super.WidgetInitialized(Widgetname, WidgetPath, Widget);
	}
	return true;
}


/*--- Menu list ---*/
function UpdateMenuList()
{
	local byte 			i;
	local GFxObject 	TempObj;
	local GFxObject 	DataProvider;
	
	// Sending data to menu
	DataProvider = MenuListMC.GetObject("dataProvider");
	for (i = 0; i < MenuListData.Length; i++)
	{
		TempObj = CreateObject("Object");
		TempObj.SetString("label", MenuListData[i]);
		DataProvider.SetElementObject(i, TempObj);
	}
	MenuListMC.SetObject("dataProvider", DataProvider);
}


/*--- Menu navigation ---*/
function OnMenuItemClick(GFxClikWidget.EventData ev)
{
    local GFxObject button;
    button = ev._this.GetObject("itemRenderer");
    
	if(button.GetString("label") == MenuListData[3])
	{
		ConsoleCommand("exit");
	}
	else
	{
		GoToFrame(button.GetInt("index"));
	}
	PlayUISound(BipSound);
}


/*--- Get a command response code ---*/
function DisplayResponse (bool bSuccess, string Msg)
{
	GetPopupResult(bSuccess, Msg);
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	bCaptureInput=true
	 
	IgnoredMaps=("LD","FX","AMB","ART","DefaultMap")
	
	MenuListData=("Parties","Statistiques","R�glages","Quitter")
	ResListData=("Ecran HD (1080p)","Ecran HDReady (720p)","D�faut (max)")
	
	ServerURL="deepvoid.eu"
	MovieInfo=SwfMovie'DV_CoreUI.MainMenu'
	
	WidgetBindings(3)={(WidgetName="MapList",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(4)={(WidgetName="ServerList",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(5)={(WidgetName="MenuList",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(6)={(WidgetName="ResolutionList",WidgetClass=class'GFxClikWidget')}
	
	WidgetBindings(7)={(WidgetName="OpenServerButton",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(8)={(WidgetName="PlayerConnectButton",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(9)={(WidgetName="SaveVideoSettings",WidgetClass=class'GFxClikWidget')}
	
	WidgetBindings(10)={(WidgetName="OptionCB1",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(11)={(WidgetName="OptionCB2",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(12)={(WidgetName="OptionCB3",WidgetClass=class'GFxClikWidget')}
}
