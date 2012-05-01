/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class DVWeaponAddon extends Actor;


/*----------------------------------------------------------
	Public attributes : new properties for attached weapons
----------------------------------------------------------*/

var (Addon) vector			ZoomOffset;

var (Addon) float			SmoothingFactor;
var (Addon) float 			ZoomSensitivity;
var (Addon) float 			ZoomedFOV;

var (Addon) float			FireRateBonus;
var (Addon) float			DamageBonus;
var (Addon) float			AmmoBonus;

var (Addon) name			MountSocket;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var StaticMeshComponent 	Mesh;


/*----------------------------------------------------------
	Methods
----------------------------------------------------------*/


/*--- Weapon attachment ---*/
simulated function AttachToWeapon(DVWeapon wp)
{
	`log("AttachToWeapon " $ self);
	if (MountSocket == '' || Mesh == None || SkeletalMeshComponent(wp.Mesh) == None)
		return;
	
	// Mesh
	AttachComponent(Mesh);
	`log("WPN (" $ Self $ ") Attaching to " $ wp);
	Mesh.SetShadowParent(wp.Mesh);
	SkeletalMeshComponent(wp.Mesh).AttachComponentToSocket(Mesh, MountSocket);
	
	// Properties override
	if (SmoothingFactor != 0.0)
		wp.SmoothingFactor = SmoothingFactor;
	if (ZoomSensitivity != 0.0)
		wp.ZoomSensitivity = ZoomSensitivity;
	if (ZoomedFOV != 0.0)
		wp.ZoomedFOV = ZoomedFOV;
	if (ZoomOffset != vect(0,0,0))
	{
		wp.ZoomSocket = MountSocket;
		wp.ZoomOffset = ZoomOffset;
	}
	
	// Bonus
	if (AmmoBonus != 0.0)
		wp.MaxAmmo *= AmmoBonus;
	if (DamageBonus != 0.0)
		wp.InstantHitDamage[0] *= DamageBonus;
	if (FireRateBonus != 0.0)
		wp.FireInterval[0] /= FireRateBonus;
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	// Lighting
	Begin Object class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
		bEnabled=true
		bDynamic=true
	End Object
	Components.Add(MyLightEnvironment)
	
	// Mesh
	Begin Object Class=StaticMeshComponent Name=AddonMesh
		LightEnvironment=MyLightEnvironment
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		bOnlyOwnerSee=false
	End Object
	Mesh=AddonMesh
	Components.Add(AddonMesh)
	
	// Properties
	MountSocket=Mount2
	SmoothingFactor=0.0
	ZoomSensitivity=0.0
	FireRateBonus=0.0
	DamageBonus=0.0
	ZoomedFOV=0.0
	AmmoBonus=0.0
}
