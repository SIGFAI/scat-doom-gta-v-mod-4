// Cars: parked ones that alarm, smoke, catch fire and blow up (GTA rules), and the Los Gatos PD cruiser.

// One burst of the car explosion: Doom's own rocket fireball, big and additive.
class LGBoomFX : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		RenderStyle "Add";
		Alpha 0.95;
		Scale 1.7;
	}
	States
	{
	Spawn:
		MISL B 5 Bright;
		MISL C 5 Bright A_FadeOut(0.15);
		MISL D 5 Bright A_FadeOut(0.25);
		Wait;
	}
}

// A tongue of fire on a burning wreck (the arch-vile flame frames of the base game).
class LGFlame : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		RenderStyle "Add";
		Alpha 0.9;
		Scale 0.7;
	}
	States
	{
	Spawn:
		FIRE ABCDEFGH 3 Bright { vel.z = 0.6; }
		Stop;
	}
}

class LGCar : Actor
{
	bool burning;
	int burnUntil;
	int lastAlarm;
	Default
	{
		Health 140;
		Radius 34;
		Height 44;
		Mass 5000;
		Scale 0.8;
		DamageFactor 1.5;     // GTA: a few bullets in the engine and it goes up
		PainChance 255;
		DeathSound "lg/carboom";
		PainSound "lg/horn";
		Tag "Car";
		+SOLID
		+SHOOTABLE
		+NOBLOOD
		+DONTTHRUST
		+NOICEDEATH
		+ACTLIKEBRIDGE
	}

	override void Tick()
	{
		Super.Tick();
		if (IsFrozen()) return;
		if (health > 0)
		{
			// GTA: a badly hit car smokes, then its engine catches fire.
			double h = double(health) / SpawnHealth();
			if (h < 0.6 && level.maptime % 3 == 0)
				A_SpawnParticle(0x404040, SPF_RELATIVE, 50, 14, 0, frandom(-8, 8), frandom(-8, 8), height * 0.9, 0, 0, 0.9, 0, 0, 0.02, 0.6, -1, 0.3);
			if (h < 0.35 && level.maptime % 5 == 0)
				Spawn("LGFlame", pos + (frandom(-10, 10), frandom(-10, 10), height * 0.6), ALLOW_REPLACE);
		}
		else if (level.maptime < burnUntil)
		{
			if (level.maptime % 4 == 0)
				Spawn("LGFlame", pos + (frandom(-24, 24), frandom(-24, 24), frandom(10, 30)), ALLOW_REPLACE);
			if (level.maptime % 2 == 0)
				A_SpawnParticle(0x202020, SPF_RELATIVE, 70, 24, 0, frandom(-20, 20), frandom(-20, 20), 40, 0, 0, 1.2, 0, 0, 0.02, 0.5, -1, 0.4);
		}
		else if (burning)
		{
			burning = false;
			A_StopSound(CHAN_7);
			A_RemoveLight('fire');
		}
	}

	// Car alarm, not on every bullet.
	void Alarm()
	{
		if (level.maptime - lastAlarm < 30) return;
		lastAlarm = level.maptime;
		A_StartSound("lg/horn", CHAN_VOICE);
	}

	// The blast: fireballs, a hop, damage around (other cars go up too: chain reactions), then it burns.
	void Boom()
	{
		A_StartSound("lg/carboom", CHAN_BODY, 0, 1., 0.5);
		A_StartSound("lg/fire", CHAN_7, CHANF_LOOPING, 0.5);
		A_Explode(160, 192, XF_HURTSOURCE);
		A_QuakeEx(4, 4, 3, 24, 0, 900, "", QF_SCALEDOWN);
		for (int i = 0; i < 9; i++)
		{
			let fx = Spawn("LGBoomFX", pos + (frandom(-36, 36), frandom(-36, 36), frandom(8, 56)), ALLOW_REPLACE);
			if (fx) { fx.vel = (frandom(-1, 1), frandom(-1, 1), frandom(1, 3)); fx.scale *= frandom(0.7, 1.3); }
		}
		for (int i = 0; i < 40; i++)
			A_SpawnParticle(0xFFB030, SPF_FULLBRIGHT | SPF_RELATIVE, 35, 5, frandom(0, 360), 0, 0, 30, frandom(2, 8), 0, frandom(2, 9), 0, 0, -0.4);
		A_AttachLight('fire', DynamicLight.FlickerLight, 0xFF8020, 140, 180, 0, (0, 0, 40), 0.3);
		A_SetSize(-1, 40);
		vel.z = 7;
		burning = true;
		burnUntil = level.maptime + 35 * 8;
		bShootable = false;
		bSolid = true;
	}
}

class ParkedTaxi : LGCar
{
	States
	{
	Spawn:
		TAXI A -1;
		Stop;
	Pain:
		TAXI A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class ParkedSedan : LGCar
{
	States
	{
	Spawn:
		SEDN A -1;
		Stop;
	Pain:
		SEDN A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class ParkedSUV : LGCar
{
	States
	{
	Spawn:
		CAR4 A -1;
		Stop;
	Pain:
		CAR4 A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class ParkedCarSpot : RandomSpawner
{
	Default
	{
		DropItem "ParkedTaxi";
		DropItem "ParkedSedan";
		DropItem "ParkedSUV";
	}
}

// The Los Gatos PD cruiser: drives at you with the siren on, rams, the cop cat at the wheel shoots out of the
// window. Blown up, it throws its driver out, who (being a cat) lands on its feet and keeps fighting.
class PoliceCruiser : LGCar
{
	int sirenPhase;
	Default
	{
		Monster;
		Health 170;
		Speed 12;
		Radius 34;
		Height 44;
		Mass 3000;
		PainChance 40;
		MeleeRange 72;
		MaxStepHeight 24;
		SeeSound "";
		ActiveSound "lg/horn";
		Obituary "%o got run over by the Los Gatos PD.";
		Tag "Police Cruiser";
		-DONTTHRUST
		-ACTLIKEBRIDGE
		+DONTMORPH
		+NORADIUSDMG
		+FLOORCLIP
	}

	override void Tick()
	{
		Super.Tick();
		if (health <= 0 || IsFrozen()) return;
		// Light bar: red and blue, swapping.
		if (level.maptime % 6 == 0)
		{
			sirenPhase ^= 1;
			A_AttachLight('bar', DynamicLight.PointLight, sirenPhase ? 0xFF1010 : 0x1030FF, 128, 0, DynamicLight.LF_DONTLIGHTSELF, (0, 0, 60));
		}
		// The light bar flashing, bright enough to read in the California sun.
		if (level.maptime % 2 == 0)
		{
			Vector2 side = AngleToVector(angle + 90, 9);
			Color c = sirenPhase ? Color(255, 30, 30) : Color(40, 80, 255);
			double s = sirenPhase ? 1 : -1;
			A_SpawnParticle(c, SPF_FULLBRIGHT, 3, 14, 0, side.x * s, side.y * s, 50, 0, 0, 0, 0, 0, 0, 0.9, 0.3);
		}
	}

	void SirenOn()
	{
		A_StartSound("lg/siren", CHAN_6, CHANF_LOOPING, 0.8, 0.8);
	}

	void Ram()
	{
		let t = target;
		if (!t || Distance3D(t) > MeleeRange + t.radius) return;
		A_StartSound("lg/horn", CHAN_VOICE);
		t.DamageMobj(self, self, random(15, 25), 'Melee');
		t.vel += (AngleToVector(angle, 14), 6);
	}

	void Eject()
	{
		A_StopSound(CHAN_6);
		A_RemoveLight('bar');
		let c = CatCop(Spawn("CatCop", pos + (0, 0, 40), ALLOW_REPLACE));
		if (c)
		{
			c.vel = (frandom(-4, 4), frandom(-4, 4), 14);
			c.Launch();
		}
	}

	States
	{
	Spawn:
		PCAR A 10 A_Look;
		Loop;
	See:
		PCAR A 0 SirenOn;
	Chase:
		PCAR A 2 A_Chase(null, "Missile");
		Loop;
	Melee:
		PCAR A 3 A_FaceTarget;
		PCAR A 3 Ram;
		PCAR A 8;
		Goto Chase;
	Missile:
		PCAR A 6 A_FaceTarget;
		PCAR A 3 Bright { A_StartSound("lg/pistol", CHAN_WEAPON); A_CustomBulletAttack(12, 0, 1, random(2, 4) * 3, "BulletPuff", 0, CBAF_NORANDOM, spawnheight: 30); }
		PCAR A 4 A_FaceTarget;
		PCAR A 3 Bright { A_StartSound("lg/pistol", CHAN_WEAPON); A_CustomBulletAttack(12, 0, 1, random(2, 4) * 3, "BulletPuff", 0, CBAF_NORANDOM, spawnheight: 30); }
		PCAR A 6;
		Goto Chase;
	Pain:
		PCAR A 4 Alarm;
		PCAR A 4;
		Goto Chase;
	Death:
		PWRK A 1 { Boom(); Eject(); }
		PWRK A -1;
		Stop;
	}
}

// Traffic: civilian cars cruising the streets. They keep to the road (the curb stops them), turn at corners and
// sometimes at crossings, honk at whoever is in the way and run over cats who don't move. Shoot them and they burn.
class TrafficCar : LGCar
{
	int turnWait, honkWait, stuck, jam;
	Vector2 lastXY;
	Default
	{
		Speed 5;
		MaxStepHeight 4;      // the curb is 8 high: cars stay on the road
		Health 140;
		-DONTTHRUST
		+NOTONAUTOMAP
		Tag "Car";
	}

	double Free(double yaw, double dist, double z = 6)
	{
		FLineTraceData d;
		if (!LineTrace(yaw, dist, 0, TRF_THRUACTORS, z, data: d)) return dist;
		return d.Distance;
	}

	void Drive()
	{
		if (health <= 0 || bDormant) return;
		turnWait--;
		honkWait--;
		// Somebody in front: honk; a cat gets run over.
		bool blocked = false;
		let it = BlockThingsIterator.Create(self, 120);
		while (it.Next())
		{
			let t = it.thing;
			if (!t || t == self || !t.bSolid || t.health <= 0) continue;
			Vector2 d = t.pos.xy - pos.xy;
			double ahead = d dot AngleToVector(angle);
			double side = abs(d dot AngleToVector(angle + 90));
			if (ahead <= 0 || ahead > radius + t.radius + 26 || side > radius + t.radius) continue;
			if (t.bIsMonster && !(t is "LGCar"))
			{
				t.DamageMobj(self, self, 45, 'Crush');
				t.vel += (AngleToVector(angle, 9), 7);
				A_StartSound("lg/horn", CHAN_VOICE);
				continue;
			}
			blocked = true;
			if (honkWait <= 0) { A_StartSound("lg/horn", CHAN_VOICE); honkWait = 50; }
		}
		if (blocked)
		{
			vel.xy = (0, 0);
			// Traffic jam: give up and take another street.
			if (++jam > 45) { angle += random(0, 1) ? 90 : 180; jam = 0; turnWait = 30; }
			return;
		}
		jam = 0;
		// Corners: the road ends (curb or wall ahead): take the open side.
		if (turnWait <= 0)
		{
			double front = Free(angle, 100);
			if (front < 90)
			{
				double l = Free(angle + 90, 260), r = Free(angle - 90, 260);
				angle += (l > r) ? 90 : -90;
				if (max(l, r) < 120) angle += 90;   // dead end: turn around
				turnWait = 20;
			}
			else if (random(0, 99) < 3 && Free(angle + 90, 300) >= 300 && Free(angle - 90, 300) >= 300)
			{
				// A crossing: sometimes turn right (right-hand traffic).
				angle -= 90;
				turnWait = 45;
			}
		}
		angle = round(angle / 90.) * 90;
		if (pos.z <= floorz + 1) vel.xy = AngleToVector(angle, speed);
		// Stuck against something: back off and turn.
		if ((pos.xy - lastXY).Length() < 0.5) { if (++stuck > 35) { angle += 90; stuck = 0; } }
		else stuck = 0;
		lastXY = pos.xy;
	}
}

class TrafficTaxi : TrafficCar
{
	States
	{
	Spawn:
		TAXI A 1 Drive;
		Loop;
	Pain:
		TAXI A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class TrafficSedan : TrafficCar
{
	States
	{
	Spawn:
		SEDN A 1 Drive;
		Loop;
	Pain:
		SEDN A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class TrafficSUV : TrafficCar
{
	States
	{
	Spawn:
		CAR4 A 1 Drive;
		Loop;
	Pain:
		CAR4 A 1 Alarm;
		Goto Spawn;
	Death:
		SWRK A 1 Boom;
		SWRK A -1;
		Stop;
	}
}

class TrafficSpot : RandomSpawner
{
	Default
	{
		DropItem "TrafficTaxi";
		DropItem "TrafficSedan";
		DropItem "TrafficSUV";
	}
}
