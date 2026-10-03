// Professor Whiskers' gadget: a pistol with a laser sight. Every shot leaves a red dot where it lands, and no cat
// can resist a red dot: cop cats and thugs who see it stop fighting and pounce on it, onto whoever is standing there.

class LaserPistol : Pistol replaces Pistol
{
	Default
	{
		Weapon.SlotNumber 2;
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 40;
		Weapon.AmmoType "Clip";
		Weapon.SelectionOrder 1900;
		Inventory.PickupMessage "Picked up Professor Whiskers' laser pistol.";
		Obituary "%o was shot by %k's laser pistol.";
		Tag "Laser Pistol";
		+WEAPON.NOAUTOFIRE
	}

	action void LaserShot()
	{
		A_StartSound("lg/pistol", CHAN_WEAPON);
		A_AlertMonsters();
		FLineTraceData d;
		double pz = player.viewz - pos.z;
		LineTrace(angle, 4096, pitch, 0, pz, data: d);
		Vector3 hit = d.HitLocation;
		A_FireBullets(1.2, 0, 1, 17, "BulletPuff", FBF_NORANDOM | FBF_USEAMMO);
		// The beam: from the laser module (right of and below the eye) to the hit point.
		Vector3 from = pos + (AngleToVector(angle - 25, 14), pz - 9);
		Vector3 seg = hit - from;
		double len = seg.Length();
		if (len > 1)
		{
			Vector3 dir = seg / len;
			for (double t = 12; t < len; t += 2.5)
			{
				Vector3 p = from + dir * t;
				double sz = 2 + min(t / 60., 5.);   // thicker far away so it reads at any distance
				A_SpawnParticle(0xFF1818, SPF_FULLBRIGHT, 8, sz, 0, p.x - pos.x, p.y - pos.y, p.z - pos.z, 0, 0, 0, 0, 0, 0, 1., 0.12);
			}
		}
		let rdot = Spawn("LaserDot", hit - (d.HitType == TRACE_HitActor ? (0, 0, 0) : (AngleToVector(angle, 2), 0)), ALLOW_REPLACE);
		if (rdot)
		{
			rdot.target = self;
			if (d.HitType == TRACE_HitActor) rdot.tracer = d.HitActor;
		}
	}

	States
	{
	Ready:
		LPSG A 1 A_WeaponReady;
		Loop;
	Deselect:
		LPSG A 1 A_Lower;
		Loop;
	Select:
		LPSG A 1 A_Raise;
		Loop;
	Fire:
		LPSG B 3 Bright LaserShot;
		LPSG A 6;
		LPSG A 2 A_ReFire;
		Goto Ready;
	Flash:
		TNT1 A 3 Bright A_Light1;
		Goto LightDone;
	Spawn:
		PIST A -1;
		Stop;
	}
}

// The red rdot. It sticks to whoever was hit and calls every cat around that can see it.
class LaserDot : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		RenderStyle "Add";
	}
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen()) return;
		if (tracer && tracer.health > 0) SetOrigin(tracer.pos + (0, 0, tracer.height * 0.6), true);
		double pulse = 7 + sin(GetAge() * 40) * 2;
		A_SpawnParticle(0xFF0000, SPF_FULLBRIGHT, 2, pulse * 2.2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.55);
		A_SpawnParticle(0xFF6060, SPF_FULLBRIGHT, 2, pulse, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.);
		if (GetAge() % 4 == 0) CallCats();
		if (GetAge() > 70) Destroy();
	}

	void CallCats()
	{
		let it = BlockThingsIterator.Create(self, 700);
		while (it.Next())
		{
			let c = it.thing;
			if (!c || c.health <= 0 || c == tracer) continue;
			let cop = CatCop(c);
			let thug = ThugCat(c);
			if (cop) cop.SeeDot(self);
			else if (thug) thug.SeeDot(self);
		}
	}
	States
	{
	Spawn:
		TNT1 A -1 Light("LGLASER");
		Stop;
	}
}

// "!" over a cat that just saw the rdot.
class CatAlert : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		+BRIGHT
		Scale 1.2;
	}
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen()) return;
		if (!master || master.health <= 0 || GetAge() > 45) { Destroy(); return; }
		SetOrigin(master.pos + (0, 0, master.height + 10 + (GetAge() < 6 ? 6 - GetAge() : 0)), true);
	}
	States
	{
	Spawn:
		ALRT A -1;
		Stop;
	}
}

// What every cat does about a red rdot. Used by the cop cats and the thugs.
mixin class DotChaser
{
	Actor rdot;
	int chaseUntil, immuneUntil;

	void SeeDot(Actor d)
	{
		if (health <= 0 || bFriendly || level.maptime < immuneUntil || (rdot && level.maptime < chaseUntil)) return;
		if (Distance3D(d) > 700 || !CheckSight(d, SF_IGNOREVISIBILITY)) return;
		rdot = d;
		chaseUntil = level.maptime + 50;
		immuneUntil = level.maptime + 50 + 35 * 3;
		let a = Spawn("CatAlert", pos + (0, 0, height + 10), ALLOW_REPLACE);
		if (a) a.master = self;
		A_StartSound("lg/meow", CHAN_VOICE);
		SetStateLabel("DotChase");
	}

	// Run at the rdot, pounce when close; a cat under the rdot gets scratched and the two of them fight (infighting).
	void ChaseDot()
	{
		if (!rdot || level.maptime >= chaseUntil)
		{
			rdot = null;
			SetState(SeeState);
			return;
		}
		A_Face(rdot, 0, 0);
		double d = Distance2D(rdot);
		if (d > 44)
		{
			if (pos.z <= floorz) vel.xy = AngleToVector(angle, min(11, d / 6 + 4));
		}
		else if (pos.z <= floorz)
		{
			vel = (AngleToVector(angle, 3), 7);   // the pounce
			let it = BlockThingsIterator.Create(rdot, 64);
			while (it.Next())
			{
				let v = it.thing;
				if (v && v != self && v.bIsMonster && v.health > 0 && v.Distance2D(rdot) < 60)
				{
					v.DamageMobj(self, self, random(8, 14), 'Melee');
					A_StartSound("lg/hiss", CHAN_WEAPON);
					let h = LGHandler(EventHandler.Find("LGHandler"));
					if (h && level.maptime - h.announceAt > 140) h.Announce("CAT FIGHT!", Font.CR_ORANGE);
					target = v;
					break;
				}
			}
			chaseUntil = min(chaseUntil, level.maptime + 12);
		}
	}
}
