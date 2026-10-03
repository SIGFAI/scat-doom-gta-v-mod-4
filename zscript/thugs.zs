// Purple Paws gang: thug cats that replace the imps and throw molotov cocktails.

class ThugCat : DoomImp replaces DoomImp
{
	mixin DotChaser;
	Default
	{
		Health 60;
		Radius 16;
		Height 56;
		Speed 9;
		PainChance 180;
		Mass 100;
		SeeSound "lg/meow";
		PainSound "lg/hiss";
		DeathSound "lg/yowl";
		ActiveSound "lg/meow";
		MeleeSound "lg/hiss";
		Obituary "%o got torched by a Purple Paws thug.";
		HitObituary "%o got clawed by a Purple Paws thug.";
		Tag "Thug Cat";
	}
	States
	{
	Spawn:
		THUG C 10 A_Look;
		Loop;
	See:
		THUG AABB 4 A_Chase;
		Loop;
	Melee:
		THUG D 6 A_FaceTarget;
		THUG D 6 A_CustomMeleeAttack(random(3, 8) * 3, "lg/hiss", "", 'Melee');
		Goto See;
	Missile:
		THUG C 14 A_FaceTarget;
		THUG D 6
		{
			// Lob it: the launch angle that lands the bottle at the target's distance (speed 17, gravity 0.5).
			double d = target ? Distance2D(target) : 300;
			A_SpawnProjectile("Molotov", 46, 8, frandom(-3, 3), CMF_AIMDIRECTION, -0.5 * asin(clamp(d / 578., 0.05, 1.)));
		}
		THUG D 8;
		Goto See;
	DotChase:
		THUG A 3 ChaseDot;
		THUG B 3 ChaseDot;
		Loop;
	Pain:
		THUG E 4;
		THUG E 4 A_Pain;
		Goto See;
	Death:
		THUG E 5;
		THUG F 6 A_Scream;
		THUG F 6 A_NoBlocking;
		THUG G 420;
		THUG G 1 A_FadeOut(0.04);   // GTA: bodies clear up after a while
		Wait;
	XDeath:
		Goto Death;
	Raise:
		THUG G 5;
		THUG F 5;
		Goto See;
	}
}

// The bottle: spins through the air on an arc with a smoky flame, smashes into a pool of fire.
class Molotov : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		Gravity 0.5;
		Speed 17;
		Radius 6;
		Height 8;
		Damage 3;
		DamageType "Fire";
		DeathSound "lg/glass";
		+ROLLSPRITE
		+ROLLCENTER
	}
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen() || bMissile == false) return;
		roll += 24;
		A_SpawnParticle(0xFF9020, SPF_FULLBRIGHT, 12, 4, 0, 0, 0, 8, frandom(-0.3, 0.3), frandom(-0.3, 0.3), 0.6);
		if (level.maptime % 2 == 0)
			A_SpawnParticle(0x505050, 0, 30, 7, 0, 0, 0, 8, 0, 0, 0.5, 0, 0, 0, 0.5, -1, 0.2);
	}
	States
	{
	Spawn:
		MOLO A 1 Bright Light("LGMOLOTOV");
		Loop;
	Death:
		TNT1 A 0
		{
			roll = 0;
			for (int i = 0; i < 4; i++)
			{
				let f = Spawn("GroundFire", pos + (frandom(-36, 36), frandom(-36, 36), 0), ALLOW_REPLACE);
				if (f) { f.target = target; f.SetOrigin((f.pos.xy, f.floorz), false); }
			}
			for (int i = 0; i < 14; i++)
				A_SpawnParticle(0x70C070, 0, 25, 3, frandom(0, 360), 0, 0, 4, frandom(1, 4), 0, frandom(2, 6), 0, 0, -0.5);
		}
		MISL B 4 Bright;
		MISL CD 4 Bright;
		Stop;
	}
}

// Burning puddle: licks of flame for 5 s, hurts whoever stands in it (cats included).
class GroundFire : Actor
{
	int life;
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+DROPOFF
		RenderStyle "Add";
		Alpha 0.95;
		Scale 0.38;
		DamageType "Fire";
	}
	override void BeginPlay()
	{
		Super.BeginPlay();
		life = 35 * 4 + random(0, 20);
		scale *= frandom(0.8, 1.2);
	}
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen()) return;
		if (--life <= 0) { Destroy(); return; }
		if (life % 10 == 0) A_Explode(4, 40, XF_HURTSOURCE | XF_NOSPLASH, false, 40);
		if (life < 30) alpha = life / 30.;
	}
	States
	{
	Spawn:
		FIRE ABCDEFGH 3 Bright Light("LGFIRE");
		Loop;
	}
}
