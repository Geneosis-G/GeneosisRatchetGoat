class RatchetGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var ClankNpc mClank;
var Wrench mWrench;
var StaticMeshComponent decoWrench;
var bool isJumpPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.MaxMultiJump++;

		SetBoneScaleForPawn(gMe, 'Ear_01_L', 3.f);
		SetBoneScaleForPawn(gMe, 'Ear_01_R', 3.f);

		decoWrench.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( decoWrench, 'grabSocket' );

		SpawnClank();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;
	local float r, h;
	local vector dest;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if(localInput.IsKeyIsPressed("GBA_AbilityAuto", string( newKey )))
		{
			if(!gMe.mIsRagdoll && mWrench != none && !mWrench.isThrown)
			{
				mWrench.GetBoundingCylinder(r, h);
				dest=Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius()+r);
				mWrench.SetLocation(gMe.Location + dest);
				mWrench.wrenchMesh.SetRBPosition(gMe.Location + dest);
				decoWrench.SetHidden(true);
				mWrench.ThrowWrench(vector(gMe.Rotation));
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Jump", string( newKey )))
		{
			isJumpPressed=true;
		}

		/*if(newKey == 'P')
		{
			mWrench.wrenchRadius=mWrench.wrenchRadius+10;
			myMut.WorldInfo.Game.Broadcast(myMut, "radius=" $ mWrench.wrenchRadius);
		}
		if(newKey == 'M')
		{
			mWrench.wrenchRadius=mWrench.wrenchRadius-10;
			myMut.WorldInfo.Game.Broadcast(myMut, "radius=" $ mWrench.wrenchRadius);
		}*/
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_AbilityAuto", string( newKey )))
		{
			mWrench.ComeBack();
		}

		if(localInput.IsKeyIsPressed("GBA_Jump", string( newKey )))
		{
			isJumpPressed=false;
		}
	}
}

function WrenchIsBack()
{
	decoWrench.SetHidden(false);
}

function bool IsClankAlive()
{
	return mClank != none && !mClank.bPendingDelete;
}

function SpawnClank()
{
	if(mClank == none)
	{
		mClank = gMe.Spawn(class'ClankNpc', gMe,, gMe.Location,,, true);
		//myMut.WorldInfo.Game.Broadcast(myMut, "mClank=" $ mClank);
	}
	//SetBoneScaleForPawn(mClank, 'Body', 0.25f);
	//mClank.mesh.SetRotation(rot(16384, 32768, 0));

	if(!gMe.IsTimerActive(NameOf(AttachClank), self))
	{
		gMe.SetTimer(0.1f, false, NameOf(AttachClank), self);
	}
}

function AttachClank()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "AttachClank");

	gMe.mActorsToIgnoreBlockingBy.AddItem(mClank);

    mClank.RideTheGoat( gMe );
    mClank.mesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
    gMe.mesh.AttachComponentToSocket( mClank.mesh, 'JetPackSocket' );

	ForceBoneRagdoll(mClank, 'Arm_R');
	ForceBoneRagdoll(mClank, 'Arm_L');
	ForceBoneRagdoll(mClank, 'Ear_R');
	ForceBoneRagdoll(mClank, 'Ear_L');

	mClank.mesh.SetLightEnvironment( gMe.mesh.LightEnvironment );

    gMe.mGoatRider = mClank;

	SetMeshCollision();
}

function RemoveClank()
{
	if(IsClankAlive())
	{
		if( gMe.mGoatRider == mClank )
	    {
		   gMe.RemoveGoatRider();
	    }
	    mClank.Destroy();
	    mClank=none;
	}
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	if(respawnController == gMe.Controller)
	{
		RemoveClank();
		SpawnClank();
	}

	super.OnPlayerRespawn(respawnController, died);
}

function SetBoneScaleForPawn(GGpawn gpawn, name boneName, float newScale)
{
	local SkelControlBase skelControl;

	skelControl = gpawn.mesh.FindSkelControl( boneName );
	if( skelControl == none )
	{
		if( gpawn.Mesh.MatchRefBone( boneName ) != INDEX_NONE )
		{
			skelControl = gpawn.Mesh.AddSkelControl( boneName, class'SkelControlSingleBone' );
			skelControl.ControlName = boneName;
		}
	}

	if( skelControl != none )
	{
		skelControl.BoneScale = newScale;

		skelControl.SetSkelControlStrength( 0.0f, 0.0f );
		skelControl.SetSkelControlStrength( 1.0f, 1.0f );
	}
}

function ForceBoneRagdoll(GGPawn gpawn, name boneName)
{
	gpawn.mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( boneName, gpawn.mesh.PhysicsAsset, gpawn.mesh, true );
}

function SetMeshCollision()
{
	// Fix ragdoll
	if(mClank.mIsRagdoll)
	{
		mClank.SetRagdoll(false);
	}
	// Fix bone update
	mClank.mesh.MinDistFactorForKinematicUpdate = 0.0f;
	mClank.mesh.ForceSkelUpdate();
	mClank.mesh.UpdateRBBonesFromSpaceBases( true, true );
	// Fix collisions
	if(gMe.mActorsToIgnoreBlockingBy.Find(mClank) == -1)
	{
		gMe.mActorsToIgnoreBlockingBy.AddItem(mClank);
	}
	mClank.CollisionComponent=none;
	mClank.SetCollisionType(COLLIDE_NoCollision);
	mClank.SetPhysics(PHYS_None);
	mClank.mesh.SetRBCollidesWithChannel( RBCC_Default, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_Pawn, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_Vehicle, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_Untitled3, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_BlockingVolume, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_EffectPhysics, false );
	mClank.mesh.SetRBCollidesWithChannel( RBCC_GameplayPhysics, false );
}

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(IsClankAlive())
	{
		if((!isRagdoll && ragdolledActor == gMe)
		|| (isRagdoll && ragdolledActor == mClank))
		{
			SetMeshCollision();
		}
	}
}

function OnLanded( Actor actorLanded, Actor actorLandedOn )
{
	if(IsClankAlive() && actorLanded == gMe)
	{
		SetMeshCollision();
	}
}

simulated event TickMutatorComponent( float delta )
{
	if(mWrench == none || mWrench.bPendingDelete)
	{
		mWrench = gMe.Spawn(class'Wrench', gMe,, gMe.Location,,, true);
		mWrench.OnWrenchBack=WrenchIsBack;
	}

	if(IsClankAlive() && !gMe.IsTimerActive(NameOf(AttachClank), self) && gMe.mGoatRider != mClank)
	{
		RemoveClank();
	}

	if(IsClankAlive() && gMe.mGrabbedItem == mClank)
	{
		gMe.DropGrabbedItem();
		SetMeshCollision();
	}

	if(gMe.Physics == PHYS_Falling && isJumpPressed && gMe.Velocity.Z<0)
	{
		gMe.Velocity.Z=0;
	}
}

defaultproperties
{
	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Garage.mesh.Garage_Tool_01'
	End Object
	decoWrench=StaticMeshComp1
}