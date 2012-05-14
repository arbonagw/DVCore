/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVCoreUI_HUD extends DVMovie;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var GFxClikWidget 			ResumeButtonMC;
var GFxClikWidget 			RestartButtonMC;
var GFxClikWidget 			SwitchTeamButtonMC;
var GFxClikWidget 			ExitButtonMC;

var GFxClikWidget 			WeaponListMC;
var GFxClikWidget 			ScoreListRed;
var GFxClikWidget 			ScoreListBlue;

var GFxObject 				AmmoMC;
var GFxObject 				ChatMC;
var GFxObject 				HealthMC;
var GFxObject 				ChatTextMC;

var GFxObject 				Score1MC;
var GFxObject 				Score2MC;
var GFxObject 				Progress1MC;
var GFxObject 				Progress2MC;

var string 					NewWeaponName;

var bool					bFirstConnection;
var bool					bChatting;


/*----------------------------------------------------------
	Core methods
----------------------------------------------------------*/

/*--- Connection of all controllers : frame 1 ---*/
simulated function InitParts()
{
	super.InitParts();
	
	// Get symbols
	AmmoMC = GetSymbol("Ammo");
	Banner = GetSymbol("Banner");
	ChatMC = GetSymbol("ChatBox");
	HealthMC = GetSymbol("Health");
	ChatTextMC = GetSymbol("ChatInput");
	
	Score1MC = GetSymbol("T0.Score");
	Score2MC = GetSymbol("T1.Score");
	Progress1MC = GetSymbol("T0.Progress");
	Progress2MC = GetSymbol("T1.Progress");
	
	// Various init
	ScoreListBlue.SetVisible(false);
	ScoreListRed.SetVisible(false);
	ChatTextMC.SetVisible(false);
	bCaptureInput = false;
	ChatMC.SetText("");
}


/*----------------------------------------------------------
	Game methods
----------------------------------------------------------*/

/*--- Respawn menu ---*/
reliable client simulated function OpenRespawnMenu()
{
	SetGamePaused();
	bChatting = false;
	bCaptureInput = true;
	Scene.GotoAndPlayI(2);
	Banner = GetSymbol("Banner");
	OpenPlayerList(PC.GetPlayerList());
}


/*--- Health bar ---*/
simulated function UpdateHealth(int amount)
{
	//HealthMC.GotoAndStopI(amount);
}


/*--- Ammo bar ---*/
simulated function UpdateAmmo(int amount)
{
	//AmmoMC.GotoAndStopI(amount);
}


/*--- Open chat ---*/
simulated function StartTalking()
{
	if (!bChatting)
	{
		PlayUISound(ClickSound);
		ChatTextMC.SetVisible(true);
		ChatTextMC.SetString("text", " ");
		ChatTextMC.SetBool("focused", true);
		bCaptureInput = true;
		bChatting = true;
	}
}


/*--- Open chat ---*/
simulated function SendChatMessage()
{
	local string text;
	
	bCaptureInput = false;
	if (bChatting)
	{
		PlayUISound(ClickSound);
		ChatTextMC.SetVisible(false);
		ChatTextMC.SetBool("focused", false);
		bChatting = false;
		
		text = ChatTextMC.GetString("text");
		if (text != "")
			ConsoleCommand("Say"@text);
	}
}


/*--- New chat line ---*/
simulated function UpdateChat(string text)
{
	ChatMC.SetText(text);
}


/*--- Score update ---*/
simulated function UpdateScore(int s1, int s2, int max)
{
	Score1MC.SetText("" $ s1 @ "points sur "@max);
	Score2MC.SetText("" $ s1 @ "points sur "@max);
	Progress1MC.GotoAndStopI(100.0 * float(s1 / max));
	Progress2MC.GotoAndStopI(100.0 * float(s2 / max));
}


/*--- Open the player list ---*/
reliable client function OpenPlayerList(array<DVPlayerRepInfo> PRList)
{
	`log("OpenPlayerList");
	
	ScoreListRed.SetVisible(true);
	ScoreListBlue.SetVisible(true);
	FillPlayerList(ScoreListRed, PRList, 0);
	FillPlayerList(ScoreListBlue, PRList, 1);
	
	// Button hide
	if (SwitchTeamButtonMC != None && bFirstConnection)
	{
		SwitchTeamButtonMC.SetVisible(false);
	}
}


/*--- Close the player list ---*/
reliable client function ClosePlayerList()
{
	`log("ClosePlayerList");
	ScoreListRed.SetVisible(false);
	ScoreListBlue.SetVisible(false);
}


/*--- PLayer list filling ---*/
reliable client function FillPlayerList(GFxObject List, array<DVPlayerRepInfo> PRList, byte TeamIndex)
{
	local byte i, j;
	local GFxObject TempObj;
	local GFxObject DataProvider;
	
	// Init
	j = 0;
	`log("FillPlayerList");
	DataProvider = List.GetObject("dataProvider");
	
	// Player filtering
	for (i = 0; i < PRList.Length; i++)
	{
		if (PRList[i].Team.TeamIndex == TeamIndex)
		{
			TempObj = CreateObject("Object");
			TempObj.SetString("label", PRList[i].PlayerName $ " : "$ PRList[i].KillCount $ " victimes");
			DataProvider.SetElementObject(j, TempObj);
			j++;
		}
	}
	List.SetObject("dataProvider", DataProvider);
	List.SetFloat("rowCount", j);
}


/*--- Update the weapon list ---*/
reliable client function UpdateWeaponList()
{
	local byte i;
	local GFxObject TempObj;
	local GFxObject DataProvider;
	`log("UpdateWeaponList");
	
	// Actual menu setting
	DataProvider = WeaponListMC.GetObject("dataProvider");
	for (i = 0; i < PC.WeaponListLength; i++)
	{
		TempObj = CreateObject("Object");
		TempObj.SetString("label", string(PC.WeaponList[i]));
		DataProvider.SetElementObject(i, TempObj);
	}
	
	// List update
	WeaponListMC.SetObject("dataProvider", DataProvider);
	WeaponListMC.SetFloat("rowCount", i);
	
	// Button hide
	if (bFirstConnection)
	{
		SwitchTeamButtonMC.SetVisible(false);
	}
}


/*----------------------------------------------------------
	Events
----------------------------------------------------------*/

/*--- Buttons ---*/
event bool WidgetInitialized (name WidgetName, name WidgetPath, GFxObject Widget)
{
	switch(WidgetName)
	{
		// Buttons
		case ('ExitMenu'):
			ExitButtonMC = GetLiveWidget(Widget, 'CLIK_click', OnExit);
			SetWidgetLabel("QuitMenu", "Quitter la partie", false);
			break;
		case ('Restart'):
			RestartButtonMC = GFxClikWidget(Widget);
			RestartButtonMC.SetVisible(false);
			SetWidgetLabel("Restart", "Respawn", false);
			break;
		case ('SwitchTeam'):
			SwitchTeamButtonMC = GetLiveWidget(Widget, 'CLIK_itemClick', OnSwitchTeam);
			SetWidgetLabel("SwitchTeam", "Changer d'�quipe", false);
			break;
		
		/// Lists
		case ('WeaponList'):
			WeaponListMC = GetLiveWidget(Widget, 'CLIK_itemClick', OnWeaponClick);
			UpdateWeaponList();
			break;
		case ('ScoreListRed'):
			ScoreListRed = GFxClikWidget(Widget);
			break;
		case ('ScoreListBlue'):
			ScoreListBlue = GFxClikWidget(Widget);
			break;
			
		default:
			return super.WidgetInitialized(Widgetname, WidgetPath, Widget);
	}
	return true;
}


/*--- Weapon selection ---*/
function OnWeaponClick(GFxClikWidget.EventData ev)
{
	// init
	local int i;
	local GFxObject button;
	local class<DVWeapon> NewWeapon;
	button = ev._this.GetObject("itemRenderer");
	NewWeaponName = button.GetString("label");
	
	// List data usage
	for (i = 0; i < PC.WeaponListLength; i++)
	{
		if (InStr(NewWeaponName, PC.WeaponList[i].name) != -1)
		{
			NewWeapon = PC.WeaponList[i];
		}
	}
	
	// Restart
	SetGameUnPaused();
	PC.HUDRespawn(NewWeapon);
	bCaptureInput = false;
	bFirstConnection = false;
	//SwitchTeamButtonMC.SetVisible(true);
}


/*--- Pause start ---*/
function TogglePause()
{
	SetGamePaused();
	bCaptureInput = true;
}


/*--- Pause end ---*/
function OnResume(GFxClikWidget.EventData evtd)
{
	SetGameUnPaused();
	bCaptureInput = false;
}


/*--- Change team ---*/
function OnSwitchTeam(GFxClikWidget.EventData evtd)
{
	PC.SwitchTeam();
	ConsoleCommand("quit");
}


/*--- Quit to menu ---*/
function OnExit(GFxClikWidget.EventData evtd)
{
	`log("Loading...");
	PC.SaveGameStatistics(false, true);
	ConsoleCommand("open UDKFrontEndMap?game=DVCore.DVGame_Menu");
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	// HUD Settings
	bFirstConnection = true;
	MovieInfo=SwfMovie'DV_CoreUI.HUD'
	
	// Bindings
	WidgetBindings(2)={(WidgetName="Restart",	WidgetClass=class'GFxClikWidget')}
	WidgetBindings(3)={(WidgetName="SwitchTeam",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(4)={(WidgetName="ExitMenu",	WidgetClass=class'GFxClikWidget')}
	
	WidgetBindings(5)={(WidgetName="WeaponList",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(6)={(WidgetName="ScoreListRed",WidgetClass=class'GFxClikWidget')}
	WidgetBindings(7)={(WidgetName="ScoreListBlue",WidgetClass=class'GFxClikWidget')}
}
