/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class GButton extends GLabel
	placeable;


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/

var (Button) bool					bIsToggle;

var (Button) const float			ClickTimeout;

var (Button) const vector			EffectLoc;

var (Button) const rotator			EffectRot;

var (Button) const ParticleSystem	Effect;

var (Button) const SoundCue 		ClickSound;


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/

var bool							bIsActive;
var bool							bClicking;

var delegate<PressCB>				PressEvent;


/*----------------------------------------------------------
	Public methods
----------------------------------------------------------*/

/**
 * @brief Method definition for press event callbacks
 * @param Reference				Caller actor
 */
delegate PressCB(Actor Caller)
{
	`log(Caller @"was clicked");
}

/**
 * @brief Register the button callback
 * @param CB				Press callback
 */
simulated function SetPress(delegate<PressCB> CB)
{
	PressEvent = CB;
}

/**
 * @brief Set the button state
 * @param bNewState			New state to set
 */
simulated function SetState(bool bNewState)
{
	if (bEnabled)
	{
		bIsActive = bNewState;
		if (Effect != None && WorldInfo.NetMode != NM_DedicatedServer)
		{
			WorldInfo.MyEmitterPool.SpawnEmitter(
				Effect,
				EffectLoc >> Rotation,
				EffectRot + Rotation
			);
		}
	}
}

/**
 * @brief Set the button behaviour on click
 * @param bShouldToggle		true if button should keep its state
 */
simulated function SetToggleMode(bool bShouldToggle)
{
	bIsToggle = bShouldToggle;
}

/**
 * @brief Get the button state
 * @return					true if on
 */
simulated function bool GetState()
{
	return bIsActive;
}

/**
 * @brief Signal a press event from HUD
 * @param					true if right click (false if left)
 */
simulated function Press(bool bIsRightClick)
{
	`log("GB > Press" @bIsRightClick @Text);
	bClicking = true;
	ClearTimer('PressTimeout');
	SetTimer(ClickTimeout, false, 'PressTimeout');
}

/**
 * @brief Signal a release event from HUD
 * @param					true if right click (false if left)
 */
simulated function Release(bool bIsRightClick)
{
	if (bEnabled)
	{
		`log("GB > Release" @bIsRightClick @Text);
		if (bClicking)
		{
			bClicking = false;
			if (bIsToggle)
			{
				SetState(!bisActive);
			}
			if (!bIsRightClick)
			{
				PressEvent(self);
			}
		}
		ClearTimer('PressTimeout');
		PlayUISound(ClickSound);
	}
}


/*----------------------------------------------------------
	Private methods
----------------------------------------------------------*/

/**
 * @brief Spawn event
 */
simulated function PostBeginPlay()
{
	super.PostBeginPlay();
	SetPress(PressCB);
}

/**
 * @brief Click has failed
 */
simulated function PressTimeout()
{
	bClicking = false;
}


/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
	// Behaviour
	ClickMove=(X=0,Y=10,Z=0)
	bIsToggle=false
	bClicking=false
	ClickTimeout=1.0
	OverSound=SoundCue'DV_Sound.UI.A_Click'
	ClickSound=SoundCue'DV_Sound.UI.A_Bip'
	
	// Text
	TextOffsetX=30.0
	TextOffsetY=670.0
	
	// Mesh
	Begin Object Name=LabelMesh
		StaticMesh=StaticMesh'DV_UI.Mesh.SM_Button'
		Rotation=(Yaw=32768)
	End Object
}
