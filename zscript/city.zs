// Los Gatos props: palm trees and cash.

class LGPalm : Actor
{
	Default
	{
		Radius 10;
		Height 200;
		ProjectilePassHeight -16;
		+SOLID
		Tag "Palm Tree";
	}
	States
	{
	Spawn:
		PALM A -1;
		Stop;
	}
}

// Rooftop billboard: Professor Whiskers runs for mayor. It turns to the viewer, so it never reads backwards.
class WhiskersBillboard : Actor
{
	Default
	{
		Radius 8;
		Height 120;
		+NOGRAVITY
		+NOBLOCKMAP
	}
	States
	{
	Spawn:
		BILL A -1;
		Stop;
	}
}

// The player's wallet: the HUD shows it as GTA-style cash.
class LGMoney : Inventory
{
	Default
	{
		Inventory.MaxAmount 99999999;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.KEEPDEPLETED
	}
}

class CashBag : CustomInventory
{
	int value;
	property Value: value;
	Default
	{
		Radius 14;
		Height 26;
		CashBag.Value 1000;
		Inventory.PickupMessage "";
		Inventory.PickupSound "lg/cash";
		+INVENTORY.ALWAYSPICKUP
		+FLOATBOB
	}
	States
	{
	Spawn:
		CASH A -1;
		Stop;
	Pickup:
		TNT1 A 0
		{
			let h = LGHandler(EventHandler.Find("LGHandler"));
			if (h) h.AddCash(invoker.value, invoker.pos);
			else A_GiveInventory("LGMoney", invoker.value);
		}
		Stop;
	}
}

// A small wad of bills: what a cat drops when it goes down.
class CashDrop : CashBag
{
	Default
	{
		Scale 0.6;
		Radius 10;
		Height 16;
		CashBag.Value 250;
		-FLOATBOB
	}

	// Loose bills blow toward you when you're close: the street cash vacuums into your pockets.
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen() || owner || GetAge() < 25) return;
		let mo = players[consoleplayer].mo;
		if (!mo || mo.health <= 0) return;
		double d = Distance3D(mo);
		if (d < 36)
		{
			let h = LGHandler(EventHandler.Find("LGHandler"));
			if (h) h.AddCash(value, pos);
			else mo.GiveInventory("LGMoney", value);
			mo.A_StartSound("lg/cash", CHAN_ITEM);
			Destroy();
			return;
		}
		if (d < 340)
		{
			bNoGravity = true;
			vel = ((mo.pos + (0, 0, 24)) - pos).Unit() * (6 + (340 - d) / 25);
			if (level.maptime % 2 == 0) A_SpawnParticle(0x60FF60, SPF_FULLBRIGHT, 10, 3);
		}
	}
}

// Tourist cats strolling the sidewalks. Gunfire or an explosion nearby and they run for it, screaming.
class TouristCat : Actor
{
	int nextTurn, panicUntil;
	Vector3 fleeFrom;
	Default
	{
		Health 30;
		Radius 14;
		Height 54;
		Mass 100;
		Speed 2;
		PainChance 255;
		PainSound "lg/hiss";
		DeathSound "lg/yowl";
		Tag "Tourist";
		+SOLID
		+SHOOTABLE
		+NEVERTARGET
		+FLOORCLIP
	}

	void Scare(Vector3 from)
	{
		if (health <= 0) return;
		if (level.maptime >= panicUntil) A_StartSound("lg/meow", CHAN_VOICE);
		fleeFrom = from;
		panicUntil = level.maptime + 35 * 4;
	}

	double Free(double yaw, double dist)
	{
		FLineTraceData d;
		if (!LineTrace(yaw, dist, 0, TRF_THRUACTORS, 20, data: d)) return dist;
		return d.Distance;
	}

	void Stroll()
	{
		if (health <= 0) return;
		bool panic = level.maptime < panicUntil;
		double sp = panic ? 7 : 2;
		if (panic)
		{
			double away = atan2(pos.y - fleeFrom.y, pos.x - fleeFrom.x);
			if (abs(deltaangle(angle, away)) > 60 || Free(angle, 48) < 40) angle = away + frandom(-30, 30);
			if (Free(angle, 48) < 40) angle += 90;
		}
		else
		{
			// Stay on the sidewalk: turn at walls and at the curb.
			Vector2 ahead = pos.xy + AngleToVector(angle, 28);
			double fz = level.PointInSector(ahead).floorplane.ZatPoint(ahead);
			if (level.maptime >= nextTurn || Free(angle, 40) < 36 || fz < floorz - 4)
			{
				angle = round(angle / 90.) * 90 + (random(0, 1) ? 90 : -90);
				if (random(0, 3) == 0) angle += 180;
				nextTurn = level.maptime + random(70, 160);
			}
		}
		if (pos.z <= floorz + 1) vel.xy = AngleToVector(angle, sp);
		if (panic && InStateSequence(CurState, ResolveState("Spawn"))) SetStateLabel("Panic");
		else if (!panic && InStateSequence(CurState, ResolveState("Panic"))) SetStateLabel("Spawn");
	}

	override void Tick()
	{
		Super.Tick();
		if (!IsFrozen()) Stroll();
	}

	States
	{
	Spawn:
		PEDC A 10;
		PEDC B 10;
		Loop;
	Panic:
		PEDC C 3;
		PEDC C 3 { scale.y = 0.94; }
		PEDC C 3 { scale.y = 1.0; }
		Loop;
	Pain:
		PEDC C 6 A_Pain;
		Goto Panic;
	Death:
		PEDC C 6 A_Scream;
		PEDC D 4 A_NoBlocking;
		PEDC D 420;
		PEDC D 1 A_FadeOut(0.04);
		Wait;
	}
}
