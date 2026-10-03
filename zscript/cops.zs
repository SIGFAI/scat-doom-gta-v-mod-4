// Los Gatos Police Department: cop cats that replace the zombie troopers.

class CatCop : ZombieMan replaces ZombieMan
{
	mixin DotChaser;
	bool flying;   // thrown out of a blown-up cruiser: spins through the air

	void Launch()
	{
		flying = true;
		bRollSprite = true;
		bRollCenter = true;
		SetStateLabel("Fly");
	}

	override void Tick()
	{
		Super.Tick();
		if (!flying || IsFrozen() || health <= 0) return;
		roll += 26;
		if (vel.z <= 0 && pos.z <= floorz + 1 && GetAge() > 4)
		{
			// A cat always lands on its feet.
			flying = false;
			roll = 0;
			A_StartSound("lg/meow", CHAN_VOICE);
			let h = LGHandler(EventHandler.Find("LGHandler"));
			if (h) h.Announce("CATS ALWAYS LAND ON THEIR FEET", Font.CR_GOLD);
			SetState(SeeState);
		}
	}

	Default
	{
		Health 60;
		Radius 16;
		Height 58;
		Speed 9;
		PainChance 170;
		Mass 120;
		DropItem "None";
		Obituary "%o got arrested by a cop cat.";
		Tag "Cop Cat";
		SeeSound "lg/meow";
		PainSound "lg/hiss";
		DeathSound "lg/yowl";
		ActiveSound "lg/meow";
	}
	States
	{
	Spawn:
		CCOP C 10 A_Look;
		Loop;
	See:
		CCOP AABB 4 A_Chase;
		Loop;
	Missile:
		CCOP C 10 A_FaceTarget;
		CCOP D 4 Bright { A_StartSound("lg/pistol", CHAN_WEAPON); A_CustomBulletAttack(18, 0, 1, random(3, 5) * 3, "BulletPuff", 0, CBAF_NORANDOM); }
		CCOP C 6;
		CCOP D 4 Bright { A_StartSound("lg/pistol", CHAN_WEAPON); A_CustomBulletAttack(18, 0, 1, random(3, 5) * 3, "BulletPuff", 0, CBAF_NORANDOM); }
		CCOP C 8;
		Goto See;
	Fly:
		CCOP E -1;
		Stop;
	DotChase:
		CCOP A 3 ChaseDot;
		CCOP B 3 ChaseDot;
		Loop;
	Pain:
		CCOP E 5;
		CCOP E 5 A_Pain;
		Goto See;
	Death:
		CCOP E 5;
		CCOP F 6 A_Scream;
		CCOP F 6 A_NoBlocking;
		CCOP G 420;
		CCOP G 1 A_FadeOut(0.04);   // GTA: bodies clear up after a while
		Wait;
	XDeath:
		Goto Death;
	Raise:
		CCOP G 5;
		CCOP F 5;
		CCOP E 5;
		Goto See;
	}
}
