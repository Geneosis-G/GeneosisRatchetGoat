class ClankNpc extends GGNpcGTwo;

function string GetActorName()
{
	return "Clank";
}

function int GetScore()
{
	return 42;
}

/*********************************************************************************************
 GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function bool CanBeGrabbed( Actor grabbedByActor, optional name boneName = '' )
{
	return false;
}

function OnGrabbed( Actor grabbedByActor );
function OnDropped( Actor droppedByActor );

function name GetBoneName( vector grabLocation )
{
	return '';
}

function PrimitiveComponent GetGrabbableComponent()
{
	return none;
}

function GGPhysicalMaterialProperty GetPhysProp()
{
	return none;
}

/*********************************************************************************************
 END GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

simulated event PostInitAnimTree( SkeletalMeshComponent skelComp )
{
	mDefaultAnimationInfo.AnimationNames.Length=0;
	mDefaultAnimationInfo.AnimationNames[0]='';

	super.PostInitAnimTree( skelComp );

	SetAnimationsEnabled(false);
	mAnimNodeSlot=none;
}

DefaultProperties
{
	Begin Object name=WPawnSkeletalMeshComponent
		AnimTreeTemplate=none
		bNotifyRigidBodyCollision = false
        CollideActors = false
        BlockActors = false
        Rotation=(Pitch=16384, Yaw=32768, Roll=0)
        Translation=(X=0, Y=0, Z=23)
        scale=0.25f
	End Object

	bNoEncroachCheck=true
	bCollideActors=false
	bBlockActors=false
}