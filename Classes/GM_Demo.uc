/**
 *  This work is distributed under the Lesser General Public License,
 *	see LICENSE for details
 *
 *  @author Gwenna�l ARBONA
 **/

class GM_Demo extends GMenu
	placeable
	ClassGroup(DeepVoid)
	hidecategories(Collision, Physics, Attachment);


/*----------------------------------------------------------
	Public attributes
----------------------------------------------------------*/


/*----------------------------------------------------------
	Private attributes
----------------------------------------------------------*/


/*----------------------------------------------------------
	Button callbacks
----------------------------------------------------------*/

/**
 * @brief Method definition for press event callbacks
 * @param Reference				Caller actor
 */
delegate GoVoid(Actor Caller)
{
	`log(Caller @"was clicked");
}


/*----------------------------------------------------------
	Private methods
----------------------------------------------------------*/

/**
 * @brief Spawn event
 */
simulated function PostBeginPlay()
{
	local GButton fire;
	super.PostBeginPlay();
	
	fire = Spawn(class'GToggleButton', self, , Location + (Vect(0,0,100) >> Rotation));
	fire.Set("FIRE", "There is a fire...");
	fire.SetPress(GoVoid);
	fire.SetRotation(Rotation);
}

/*----------------------------------------------------------
	Properties
----------------------------------------------------------*/

defaultproperties
{
}
