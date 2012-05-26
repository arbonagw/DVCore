/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVGame extends UDKGame;


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/

var (DVGame) const class<DVWeapon> 		DefaultWeaponList[8];
var (DVGame) const class<DVTurret>		DefaultTurretClass;

var (DVGame) const class<DVTeamInfo> 	TeamInfoClass;

var (DVGame) const int					WeaponListLength;
var (DVGame) const int 					MaxScore;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var class<DVWeapon>					DefaultWeapon;

var	DVTeamInfo						Teams[2];

var float							EndGameTick;
var float							RestartTimer;


/*----------------------------------------------------------
	Events
----------------------------------------------------------*/

/*--- Standard team creation ---*/
function PreBeginPlay()
{
	// Vars
	local DVTurretController DVTC;
	local DVTurretSocket PS;
	
	// Game
	super.PreBeginPlay();
	CreateTeam(0);
	CreateTeam(1);
	
	// Spawn turrets
	foreach WorldInfo.AllNavigationPoints(class'DVTurretSocket', PS)
	{
		DVTC = spawn(PS.TurretControllerClass);
		SetTeam(DVTC,Teams[PS.TeamIndex], false);
		RestartPlayer(DVTC);
	}
}


/*--- Score update ---*/
event PostBeginPlay()
{
	super.PostBeginPlay();
	SetTimer(EndGameTick, true, 'ScoreUpdated');
}


/*--- Team attribution ---*/
event PostLogin (PlayerController NewPlayer)
{
	local Actor A;
	local DVPlayerController P;
	Super.PostLogin(NewPlayer);
	
	DVPlayerController(NewPlayer).SetWeaponList(DefaultWeaponList, WeaponListLength);
	
	if (LocalPlayer(NewPlayer.Player) == None)
		return;
	
	foreach AllActors(class'Actor', A)
		A.NotifyLocalPlayerTeamReceived();
	
	foreach AllActors(class'DVPlayerController', P)
	{
		if (P != NewPlayer)
			P.ServerNotifyNewPlayer(DVPlayerController(NewPlayer).GetPlayerName());
	}
	DVPlayerController(NewPlayer).MaxScore = MaxScore;
	DVPlayerController(NewPlayer).StartMusicIfAvailable();
}


/*----------------------------------------------------------
	Methods
----------------------------------------------------------*/

/*--- Spawning weapon management ---*/
function AddDefaultInventory(Pawn PlayerPawn)
{
	local class<DVWeapon> Choiced;
	
	`log("AddDefaultInventory for " $ PlayerPawn);
	if (PlayerPawn.Controller != None)
	{
		Choiced = DVPlayerController(PlayerPawn.Controller).UserChoiceWeapon;
		if (Choiced != None)
		{
			PlayerPawn.CreateInventory(Choiced);
		}
	}
	else
	{
		`log("Spawned default weapon, this is wrong.");
		PlayerPawn.CreateInventory(DefaultWeapon);
	}
	PlayerPawn.AddDefaultInventory();
}


/*--- Get the default class for pawns ---*/
function class<Pawn> GetDefaultPlayerClass(Controller C)
{
	if (C.IsA('DVTurretController'))
		return DefaultTurretClass;
	else
		return DefaultPawnClass;
}


/*--- Stub ---*/
function ScoreUpdated()
{
	// Init
	local int S0, S1;
	S0 = Teams[0].GetScore();
	S1 = Teams[1].GetScore();
	
	// Victory
	if (S0 >= MaxScore || S1 >= MaxScore)
	{
		GameEnded( (S0 > S1) ? 0 : 1);
	}
}


/*--- Game end ---*/
function GameEnded(byte WinnerIndex)
{
	local DVPlayerController PC;
	local bool bIsWinner;
	
	ForEach AllActors(class'DVPlayerController', PC)
	{
		bIsWinner = CheckForWin(PC, WinnerIndex);
		PC.SignalEndGame(bIsWinner);
	}
	
	ClearTimer('ScoreUpdated');
	SetTimer(RestartTimer, false, 'RestartGame');
}


/*--- Is this controller the winner ? ---*/
simulated function bool CheckForWin(DVPlayerController PC, byte WinnerIndex)
{
	return (PC.GetTeamIndex() == WinnerIndex);
}


/*--- Killed set ---*/
function ScoreKill(Controller Killer, Controller Other)
{
	// Init
	local DVPlayerRepInfo KillerPRI, OtherPRI;
	local bool bIsTeamKill;
	KillerPRI = DVPlayerRepInfo(Killer.PlayerReplicationInfo);
	OtherPRI = DVPlayerRepInfo(Other.PlayerReplicationInfo);
	
	// Score kill
	if (KillerPRI != None)
	{
		// Team kill data
		if (KillerPRI.Team != None && DVPlayerController(Other) != None)
			bIsTeamKill = (
					DVPlayerController(Killer).GetTeamIndex()
				 == DVPlayerController(Other).GetTeamIndex()
			);
		else
			bIsTeamKill = false;
		
		// Kill indication to player
		if (OtherPRI != KillerPRI)
		{
			KillerPRI.ScorePoint(bIsTeamKill);
		}
		DVPlayerController(Other).ShowKilledBy(KillerPRI.PlayerName);
		`log(Other $ " KilledBy " $ KillerPRI $ ", isTK=" $ bIsTeamKill);
	}
	
	// Death indication to other player
	if (OtherPRI != None)
	{
		if (OtherPRI != KillerPRI)
		{
			DVPlayerController(Killer).ShowKilled(OtherPRI.PlayerName, bIsTeamKill);
		}
		OtherPRI.ScoreDeath();
	}
}


/*--- Player start determination ---*/
function PlayerStart ChoosePlayerStart(Controller Player, optional byte InTeam)
{
	local array<PlayerStart> PlayerStarts;
	local PlayerStart 		P, BestStart;
	local float 			BestRating, NewRating;
	local int 				i, RandStart;

	// All player starts
	foreach WorldInfo.AllNavigationPoints(class'PlayerStart', P)
	{
		if (P.bEnabled && (Player.IsA('DVTurretController') == P.IsA('DVTurretSocket')))
			PlayerStarts[PlayerStarts.Length] = P;
	}
	RandStart = Rand(PlayerStarts.Length);

	// Random points : end part
	for (i = RandStart; i < PlayerStarts.Length; i++)
	{
		P = PlayerStarts[i];
		if (!CheckIfOK(P))
			continue;
		NewRating = RatePlayerStart(P, InTeam, Player);
		
		if ( NewRating >= 30 )
			return P;
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = P;
		}
	}
	
	// Random points : start part
	for ( i = 0; i < RandStart; i++)
	{
		P = PlayerStarts[i];
		if (!CheckIfOK(P))
			continue;
		NewRating = RatePlayerStart(P, InTeam, Player);
		
		if ( NewRating >= 30 )
			return P;
		if ( NewRating > BestRating )
		{
			BestRating = NewRating;
			BestStart = P;
		}
	}
	return BestStart;
}


/*--- Rate a player start so that we don't do stupid things ---*/
function bool CheckIfOK(PlayerStart PS)
{
	local Controller P;
	
	foreach WorldInfo.AllControllers(class'Controller', P)
	{
		if (P.bIsPlayer && (P.Pawn != None))
		{
			if ((Abs(PS.Location.Z - P.Pawn.Location.Z) < PS.CylinderComponent.CollisionHeight + P.Pawn.CylinderComponent.CollisionHeight)
				&& (VSize2D(PS.Location - P.Pawn.Location) < PS.CylinderComponent.CollisionRadius + P.Pawn.CylinderComponent.CollisionRadius) )
			{
				return false;
			}
		}
	}
	return true;
}


/*---Team attribution ---*/
function SetTeam(Controller Other, DVTeamInfo NewTeam, bool bNewTeam)
{
	local Actor A;

	// Init
	if ( Other.PlayerReplicationInfo == None )
		return;
	if (Other.PlayerReplicationInfo.Team != None || !ShouldSpawnAtStartSpot(Other))
		Other.StartSpot = None;

	// Team removal
	if ( Other.PlayerReplicationInfo.Team != None )
	{
		Other.PlayerReplicationInfo.Team.RemoveFromTeam(Other);
		Other.PlayerReplicationInfo.Team = none;
	}
	
	// Team setting
	if ( NewTeam == None || (NewTeam != None && NewTeam.AddToTeam(Other)) )
	{
		if ( (NewTeam!=None) && ((WorldInfo.NetMode != NM_Standalone) || (PlayerController(Other) == None) || (PlayerController(Other).Player != None)) )
			BroadcastLocalizedMessage( GameMessageClass, 3, Other.PlayerReplicationInfo, None, NewTeam );
	}
	if ( (PlayerController(Other) != None) && (LocalPlayer(PlayerController(Other).Player) != None) )
	{
		ForEach AllActors(class'Actor', A)
		{
			A.NotifyLocalPlayerTeamReceived();
		}
	}
	
	// Enemy team
	if (NewTeam.TeamIndex == 0)
		DVPlayerController(Other).SetEnemyTeamInfo(Teams[1]);
	else
		DVPlayerController(Other).SetEnemyTeamInfo(Teams[0]);
}


/*--- Pick a team ! ---*/
function byte PickTeam(byte num, Controller C)
{
	if (Teams[0].Size > Teams[1].Size)
		return 1;
	else
		return 0;
}


/*--- Team storage ---*/
function CreateTeam(int TeamIndex)
{
	Teams[TeamIndex] = spawn(TeamInfoClass);
	Teams[TeamIndex].Initialize(TeamIndex);
	GameReplicationInfo.SetTeam(TeamIndex, Teams[TeamIndex]);
}


/*--- Changing teams ---*/
function bool ChangeTeam(Controller Other, int num, bool bNewTeam)
{
	`log("ChangeTeam "$ Other $" "$ num $" "$ bNewTeam);
	SetTeam(Other, Teams[num], bNewTeam);
	return true;
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	// Settings
	bTeamGame=true
	EndGameTick=0.5
	
	// Classes
	HUDType=class'DVHUD'
	DefaultPawnClass=class'DVPawn'
	TeamInfoClass=class'DVCore.DVTeamInfo'
	PlayerControllerClass=class'DVPlayerController'
	PlayerReplicationInfoClass=class'DVCore.DVPlayerRepInfo'
}
