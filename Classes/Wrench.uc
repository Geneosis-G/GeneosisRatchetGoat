class Wrench extends GGKActor;

var StaticMeshComponent wrenchMesh;

var bool isThrown;
var bool isGoingAway;
var vector expectedDirection;
var rotator expectedRotation;
var float wrenchRotationRate;
var float distBeforeBoomerang;
var float wrenchSpeed;
var float wrenchForce;
var float wrenchRadius;
var rotator mCurrentRotation;

var GGGoat mGoat;

delegate OnWrenchBack();

simulated event PostBeginPlay()
{
	super.PostBeginPlay();
	//WorldInfo.Game.Broadcast(self, "LaserwrenchSpawned=" $ self);
	StaticMeshComponent.BodyInstance.CustomGravityFactor=0.f;
	CollisionComponent.WakeRigidBody();

	mGoat=GGGoat(Owner);
	wrenchMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );

	wrenchMesh.SetHidden(true);
	wrenchMesh.SetActorCollision(false, false);
	wrenchMesh.SetBlockRigidBody(false);
	wrenchMesh.SetNotifyRigidBodyCollision(false);
}

function bool shouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| Landscape(act) != none
	|| act == self
	|| act.Owner == Owner);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage");
	if(shouldIgnoreActor(damageCauser))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	HitActor(damageCauser);
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump");
	if(shouldIgnoreActor(other))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	HitActor(other);
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision");
	if(shouldIgnoreActor(OtherComponent.Owner))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	HitActor(OtherComponent!=none?OtherComponent.Owner:none);
}

function FindExtraTargets()
{
	local Actor currTarget;

	//traceStart=Location + (wrenchMesh.Translation >> Rotation);
	//DrawDebugLine (traceStart, traceStart + (Normal(vector(Rotation)) * wrenchRadius), 0, 0, 0,);

	//WorldInfo.Game.Broadcast(self, "FindExtraTargets() wrenchRadius=" $ wrenchRadius);

	foreach OverlappingActors( class'Actor', currTarget, wrenchRadius, Location)
    {
		if(shouldIgnoreActor(currTarget))
	    {
	        continue;
	    }

		//WorldInfo.Game.Broadcast(self, "Found Extra Target :" $ currTarget);
		HitActor(currTarget);
    }
}

function HitActor(optional Actor target)
{
	local GGPawn gpawn;
	local GGNPCMMOEnemy mmoEnemy;
	local GGNpcZombieGameModeAbstract zombieEnemy;
	local GGKactor kActor;
	local GGSVehicle vehicle;
	local float mass;
	local vector targetPos, direction, newVelocity, point, X, Y, Z;
	local int damage;

	if(target == mGoat)
	{
		if(isThrown && !isGoingAway)
		{
			CatchWrench();
		}
		return;
	}

	gpawn = GGPawn(target);
	mmoEnemy = GGNPCMMOEnemy(target);
	zombieEnemy = GGNpcZombieGameModeAbstract(target);
	kActor = GGKActor(target);
	vehicle = GGSVehicle(target);
	// Get correct angle depending on wrench angle
	targetPos = gpawn==none?target.Location:gpawn.mesh.GetPosition();
	GetAxes(Rotation, X, Y, Z);
	point=PointProjectToPlane(targetPos, Location, Location + X, Location + Y);
	direction = Normal(point-Location);
	if(gpawn != none)
	{
		mass=50.f;
		if(!gpawn.mIsRagdoll)
		{
			gpawn.SetRagdoll(true);
		}
		//gpawn.mesh.AddImpulse(direction * mass * wrenchForce,,, false);
		newVelocity = gpawn.Mesh.GetRBLinearVelocity() + (direction * wrenchForce);
		gpawn.Mesh.SetRBLinearVelocity(newVelocity);
		//Damage MMO enemies
		if(mmoEnemy != none)
		{
			damage = int(RandRange(1, 5));
			mmoEnemy.TakeDamageFrom(damage, Owner, class'GGDamageTypeExplosiveActor');
		}
		else
		{
			gpawn.TakeDamage( 0.f, GGGoat(Owner).Controller, gpawn.Location, vect(0, 0, 0), class'GGDamageType',, Owner);
		}
		//Damage zombies
		if(zombieEnemy != none)
		{
			damage = int(RandRange(5, 10));
			zombieEnemy.TakeDamage(damage, GGGoat(Owner).Controller, zombieEnemy.Location, vect(0, 0, 0), class'GGDamageTypeZombieSurvivalMode' );
		}
	}
	else if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse(direction,  mass * wrenchForce,  -direction);
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce(direction * mass * wrenchForce);
	}
	else if(GGApexDestructibleActor(target) != none)
	{
		target.TakeDamage(10000000, GGGoat(Owner).Controller, target.Location, direction * mass * wrenchForce, class'GGDamageTypeAbility',, Owner);
	}
}

simulated event Tick( float delta )
{
	local GGPawn gpawn;
	local float currVelocity;
	local float r, h;

	//WorldInfo.Game.Broadcast(self, self $ " at " $ Location);

	// Try to prevent pawns from walking on it
	foreach BasedActors(class'GGPawn', gpawn)
	{
		HitActor(gpawn);
	}
	// Test the state of the wrench
	if(isThrown)
	{
		if(isGoingAway)
		{
			if(VSize(Location-mGoat.Mesh.GetPosition()) >= distBeforeBoomerang)
			{
				ComeBack();
			}
		}
		else
		{
			GetBoundingCylinder(r, h);
			if(VSize(Location-mGoat.Mesh.GetPosition()) <= mGoat.GetCollisionRadius()+r)
			{
				CatchWrench();
			}
			else
			{
				expectedDirection=mGoat.mesh.GetPosition()-Location;
			}
		}
		// if the wrench is still flying
		if(isThrown)
		{
			currVelocity=VSize(Velocity);
			if(!IsZero(expectedDirection))
			{
				// Maintain velocity
				if(currVelocity < wrenchSpeed)
				{
					StaticMeshComponent.SetRBLinearVelocity(Normal(expectedDirection) * wrenchSpeed);
				}
			}
			// Force rotation
			mCurrentRotation.Yaw+=wrenchRotationRate * delta;
			mCurrentRotation.Yaw=mCurrentRotation.Yaw % 65536;
			expectedRotation=GetGlobalRotation(rotator(Normal(Velocity)), mCurrentRotation);
			StaticMeshComponent.SetRBRotation(expectedRotation);
			// Find missed items
			FindExtraTargets();
		}
	}
}

function rotator GetGlobalRotation(rotator BaseRotation, rotator LocalRotation)
{
	local vector X, Y, Z;

	GetAxes(LocalRotation, X, Y, Z);
	return OrthoRotation(X >> BaseRotation, Y >> BaseRotation, Z >> BaseRotation);
}

function ThrowWrench(vector newDirection)
{
	if(isThrown)
		return;

	wrenchMesh.SetHidden(false);
	wrenchMesh.SetActorCollision(true, true);
	wrenchMesh.SetBlockRigidBody(true);
	wrenchMesh.SetNotifyRigidBodyCollision(true);
	isThrown=true;
	isGoingAway=true;
	expectedDirection=newDirection;
	// if the boomerang don't come back after 10 sec, force it to come back
	SetTimer(10.f, false, NameOf(ComeBack));
}

function ComeBack()
{
	if(!isThrown || !isGoingAway)
		return;

	isGoingAway=false;
	expectedDirection = -expectedDirection;
	// if the boomerang is not catched after 10 sec, force it to be catched
	SetTimer(10.f, false, NameOf(CatchWrench));
}

function CatchWrench()
{
	if(!isThrown || isGoingAway)
		return;

	wrenchMesh.SetHidden(true);
	wrenchMesh.SetActorCollision(false, false);
	wrenchMesh.SetBlockRigidBody(false);
	wrenchMesh.SetNotifyRigidBodyCollision(false);
	isThrown=false;
	expectedDirection=vect(0, 0, 0);
	ClearTimer(NameOf(ComeBack));
	ClearTimer(NameOf(CatchWrench));
	OnWrenchBack();
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	mBlockCamera=false

	wrenchForce=200.f
	wrenchRadius=20.0f
	wrenchSpeed=2000.f
	wrenchRotationRate=500000.f
	distBeforeBoomerang=5000.f

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Garage.mesh.Garage_Tool_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
	End Object
	wrenchMesh=StaticMeshComponent0

	bCollideActors=true
	bBlockActors=true
	bCollideWorld=true;
}