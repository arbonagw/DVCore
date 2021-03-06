/**
 *  This work is distributed under the General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVPawn extends UDKPawn;


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/

var (DVPawn) const bool				bDVLog;

var (DVPawn) const name				EyeSocket;
var (DVPawn) const name				WeaponSocket;
var (DVPawn) const name				WeaponSocket2;

var (DVPawn) const int 				AllowedBadDisplacements;

var (DVPawn) const float 			RecoilRiseTime;
var (DVPawn) const float 			RecoilLowTime;
var (DVPawn) const float 			RecoilOvershoot;

var (DVPawn) const float			TeamMultiplier;
var (DVPawn) const float 			DefaultFOV;
var (DVPawn) const float 			HeadBobbingFactor;
var (DVPawn) const float 			StandardEyeHeight;

var (DVPawn) const float			ZoomedGroundSpeed;
var (DVPawn) const float			UnzoomedGroundSpeed;
var (DVPawn) const float 			MaxWorldDisplacement;

var (DVPawn) const float			SprintDamagePeriod;
var (DVPawn) const float			SprintDamage;
var (DVPawn) const float			HeadshotMultiplier;
var (DVPawn) const float			JumpDamageMultiplier;
var (DVPawn) const float			DeathFlickerFrequency;

var (DVPawn) const LinearColor		OffLight;

var (DVPawn) const SoundCue			FootStepSound;
var (DVPawn) const SoundCue			JumpSound;
var (DVPawn) const SoundCue			HitSound;

var (DVPawn) const ParticleSystem	HitPSCTemplate;
var (DVPawn) const ParticleSystem	LargeHitPSCTemplate;
var (DVPawn) const array<MaterialInstanceConstant> TeamMaterials;
var (DVPawn) const array<MaterialInstanceConstant> BloodDecals;

var (DVPawn) const string			ModuleName;


/*----------------------------------------------------------
	Localized attributes
----------------------------------------------------------*/

var (DVPawn) localized string		lPickedUp;
var (DVPawn) localized string		lBullets;
var (DVPawn) localized string		lHealth;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var DVKillMarker					KM;
var MaterialInstanceConstant		TeamMaterial;
var DynamicLightEnvironmentComponent LightEnvironment;
var	DVWeapon						OldWeaponReference;

var repnotify LinearColor			TeamLight;
var repnotify class<DVWeapon> 		CurrentWeaponClass;

var bool							bOverDisplaced;
var bool							bRising;
var bool							bRunning;
var bool 							bWasHS;
var bool							bZoomed;
var bool							bJumping;
var bool							bHasGotTeamColors;

var string			 				KillerName;
var string							UserName;

var int								BadDisplacements;

var vector							LastLocation;

var float							FeignDeathStartTime;

var float 							CurrentRecoilTime;
var float 							CurrentRecoilOffset;


/*----------------------------------------------------------
	Replication
----------------------------------------------------------*/

replication
{
	if ( bNetDirty )
		CurrentWeaponClass, UserName, KillerName, bWasHS, TeamLight, KM, bJumping, bRunning, BadDisplacements;
}

simulated event ReplicatedEvent(name VarName)
{	
	// Weapon class
	if ( VarName == 'CurrentWeaponClass' )
	{
		WeaponClassChanged();
		return;
	}
	// Team color
	if ( VarName == 'TeamLight')
	{
		if (PlayerReplicationInfo.Team != None)
			UpdateTeamColor(GetTeamIndex());
		return;
	}
	else
	{
		Super.ReplicatedEvent(VarName);
	}
}


/*----------------------------------------------------------
	Methods
----------------------------------------------------------*/

/*--- Initial setup ---*/
function PostBeginPlay()
{
	super.PostBeginPlay();
	ServerLogAction("IPOS");
	SetTimer(1.0, true, 'LogPosition');
	SetRunning(false);
}


/*--- Position logging ---*/
simulated function LogPosition()
{
	ServerLogAction("POS");
}


/*--- Team replication event ---*/
simulated function NotifyTeamChanged()
{
	if (!bHasGotTeamColors)
	{
		UpdateTeamColor(DVPlayerRepInfo(PlayerReplicationInfo).Team.TeamIndex);
		bHasGotTeamColors = true;
	}
}


/*--- Material setup ---*/
simulated function UpdateTeamColor(byte TeamIndex)
{
	if(TeamMaterials[TeamIndex] != None)
	{
		TeamMaterial = Mesh.CreateAndSetMaterialInstanceConstant(0);
		
		if (TeamMaterial != None)
		{
			TeamMaterial.SetParent(TeamMaterials[TeamIndex]);
			TeamMaterial.GetVectorParameterValue('LightColor', TeamLight);
		}
	}
}


/*--- Team ID ---*/
simulated function byte GetTeamIndex()
{
	if (PlayerReplicationInfo != None)
		return DVPlayerRepInfo(PlayerReplicationInfo).Team.TeamIndex;
	else
		return 0;
}


/*--- Init ---*/
simulated event PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
	if (SkelComp == Mesh)
	{
		AimNode = AnimNodeAimOffset(mesh.FindAnimNode('AimNode'));
		LeftHandIK = SkelControlLimb(mesh.FindSkelControl('LeftHandIK'));
		RightHandIK = SkelControlLimb(mesh.FindSkelControl('RightHandIK'));
		RootRotControl = SkelControlSingleBone(mesh.FindSkelControl('RootRot'));
		FlyingDirOffset = AnimNodeAimOffset(mesh.FindAnimNode('FlyingDirOffset'));
		GunRecoilNode = GameSkelCtrl_Recoil(mesh.FindSkelControl('GunRecoilNode'));
		LeftRecoilNode = GameSkelCtrl_Recoil(mesh.FindSkelControl('LeftRecoilNode'));
		RightRecoilNode = GameSkelCtrl_Recoil(mesh.FindSkelControl('RightRecoilNode'));
		LeftLegControl = SkelControlFootPlacement(Mesh.FindSkelControl(LeftFootControlName));
		RightLegControl = SkelControlFootPlacement(Mesh.FindSkelControl(RightFootControlName));
	}
}


/*--- Bumped ---*/
event Bump(Actor Other, PrimitiveComponent OtherComp, Vector HitNormal)
{
	BadDisplacements = 0;
}


/*--- Replicated weapon switch ---*/
simulated function WeaponClassChanged()
{
	if (Mesh != None && (Weapon == None || Weapon.Class != CurrentWeaponClass))
	{
		if (Weapon != None)
		{
			`log("DVP > Destroyed " $ Weapon);
			DVWeapon(Weapon).DetachFrom(Mesh);
			Weapon.Destroy();
			Weapon = None;
		}

		if (CurrentWeaponClass != None)
		{
			Weapon = Spawn(CurrentWeaponClass, self);
			Weapon.Instigator = self;
			`log("DVP > Spawned " $ Weapon);
		}
	}
	AimNode.SetActiveProfileByName('ShoulderRocket');
	WeaponChanged(DVWeapon(Weapon));
}


/*--- Weapon attachment ---*/
simulated function WeaponChanged(DVWeapon NewWeapon)
{
	if (Mesh != None && NewWeapon.Mesh != None && Weapon != None)
	{
		DVWeapon(Weapon).AttachWeaponTo(Mesh);
	}
	OldWeaponReference = NewWeapon;
}


/*--- Weapon change ---*/
simulated function SwitchToWeapon(class<DVWeapon> WpClass)
{
	if (WorldInfo.NetMode == NM_DedicatedServer && InvManager != None)
	{
		CurrentWeaponClass = WpClass;
	}
}


/*--- Add ammo ---*/
simulated function AddWeaponAmmo(int amount)
{
	local int realAmount;
	realAmount = 0;

	if (Weapon != None)
		realAmount = Weapon.AddAmmo(amount);
	
	if (Controller != None)
		DVPlayerController(Controller).ShowGenericMessage(lPickedUp @ realAmount @ lBullets);
}


/*--- Healing ---*/
simulated function AddHealth(int amount)
{
	local DVPlayerController PC;
	PC = DVPlayerController(Controller);
	Health += amount;
	Health = Clamp (Health, 0, HealthMax);

	if (PC != None)
	{
		DVHUD(PC.myHUD).HideHit();
		PC.ShowGenericMessage(lPickedUp @ amount @ lHealth);
	}
}


/*--- Zoomed view location : socket & offset ---*/
simulated function vector GetZoomViewLocation()
{
	local DVWeapon wp;
	wp = DVWeapon(Weapon);
	if (wp != None)
		return wp.GetZoomViewLocation();
	else
		return Location;
}

/*--- Zoomed view rotation : socket ---*/
simulated function rotator GetZoomViewRotation()
{
	local DVWeapon wp;
	wp = DVWeapon(Weapon);
	if (wp != None)
		return wp.GetZoomViewRotation();
	else
		return Controller.Rotation;
}


/*--- Which zoom state ? ---*/
simulated function Vector GetPawnViewLocation()
{
	if (bZoomed)
	{
		return GetZoomViewLocation();
	}
	else
	{
		return GetEyeLocation();
	}
}


/*--- Location backend ---*/
simulated function Vector GetEyeLocation()
{
	local vector SMS;

	if (!Mesh.GetSocketWorldLocationAndrotation(EyeSocket, SMS))
		`log("DVP > GetSocketWorldLocationAndrotation GetPawnViewLocation failed ");
	SMS.Z = 	HeadBobbingFactor 	* SMS.Z +
		(1.0 - HeadBobbingFactor) 	* (Location.Z + StandardEyeHeight);
	
	return SMS;
}


/*--- Zoom management ---*/
simulated function StartZoom()
{
	bZoomed = true;
	DVWeapon(Weapon).ZoomIn();
	Mesh.GlobalAnimRateScale = (ZoomedGroundSpeed / UnzoomedGroundSpeed);
}


simulated function EndZoom()
{
	bZoomed = false;
	DVWeapon(Weapon).ZoomOut();
	Mesh.GlobalAnimRateScale = 1.0;
}


/*--- Camera status update : view calculation ---*/
simulated function bool CalcCamera(float fDeltaTime, out vector out_CamLoc, out rotator out_CamRot, out float out_FOV)
{	
	// Locked
	out_FOV = DefaultFOV;
	if (Controller == None || DVPlayerController(Controller).IsCameraLocked())
		return true;
	
	// Zoomed
	if (bZoomed && Weapon != None && Controller != None)
	{
		out_FOV = DVWeapon(Weapon).ZoomedFOV;
		out_CamLoc = GetZoomViewLocation();
		out_CamRot = GetZoomViewRotation();
		SetGroundSpeed(ZoomedGroundSpeed);
	}
	
	// Standard viewpoint
	else
	{
		out_CamLoc = GetPawnViewLocation();
		
		if (Controller != None)
			out_CamRot = Controller.Rotation;
		else
			out_CamRot = Rotation;
		SetGroundSpeed(UnzoomedGroundSpeed);
	}

	return true;
}


/*--- Speed limit setting ---*/
reliable server function SetGroundSpeed(float NewSpeed)
{
	local float OldSpeed;
	OldSpeed = GroundSpeed;
	GroundSpeed = NewSpeed;
	
	if (OldSpeed != GroundSpeed)
	{
		PlayerReplicationInfo.bForceNetUpdate = true;
	}
}

/*--- Pawn tick ---*/
simulated function Tick(float DeltaTime)
{
	local Vector Temp;
	local float Pitch;
	local float Displacement;
	local rotator RecoilOffset;

	// Weapon adjustment
	if (Weapon == None)
	{
		return;
	}
	else if (!DVWeapon(Weapon).IsZoomed())
	{
		Weapon.Mesh.SetRotation(Weapon.default.Mesh.Rotation + GetSmoothedRotation());
	}

	// Recoil calculation
	if (CurrentRecoilTime >= 0.0)
	{
		if (CurrentRecoilTime < RecoilRiseTime)
		{
			bRising = true;
			Pitch = FInterpEaseInOut(
					0,
					DVWeapon(Weapon).RecoilAngle * RecoilOvershoot,
					CurrentRecoilTime / RecoilRiseTime,
					1.0
			);
			RecoilOffset.Pitch = Pitch - CurrentRecoilOffset;
		}
		else if (CurrentRecoilTime < (RecoilRiseTime + RecoilLowTime))
		{
			if (bRising && CurrentRecoilOffset > DVWeapon(Weapon).RecoilAngle * (RecoilOvershoot - 1.0))
			{
				CurrentRecoilOffset = 0.0;
				bRising = false;
			}
			Pitch = FInterpEaseInOut(
					0,
					DVWeapon(Weapon).RecoilAngle * (RecoilOvershoot - 1.0),
					(CurrentRecoilTime - RecoilRiseTime) / RecoilLowTime,
					1.0
			);
			RecoilOffset.Pitch = abs(Pitch - CurrentRecoilOffset);
		}
		else
		{
			RecoilOffset.Pitch = 0;
			CurrentRecoilTime = -1.0;
		}

		// Apply recoil
		if (Controller != None && RecoilOffset.Pitch != 0)
		{
			if (CurrentRecoilTime < RecoilRiseTime)
			{
				Controller.SetRotation(Controller.Rotation + RecoilOffset);
			}
			else if (CurrentRecoilTime < (RecoilRiseTime + RecoilLowTime))
			{
				Controller.SetRotation(Controller.Rotation - RecoilOffset);
			}
			CurrentRecoilOffset = RecoilOffset.Pitch;
		}
		CurrentRecoilTime += DeltaTime;
	}

	// Run stop
	if ((Health <= SprintDamage || Velocity == Vect(0,0,0)) && bRunning)
	{
		SetRunning(false);
	}
	bIsWalking = bRunning;

	// Displacement check
	Temp = Location - LastLocation;
	Temp.Z = 0;
	Displacement = (VSize(Temp) / DeltaTime);

	if (Displacement > MaxWorldDisplacement && bOverDisplaced)
	{
		if (BadDisplacements > 0)
		{
			`log("DVP > Bad displacement" @BadDisplacements @Displacement);
		}
		BadDisplacements++;
		if (BadDisplacements > AllowedBadDisplacements)
		{
			KilledBy(self);
		}
	}
	bOverDisplaced = (Displacement > MaxWorldDisplacement);
	LastLocation = Location;
}


/*--- Movement smoothing for regulation ---*/
simulated function rotator GetSmoothedRotation()
{
	// Init
	local rotator SmoothRot, CurRot, BaseAim;
	local vector CurLoc;
	local float SmoothingFactor;
	
	// Bone rotation (measure)
	SmoothingFactor = DVWeapon(Weapon).SmoothingFactor;
	if (Mesh == None)
	{
		return rotator(vect(0, 0, 0));
	}
	BaseAim = GetBaseAimRotation();
	SmoothingFactor = DVWeapon(Weapon).SmoothingFactor;
	Mesh.GetSocketWorldLocationAndRotation(WeaponSocket, CurLoc, CurRot);

	// Smoothing calculation
	SmoothRot.Pitch = (BaseAim.Roll - CurRot.Roll) * SmoothingFactor;
	SmoothRot.Yaw = (BaseAim.Yaw - CurRot.Yaw) ;
	SmoothRot.Roll = (CurRot.Pitch - GetCorrectedFloat(BaseAim.Pitch)) * SmoothingFactor;
	
	// Final checks
	if (abs(GetCorrectedFloat(BaseAim.Pitch)) > 12000)
		return rotator(vect(0, 0, 0));
	else
		return SmoothRot;
}


/*--- More really curious things. ---*/
simulated function int GetCorrectedFloat(int input)
{
	input = input % 65536;
	if (input < -32768)
		return input + 65536;
	else if (input <= 32768)
		return input;
	else
		return (input - 65536);
}


/*--- Jump management ---*/
function bool DoJump( bool bUpdating )
{
	bJumping = true;
	ServerLogAction("JUMP");
	return super.DoJump(bUpdating);
}


/*--- Jump end ---*/
event Landed(vector HitNormal, Actor FloorActor)
{
	super.Landed(HitNormal, FloorActor);
	bJumping = false;
	ServerLogAction("LAND");
	PlaySound(JumpSound, false, true, false, Location);
}


/*--- Damage multiplier when jumping ---*/
simulated function float GetJumpingFactor()
{
	return (bJumping ? JumpDamageMultiplier : 1.0);
}


/*--- Running ? ---*/
reliable client simulated function SetRunning(bool status)
{
	if (status && Health > SprintDamage)
	{
		bRunning = true;
		Mesh.GlobalAnimRateScale = WalkingPct;
		TakeRunningDamage();
		ClearTimer('TakeRunningDamage');
		SetTimer(SprintDamagePeriod, true, 'TakeRunningDamage');
	}
	if (!status)
	{
		bRunning = false;
		Mesh.GlobalAnimRateScale = 1.0;
		ClearTimer('TakeRunningDamage');
		DVPlayerController(Controller).bRun = 0;
	}
	bForceNetUpdate = true;
}


/* Running is painful */
reliable client simulated function TakeRunningDamage()
{
	HurtSprint();
	ServerHurtSprint();
	if (Health <= SprintDamage)
	{
		SetRunning(false);
	}
	bForceNetUpdate = true;
}


/*--- Hurt ---*/
reliable client simulated function HurtSprint()
{
	if (Health > SprintDamage)
	{
		TakeDamage(SprintDamage, Controller, Location, vect(0, 0, 0), class'DamageType');
	}
}
reliable server simulated function ServerHurtSprint()
{
	if (Health > SprintDamage)
	{
		TakeDamage(SprintDamage, Controller, Location, vect(0, 0, 0), class'DamageType');
	}
}


/*--- Addon status update ---*/
reliable client simulated function bool GetAddonStatus()
{
	if (PlayerReplicationInfo == None) return false;
	return DVPlayerRepInfo(PlayerReplicationInfo).bUseAddon;
}

reliable server simulated function SetAddonStatus(bool NewStatus)
{
	DVPlayerRepInfo(PlayerReplicationInfo).SetAddonState(NewStatus);
}


/*--- Camera lock getter ---*/
reliable server simulated function bool ServerIsCameraLocked()
{
	if (Controller != None)
		return DVPlayerController(Controller).IsCameraLocked();
	else
		return false;
}


/*--- Set ragdoll on/off ---*/
simulated function SetPawnRBChannels(bool bRagdollMode)
{
	if(bRagdollMode)
	{
		Mesh.SetRBChannel(RBCC_Pawn);
		Mesh.SetRBCollidesWithChannel(RBCC_Default,true);
		Mesh.SetRBCollidesWithChannel(RBCC_Pawn,true);
		Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,true);
		Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,false);
		Mesh.SetRBCollidesWithChannel(RBCC_BlockingVolume,true);
	}
	else
	{
		Mesh.SetRBChannel(RBCC_Untitled3);
		Mesh.SetRBCollidesWithChannel(RBCC_Default,false);
		Mesh.SetRBCollidesWithChannel(RBCC_Pawn,false);
		Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,false);
		Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,true);
		Mesh.SetRBCollidesWithChannel(RBCC_BlockingVolume,true);
	}
}


/*--- Mesh settings ---*/
simulated function HideMesh(bool Invisible)
{
    if ( LocalPlayer(PlayerController(Controller).Player) != None )
    {
    	if (Weapon != None)
    	{
    		Weapon.Mesh.SetHidden(Invisible);
    		SetAddonStatus(false);
    	}
        Mesh.SetHidden(Invisible);
    }
}


/*--- Fire started ---*/
simulated function StartFire(byte FireModeNum)
{
	if (FireModeNum == 1)
		StartZoom();
	else
	{
		super.StartFire(FireModeNum);
	}
}


/*--- Fire ended ---*/
simulated function StopFire(byte FireModeNum)
{	
	if (FireModeNum == 1)
		EndZoom();
	else
		super.StopFire(FireModeNum);
}


/*--- Weapon fire effects ---*/
simulated function WeaponFired(Weapon InWeapon, bool bViaReplication, optional vector HitLocation)
{
	if (Weapon != None)
	{
		DVWeapon(Weapon).PlayFiringEffects(HitLocation);
		if ( HitLocation != Vect(0,0,0) && (WorldInfo.NetMode == NM_ListenServer || WorldInfo.NetMode == NM_Standalone || bViaReplication) )
		{
			DVWeapon(Weapon).PlayImpactEffects(HitLocation);
		}
		CurrentRecoilTime = 0.0;
		CurrentRecoilOffset = 0.0;
		//GunRecoilNode.bPlayRecoil = true;
	}
}


/* -- Triggers PS effect --*/
simulated function FireParticleSystem(ParticleSystem ps, vector loc, rotator rot)
{
	if (WorldInfo.NetMode != NM_DedicatedServer)
	{
		WorldInfo.MyEmitterPool.SpawnEmitter(ps, loc, rot);
	}
}


/* -- Foot sound --*/
event PlayFootStepSound(int FootDown)
{
	PlaySound(FootStepSound, false, true, false, Location);
}


/*--- Damage management for blood FX ---*/
simulated event TakeDamage(int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
	local vector EndTrace, BloodImpact, BloodNormal;
	local vector ApplyImpulse, ShotDir;
	local DVPlayerController Attacker;
	local Actor SplatteredActor;
	local DVPawn P;

	// Jumping multiplication & kill marker settings
	if (InstigatedBy != None)
	{
		Attacker = DVPlayerController(InstigatedBy);
		if (Attacker != None)
		{
			if (KillerName == "")
			{
				KillerName = Attacker.GetPlayerName();
				bForceNetUpdate = true;
			}
			if (Attacker.Pawn != None)
				Damage *= DVPawn(Attacker.Pawn).GetJumpingFactor();
		}

		// Team damage
		if (GetTeamIndex() == Attacker.GetTeamIndex() && InstigatedBy != Controller)
		{
			Damage = int(TeamMultiplier * float(Damage));
		}
	}
	if (Controller != None && UserName == "")
	{
		UserName = DVPlayerController(Controller).GetPlayerName();
		bForceNetUpdate = true;
	}
	
	// Headshot management
	if (HitInfo.BoneName == 'b_Head' || HitInfo.BoneName == 'b_Neck')
	{
		bWasHS = true;
		Damage *= HeadshotMultiplier;
	}
	else bWasHS = false;

	// Logging
	ServerLogAction("HIT");
	if (InstigatedBy != None && bWasHs)
	{
		DVPlayerController(Controller).ClientSignalHeadshot(InstigatedBy);
	}
	
	// Blood impact
	EndTrace = HitLocation + Normal(Momentum) * 1000.0;
	SplatteredActor = Trace(BloodImpact, BloodNormal, EndTrace, HitLocation, true,,,TRACEFLAG_Bullet);
	if (SplatteredActor != None && !bRunning)
	{
		foreach WorldInfo.AllPawns(class'DVPawn', P)
		{
			P.ClientSpawnBloodDecal(BloodImpact, BloodNormal);
		}
		bForceNetUpdate = true;
	}
	FireParticleSystem(HitPSCTemplate, HitLocation, rotator(Momentum));
	
	// Physics
	shotDir = Normal(Momentum);
	ApplyImpulse = (DamageType.Default.KDamageImpulse * shotDir);
	if(Velocity.Z > -10)
	{
		ApplyImpulse += Vect(0,0,1) * DamageType.default.KDeathUpKick;
	}
	Mesh.WakeRigidBody();
	Mesh.AddImpulse(ApplyImpulse, HitLocation, HitInfo.BoneName, true);
	
	// UI
	if (DVPlayerController(Controller).myHUD != None)
	{
		DVHUD(DVPlayerController(Controller).myHUD).ShowHit();
	}
	if (HitSound != None && !bRunning)
	{
		PlaySound(HitSound, false, true, false, Location);
	}
	
	Super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
}


/*--- Spawn a blood decal ---*/
reliable client simulated function ClientSpawnBloodDecal(vector BLocation, vector BRotation)
{
	// Vars
	local MaterialInstanceConstant DecalTemplate;
	local MaterialInstanceConstant Decal;
	local float DecalSize;
	
	/*--- Random settings ---*/
	if (WorldInfo.NetMode == NM_DedicatedServer)
	{
		return;
	}
	DecalSize = FRand() * 200.0;
	DecalTemplate = BloodDecals[Rand(BloodDecals.Length)];
	
	/*--- Actual settings ---*/
	Decal = new(Outer) class'MaterialInstanceConstant';
	Decal.SetParent(DecalTemplate);
	WorldInfo.MyDecalManager.SpawnDecal(
		Decal,
		BLocation,
		rotator(-BRotation),
		DecalSize, DecalSize, 100, false,,, true, false
	);
}


/*--- Death aftermath ---*/
simulated function PlayDying(class<DamageType> DamageType, vector HitLoc)
{
	local vector ApplyImpulse, ShotDir;
	local TraceHitInfo HitInfo;

	bTearOff = true;
	bPlayedDeath = true;
	bCanTeleport = false;
	TakeHitLocation = HitLoc;
	HitDamageType = DamageType;
	bReplicateMovement = false;
	
	// Weapon
	`log("DVP > PlayDying");
	if (OldWeaponReference != None)
	{
		OldWeaponReference.DetachFrom(Mesh);
		OldWeaponReference.Destroy();
	}
	
	if (WorldInfo.NetMode == NM_DedicatedServer)
	{
		GotoState('Dying');
		return;
	}

	CheckHitInfo(HitInfo, Mesh, Normal(TearOffMomentum), TakeHitLocation );
	bBlendOutTakeHitPhysics = false;
	SetHandIKEnabled(false);

	if (Physics == PHYS_RigidBody)
	{
		setPhysics(PHYS_Falling);
	}

	PreRagdollCollisionComponent = CollisionComponent;
	CollisionComponent = Mesh;

	Mesh.MinDistFactorForKinematicUpdate = 0.f;
	Mesh.ForceSkelUpdate();
	Mesh.UpdateRBBonesFromSpaceBases(true, true);
	Mesh.PhysicsWeight = 1.0;
	
	SetPhysics(PHYS_RigidBody);
	Mesh.PhysicsAssetInstance.SetAllBodiesFixed(false);
	SetPawnRBChannels(true);
	
	// Momentum
	if(TearOffMomentum != vect(0,0,0))
	{
		ShotDir = normal(TearOffMomentum);
		ApplyImpulse = ShotDir * DamageType.default.KDamageImpulse;

		if ( Velocity.Z > -10 )
		{
			ApplyImpulse += Vect(0,0,1)*DamageType.default.KDeathUpKick;
		}
		Mesh.AddImpulse(ApplyImpulse, TakeHitLocation, HitInfo.BoneName, true);
	}
	
	GotoState('Dying');
}


/*--- Standard log procedure ---*/
reliable server simulated function ServerLogAction(string event)
{
	if ((WorldInfo.NetMode == NM_DedicatedServer || WorldInfo.NetMode == NM_Standalone) && bDVLog)
	{
		`log("DVL/"
			$event $"/" $self 
			$"/X/" $Location.Y
			$"/Y/" $Location.X 
			$"/Z/" $Location.Z 
			$"/EDL"
		);
	}
}


/*----------------------------------------------------------
	States
----------------------------------------------------------*/

/*--- Just before dying ---*/
simulated State Dying
{
	ignores OnAnimEnd, Bump, HitWall, PhysicsVolumeChange, Falling, FellOutOfWorld;

	/*-- Corpse apparition ---*/
	simulated function BeginState(Name PreviousStateName)
	{
		Super.BeginState(PreviousStateName);
		if ( Mesh != None )
		{
			Mesh.SetTraceBlocking(true, true);
			Mesh.SetActorCollision(true, false);
			Mesh.SetTickGroup(TG_PostAsyncWork);
		}
		SetTimer(30.0, false);
		
		// Logging
		ServerLogAction("DIED");
	}
	
	event bool EncroachingOn(Actor Other)
	{
		return false;
	}
	
	/*--- Marker movement logic ---*/
	simulated function Tick(float DeltaTime)
	{
		// Marker
		if (KM != None)
			KM.SetLocation(Location);
	}
	
	/*-- Corpse removal ---*/
	event Timer()
	{
		Destroy();
	}
	
	/*-- Corpse damage ---*/
	simulated event TakeDamage(int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
	{
		local Vector shotDir, ApplyImpulse;

		CheckHitInfo( HitInfo, Mesh, Normal(Momentum), HitLocation );

		if (Role == ROLE_Authority && InstigatedBy != None && Controller != None)
		{
			FireParticleSystem(LargeHitPSCTemplate, HitLocation, rotator(Momentum));
		}

		if( (Physics != PHYS_RigidBody) || (Momentum == vect(0,0,0)) || (HitInfo.BoneName == '') )
			return;

		shotDir = Normal(Momentum);
		ApplyImpulse = (DamageType.Default.KDamageImpulse * shotDir);

		if(Velocity.Z > -10)
		{
			ApplyImpulse += Vect(0,0,1) * DamageType.default.KDeathUpKick;
		}
		Mesh.WakeRigidBody();
		Mesh.AddImpulse(ApplyImpulse, HitLocation, HitInfo.BoneName, true);
	}
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	// I can has light
	Begin Object class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
		bUseBooleanEnvironmentShadowing=true
		bIsCharacterLightEnvironment=true
		bSynthesizeSHLight=true
		bEnabled=true
		bDynamic=true
	End Object
	Components.Add(MyLightEnvironment)
	LightEnvironment=MyLightEnvironment
	
	// Main mesh
	Begin Object class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		bHasPhysicsAssetInstance=true
		bPerBoneMotionBlur=true
		BlockZeroExtent=true
		BlockRigidBody=true
		CollideActors=true
		Rotation=(Yaw=-16384)
		Scale=2.0
	End Object
	Mesh=SkeletalMeshComponent0
	Components.Add(SkeletalMeshComponent0)

	// Cylinder
	Begin Object Name=CollisionCylinder
		CollisionRadius=40.0
		CollisionHeight=100.0
		BlockZeroExtent=false
	End Object
	CylinderComponent=CollisionCylinder
	CollisionComponent=CollisionCylinder
	
	// Blood
	BloodDecals(0)=MaterialInstanceConstant'DV_CoreEffects.Material.MI_Blood1'
	BloodDecals(1)=MaterialInstanceConstant'DV_CoreEffects.Material.MI_Blood2'
	BloodDecals(2)=MaterialInstanceConstant'DV_CoreEffects.Material.MI_Blood3'
	
	// Weapons
	TeamMultiplier=0.2
	EyeSocket=EyeSocket
	WeaponSocket=WeaponPoint
	WeaponSocket2=DualWeaponPoint
	InventoryManagerClass=class'DVCore.DVInventoryManager'
	HitPSCTemplate=ParticleSystem'DV_CoreEffects.FX.PS_BloodHit'
	LargeHitPSCTemplate=ParticleSystem'DV_CoreEffects.FX.PS_BloodHit_Large'
	
	// Recoil
	RecoilRiseTime=0.1
	RecoilLowTime=0.3
	RecoilOvershoot=1.5

	// Gameplay
	MaxWorldDisplacement=2000
	AllowedBadDisplacements=10
	bDVLog=false
	bWasHS=false
	bZoomed=false
	bJumping=false
	bCanCrouch=false
	bLimitFallAccel=true
	bHasGotTeamColors=false
	bAlwaysEncroachCheck=true
	
	// Default
	UserName=""
	KillerName=""
	SprintDamagePeriod=0.5
	SprintDamage=4.0
	WalkingPct=1.5
	DefaultFOV=85
	OffLight=(R=0.0,G=0.0,B=0.0,A=0.0)
}
