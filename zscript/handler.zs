// Los Gatos rules: cash, wanted level, the heist story told over the phone by Professor Whiskers, and the HUD.

class LGHandler : EventHandler
{
	// Crime and the police
	int heat;               // crime points: the wanted level grows with them
	int wanted;             // 0..5 paws
	int wantedAt;           // maptime of the last new paw (flash)
	int cruisersSent;
	int nextBackup;

	// The story
	int stage;              // 0 call, 1 street cash, 2 cruiser, 3 the tuna, 4 free roam
	int stageAt;
	String callText;        // the phone message on screen
	int callAt;
	String objective;
	int objectiveAt;
	String passedName;
	int passedAt;
	bool tunaOut;

	// HUD feedback
	int cashShown;
	String capText;
	int announceAt, announceColor;
	Array<String> popText;
	Array<int> popAt;

	static const int WANTED_HEAT[] = { 1, 6, 14, 26, 40 };
	const CASH_GOAL = 1500;

	int Cash()
	{
		let mo = players[consoleplayer].mo;
		return mo ? mo.CountInv("LGMoney") : 0;
	}

	void AddCash(int amount, Vector3 where)
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		mo.GiveInventory("LGMoney", amount);
		Pop(String.Format("+$%d", amount));
	}

	void Pop(String s)
	{
		popText.Push(s);
		popAt.Push(level.maptime);
		if (popText.Size() > 2) { popText.Delete(0); popAt.Delete(0); }
	}

	void Announce(String s, int color = Font.CR_GOLD)
	{
		capText = s;
		announceAt = level.maptime;
		announceColor = color;
	}

	int callDur;
	Sound callVoice;

	void Call(String s, Sound voice = "", int seconds = 9)
	{
		callText = s;
		callAt = level.maptime;
		callDur = seconds * 35;
		callVoice = voice;
		S_StartSound("lg/phone", CHAN_AUTO, CHANF_UI, 1., ATTN_NONE);
	}

	void SetObjective(String s)
	{
		objective = s;
		objectiveAt = level.maptime;
	}

	void Passed(String name)
	{
		passedName = name;
		passedAt = level.maptime;
		S_StartSound("lg/passed", CHAN_AUTO, CHANF_UI, 1., ATTN_NONE);
		let mo = players[consoleplayer].mo;
		if (mo) mo.GiveInventory("LGMoney", 1000);
	}

	void AddHeat(int n)
	{
		heat += n;
		int w = 0;
		while (w < 5 && heat >= WANTED_HEAT[w]) w++;
		if (w > wanted) SetWanted(w);
	}

	void SetWanted(int w)
	{
		if (w <= wanted) return;
		wanted = w;
		wantedAt = level.maptime;
		S_StartSound("lg/siren", CHAN_AUTO, CHANF_UI, 0.6, ATTN_NONE);
		// The police answer: more cop cats from 2 paws, a cruiser at 3, another at 5.
		if (w >= 2) SendCops(2);
		bool chase = stage == 2 || (stage == 4 && level.maptime - stageAt > 35 * 12);
		if (chase && ((w >= 3 && CountCruisers() == 0) || (w >= 5 && CountCruisers() < 2))) SendCruiser();
	}

	// A spot on the street, out of sight if possible, 500..900 units away.
	// z < 0: nothing found.
	Vector3 StreetSpot(PlayerPawn mo, Class<Actor> cls)
	{
		for (int pass = 0; pass < 2; pass++)
		{
			for (int i = 0; i < 40; i++)
			{
				Vector2 xy = mo.Vec2Angle(frandom(500, 900), frandom(0, 360));
				let sec = level.PointInSector(xy);
				if (sec.floorplane.ZatPoint(xy) != 0) continue;     // the road only
				let a = Actor.Spawn(cls, (xy, 0), NO_REPLACE);
				if (!a) continue;
				bool ok = a.TestMobjLocation() && (pass == 1 || !a.CheckSight(mo));
				a.Destroy();
				if (ok) return (xy, 0);
			}
		}
		return (0, 0, -1);
	}

	void SendCops(int n)
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		for (int i = 0; i < n; i++)
		{
			Vector3 at = StreetSpot(mo, "CatCop");
			if (at.z < 0) continue;
			let c = Actor.Spawn("CatCop", at, ALLOW_REPLACE);
			if (c) { c.target = mo; c.SetState(c.SeeState); }
		}
	}

	void SendCruiser()
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		Vector3 at = StreetSpot(mo, "PoliceCruiser");
		if (at.z < 0) return;
		let c = Actor.Spawn("PoliceCruiser", at, ALLOW_REPLACE);
		if (!c) return;
		c.target = mo;
		c.angle = c.AngleTo(mo);
		c.SetState(c.SeeState);
		cruisersSent++;
		Announce("POLICE CRUISER INCOMING", Font.CR_RED);
	}

	// Everyone in Los Gatos starts with Professor Whiskers' laser pistol.
	override void PlayerSpawned(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo) return;
		if (!mo.FindInventory("LaserPistol")) mo.GiveInventory("LaserPistol", 1);
		if (mo.FindInventory("Pistol", false) && !(mo.FindInventory("Pistol", false) is "LaserPistol")) mo.TakeInventory("Pistol", 1);
		mo.A_SelectWeapon("LaserPistol");
	}

	// Gunfire and blasts scare the tourists around them.
	override void WorldThingSpawned(WorldEvent e)
	{
		let t = e.Thing;
		if (!t || !(t is "BulletPuff" || t is "LaserDot" || t is "LGBoomFX" || t is "Molotov")) return;
		if (level.maptime - lastScare < 4) return;
		lastScare = level.maptime;
		let it = BlockThingsIterator.Create(t, 640);
		while (it.Next())
		{
			let p = TouristCat(it.thing);
			if (p && p.Distance3D(t) < 640) p.Scare(t.pos);
		}
	}
	int lastScare;

	override void WorldThingDied(WorldEvent e)
	{
		let t = e.Thing;
		if (!t) return;
		if (t is "TouristCat")
		{
			AddHeat(2);   // GTA: civilians are a crime
			let g = Actor.Spawn("CatGhost", t.pos + (0, 0, 10), ALLOW_REPLACE);
			if (g) { g.sprite = t.sprite; g.frame = 2; }
			return;
		}
		if (t is "PoliceCruiser")
		{
			AddHeat(3);
			// The cops had the Golden Tuna in the trunk.
			if (stage == 2 && !tunaOut)
			{
				NextStage();
				tunaOut = true;
				let g = Actor.Spawn("GoldenTuna", t.pos + (0, 0, 40), ALLOW_REPLACE);
				if (g) g.vel = (frandom(-2, 2), frandom(-2, 2), 9);
			}
			return;
		}
		if (!t.bIsMonster) return;
		bool cop = t is "CatCop";
		AddHeat(cop ? 2 : 1);
		// GTA: every body drops a wad of bills.
		let c = CashBag(Actor.Spawn("CashDrop", t.pos + (0, 0, 24), ALLOW_REPLACE));
		if (c)
		{
			c.vel = (frandom(-3, 3), frandom(-3, 3), 6);
			c.value = cop ? 300 : random(15, 25) * 10;
		}
		// Nine lives: the cat's ghost floats up.
		if (cop || t is "ThugCat")
		{
			let g = Actor.Spawn("CatGhost", t.pos + (0, 0, 10), ALLOW_REPLACE);
			if (g) { g.sprite = t.sprite; g.frame = 4; }
		}
	}

	void NextStage()
	{
		stage++;
		stageAt = level.maptime;
		Console.PrintfEx(PRINT_NONOTIFY, "LG_STAGE %d at %d", stage, level.maptime);
		switch (stage)
		{
		case 1:
			Call("Hairless ape. Professor Whiskers here. IQ 300, zero thumbs. You have thumbs. Together we rob Los Gatos. First, some seed money.", "lg/vo1", 13);
			SetObjective(String.Format("Collect \ck$%d\cj of street cash.", CASH_GOAL));
			break;
		case 2:
			Passed("STREET MONEY");
			break;
		case 3:
			Announce("THE GOLDEN TUNA!", Font.CR_GOLD);
			SetObjective("Grab the \ckGolden Tuna\cj.");
			break;
		case 4:
			Passed("THE BIG SCORE");
			break;
		}
	}

	override void WorldTick()
	{
		int real = Cash();
		if (cashShown < real) cashShown = min(real, cashShown + max(13, (real - cashShown) / 8));
		else cashShown = real;
		let mo = players[consoleplayer].mo;
		if (!mo) return;

		if (stage == 0 && level.maptime >= 20) NextStage();
		// Whiskers starts talking once the phone has buzzed.
		if (callVoice && level.maptime == callAt + 14) S_StartSound(callVoice, CHAN_VOICE, CHANF_UI, 1., ATTN_NONE);
		if (stage == 1 && real >= CASH_GOAL && level.maptime - callAt > callDur - 35) NextStage();   // after Whiskers hangs up
		// The calls that follow each passed mission, once the banner is gone.
		int since = level.maptime - stageAt;
		if (stage == 2 && since == 60 && CountCruisers() == 0) SendCruiser();   // on its way during the banner
		if (stage == 2 && since == 160)
		{
			Call("The cops took the Golden Tuna as evidence. It's in a cruiser. Blow it up. Cars explode. Cats don't. Mostly.", "lg/vo2", 11);
			SetObjective("Destroy the \ckpolice cruiser\cj.");
			SetWanted(max(wanted, 3));
			if (CountCruisers() == 0) SendCruiser();
		}
		if ((stage == 2 && since > 160 || stage == 4 && since > 35 * 12) && since % 500 == 0 && CountCruisers() == 0) SendCruiser();
		if (stage == 4 && since == 150)
		{
			Call("Twelve years of planning, for one can of tuna. Worth it. Now open it for me. Thumbs, ape. Thumbs!", "lg/vo3", 11);
			SetObjective("Free roam: the city is yours. Cause \ckchaos\cj.");
		}
		// The police keep coming while you're wanted.
		if (wanted >= 2 && level.maptime >= nextBackup && CountCops() < (CountCruisers() ? 2 : 3))
		{
			nextBackup = level.maptime + 35 * 12;
			SendCops(1 + wanted / 3);
		}
	}

	int CountCops()
	{
		int n = 0;
		let it = ThinkerIterator.Create("CatCop");
		Actor a;
		while (a = Actor(it.Next())) if (a.health > 0) n++;
		return n;
	}

	int CountCruisers()
	{
		int n = 0;
		let it = ThinkerIterator.Create("PoliceCruiser");
		Actor a;
		while (a = Actor(it.Next())) if (a.health > 0) n++;
		return n;
	}

	void TunaTaken()
	{
		if (stage < 4) { stage = 3; NextStage(); }
		else Pop("+$10000");
	}

	// ---------------------------------------------------------------- HUD
	ui double sc, ox, oy;

	ui void Frame()
	{
		sc = min(Screen.GetWidth() / 640., Screen.GetHeight() / 360.);
		ox = (Screen.GetWidth() - 640 * sc) / 2;
		oy = (Screen.GetHeight() - 360 * sc) / 2;
	}

	ui void Text(Font f, int color, double x, double y, String s, double alpha = 1., double size = 1.)
	{
		Screen.DrawText(f, color, ox + x * sc, oy + y * sc, s, DTA_ScaleX, sc * size, DTA_ScaleY, sc * size, DTA_Alpha, alpha);
	}

	// Text with a black outline, the GTA way.
	ui void Bold(Font f, int color, double x, double y, String s, double alpha = 1., double size = 1.)
	{
		for (int i = 0; i < 4; i++)
		{
			double dx = i == 0 ? -1 : (i == 1 ? 1 : 0), dy = i == 2 ? -1 : (i == 3 ? 1 : 0);
			Screen.DrawText(f, Font.CR_BLACK, ox + (x + dx * size) * sc, oy + (y + dy * size) * sc, s,
				DTA_ScaleX, sc * size, DTA_ScaleY, sc * size, DTA_Alpha, alpha, DTA_ColorOverlay, Color(255, 0, 0, 0));
		}
		Text(f, color, x, y, s, alpha, size);
	}

	ui void Box(double x, double y, double w, double h, Color c, double alpha)
	{
		Screen.Dim(c, alpha, int(ox + x * sc), int(oy + y * sc), int(w * sc), int(h * sc));
	}

	ui void Image(String name, double x, double y, double w, double h, double alpha = 1., Color tint = 0)
	{
		let t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return;
		Screen.DrawTexture(t, false, ox + x * sc, oy + y * sc, DTA_DestWidthF, w * sc, DTA_DestHeightF, h * sc, DTA_Alpha, alpha,
			DTA_ColorOverlay, tint, DTA_TopOffset, 0, DTA_LeftOffset, 0);
	}

	ui String Money(int v)
	{
		String s = String.Format("%d", v);
		String o = "";
		int n = s.Length();
		for (int i = 0; i < n; i++)
		{
			if (i && (n - i) % 3 == 0) o = o .. ",";
			o = o .. s.Mid(i, 1);
		}
		return "\cd$" .. o;   // a string starting with $ would be looked up in LANGUAGE
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (automapactive || gamestate != GS_LEVEL) return;
		Frame();
		let mo = players[consoleplayer].mo;
		Font f = NewSmallFont;
		double t = level.maptime + e.FracTic;

		// Cash, top right.
		String m = Money(cashShown);
		Bold(f, Font.CR_GREEN, 630 - f.StringWidth(m) * 2, 8, m, 1., 2.);
		for (int i = 0; i < popText.Size(); i++)
		{
			double age = t - popAt[i];
			if (age > 70) continue;
			Bold(f, Font.CR_GREEN, 630 - f.StringWidth(popText[i]) * 1.2, 34 + i * 11 - age * 0.1, popText[i], 1. - age / 70., 1.2);
		}

		// Wanted level: five paws, the newest one flashes.
		for (int i = 0; i < 5; i++)
		{
			bool lit = i < wanted;
			bool flash = lit && i == wanted - 1 && t - wantedAt < 140 && (level.maptime / 5) % 2;
			double x = 630 - (5 - i) * 21;
			if (lit) Image("LGPAW", x, 62, 19, 19, 1., flash ? Color(255, 255, 40, 40) : Color(0, 0, 0, 0));
			else Image("LGPAW", x, 62, 19, 19, 0.3, Color(255, 20, 20, 20));
		}
		if (wanted && t - wantedAt < 140 && (level.maptime / 5) % 2)
			Bold(f, Font.CR_RED, 630 - f.StringWidth("WANTED") * 1.5, 84, "WANTED", 1., 1.5);

		Radar(mo);
		Phone(f, t);

		// Opening title, then the radio station, GTA style.
		if (t < 130)
		{
			double a = clamp(min(t / 10., (130 - t) / 20.), 0., 1.);
			Box(150, 104, 340, 44, Color(0, 0, 0), 0.45 * a);
			String ti = "SUPERINTELLIGENT CAT";
			Bold(f, Font.CR_GOLD, 320 - f.StringWidth(ti) * 1.2, 106, ti, a, 2.4);
			String su = "a Los Gatos heist";
			Bold(f, Font.CR_WHITE, 320 - f.StringWidth(su) * 0.6, 134, su, a, 1.2);
		}
		if (t > 120 && t < 330)
		{
			double a = clamp(min((t - 120) / 10., (330 - t) / 20.), 0., 1.);
			String r1 = "PURR FM 104.9";
			String r2 = "West Coast Meow";
			Bold(f, Font.CR_WHITE, 400 - f.StringWidth(r1) * 1.0, 8, r1, a, 2.);
			Bold(f, Font.CR_GRAY, 400 - f.StringWidth(r2) * 0.6, 30, r2, a, 1.2);
		}

		// Objective, bottom middle, GTA subtitle style.
		if (objective.Length() && t - objectiveAt < 35 * 12)
		{
			double a = clamp((t - objectiveAt) / 10., 0., 1.);
			Bold(f, Font.CR_WHITE, 320 - f.StringWidth(objective) * 0.75, 296, objective, a, 1.5);
		}

		// Big caption.
		double aage = t - announceAt;
		if (capText.Length() && aage < 105)
		{
			double a = aage < 90 ? 1. : (105 - aage) / 15.;
			Bold(f, announceColor, 320 - f.StringWidth(capText) * 1.0, 250, capText, a, 2.);
		}

		// MISSION PASSED
		double pa = t - passedAt;
		if (passedName.Length() && pa < 35 * 4.5)
		{
			double a = clamp(min(pa / 8., (35 * 4.5 - pa) / 15.), 0., 1.);
			Box(0, 118, 640, 92, Color(0, 0, 0), 0.55 * a);
			String s = "MISSION PASSED";
			double grow = 4.2 - 0.8 * clamp(pa / 10., 0., 1.);
			Bold(f, Font.CR_GOLD, 320 - f.StringWidth(s) * grow / 2, 124 + (4.2 - grow) * 8, s, a, grow);
			Bold(f, Font.CR_WHITE, 320 - f.StringWidth(passedName) * 1.0, 170, passedName, a, 2.);
			String r = "RESPECT +";
			Bold(f, Font.CR_WHITE, 320 - f.StringWidth(r) * 0.75, 192, r, a, 1.5);
		}
	}

	// GTA V radar, bottom left: the city blocks turn around the player, enemies as dots.
	ui void Radar(PlayerPawn mo)
	{
		if (!mo) return;
		double rx = 10, ry = 222, rw = 150, rh = 96;
		double cx = rx + rw / 2, cy = ry + rh * 0.62;
		double k = 0.055;                       // virtual px per map unit
		Box(rx - 2, ry - 2, rw + 4, rh + 4, Color(10, 10, 10), 0.85);
		Box(rx, ry, rw, rh, Color(70, 90, 75), 0.75);
		Screen.SetClipRect(int(ox + rx * sc), int(oy + ry * sc), int(rw * sc), int(rh * sc));
		double ang = mo.angle;
		Vector2 fw = (cos(ang), sin(ang)), rt = (sin(ang), -cos(ang));
		for (int i = 0; i < level.Lines.Size(); i++)
		{
			let l = level.Lines[i];
			if (!l.backsector || l.frontsector.floorplane.ZatPoint(l.v1.p) == l.backsector.floorplane.ZatPoint(l.v1.p)) continue;
			Vector2 a = l.v1.p - mo.pos.xy, b = l.v2.p - mo.pos.xy;
			if (a.Length() > 1900 && b.Length() > 1900) continue;
			double ax = cx + (a dot rt) * k, ay = cy - (a dot fw) * k;
			double bx = cx + (b dot rt) * k, by = cy - (b dot fw) * k;
			// Liang-Barsky clip to the radar box.
			double t0 = 0, t1 = 1, dx = bx - ax, dy = by - ay;
			double p[4] = { -dx, dx, -dy, dy };
			double q[4] = { ax - rx, rx + rw - ax, ay - ry, ry + rh - ay };
			bool keep = true;
			for (int j = 0; j < 4; j++)
			{
				if (p[j] == 0) { if (q[j] < 0) keep = false; continue; }
				double r = q[j] / p[j];
				if (p[j] < 0) t0 = max(t0, r); else t1 = min(t1, r);
			}
			if (!keep || t0 > t1) continue;
			double x0 = ax + dx * t0, y0 = ay + dy * t0, x1 = ax + dx * t1, y1 = ay + dy * t1;
			Screen.DrawThickLine(int(ox + x0 * sc), int(oy + y0 * sc), int(ox + x1 * sc), int(oy + y1 * sc), 1.5 * sc, Color(200, 210, 200), 230);
		}
		// Blips.
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			Color c;
			double s = 4;
			if (a.bIsMonster && a.health > 0)
			{
				if (a is "PoliceCruiser") { c = (level.maptime / 6) % 2 ? Color(255, 40, 40) : Color(60, 90, 255); s = 7; }
				else if (a is "CatCop") c = (level.maptime / 6) % 2 ? Color(255, 60, 60) : Color(80, 120, 255);
				else c = Color(230, 60, 60);
			}
			else if (a is "GoldenTuna") { c = Color(255, 220, 40); s = 7; }
			else if (a is "CashBag") { c = Color(90, 255, 90); s = 3; }
			else continue;
			Vector2 d = a.pos.xy - mo.pos.xy;
			if (d.Length() > 1900) continue;
			double x = cx + (d dot rt) * k, y = cy - (d dot fw) * k;
			if (x < rx + 3 || x > rx + rw - 3 || y < ry + 3 || y > ry + rh - 3) continue;
			Box(x - s / 2 - 0.5, y - s / 2 - 0.5, s + 1, s + 1, Color(0, 0, 0), 1.);
			Box(x - s / 2, y - s / 2, s, s, c, 1.);
		}
		Screen.ClearClipRect();
		// The player: a white arrow.
		Color w = Color(255, 255, 255);
		Screen.DrawThickLine(int(ox + cx * sc), int(oy + (cy - 6) * sc), int(ox + (cx - 4) * sc), int(oy + (cy + 4) * sc), 2 * sc, w);
		Screen.DrawThickLine(int(ox + cx * sc), int(oy + (cy - 6) * sc), int(ox + (cx + 4) * sc), int(oy + (cy + 4) * sc), 2 * sc, w);
		Screen.DrawThickLine(int(ox + (cx - 4) * sc), int(oy + (cy + 4) * sc), int(ox + (cx + 4) * sc), int(oy + (cy + 4) * sc), 2 * sc, w);
		// Wanted: the radar frame flashes red and blue.
		if (wanted)
		{
			Color fc = (level.maptime / 8) % 2 ? Color(220, 30, 30) : Color(40, 70, 230);
			Box(rx - 2, ry - 2, rw + 4, 2, fc, 0.9);
			Box(rx - 2, ry + rh, rw + 4, 2, fc, 0.9);
			Box(rx - 2, ry - 2, 2, rh + 4, fc, 0.9);
			Box(rx + rw, ry - 2, 2, rh + 4, fc, 0.9);
		}
	}

	// Professor Whiskers' messages: a phone-style card, top left, the text typed in.
	ui void Phone(Font f, double t)
	{
		double age = t - callAt;
		if (!callText.Length() || age > callDur) return;
		double slide = clamp(age / 8., 0., 1.) * clamp((callDur - age) / 8., 0., 1.);
		double x = 10 - (1 - slide) * 300, y = 10, w = 286, h = 92;
		Box(x, y, w, h, Color(0, 0, 0), 0.78);
		Box(x, y, w, 12, Color(30, 120, 60), 0.95);
		Text(f, Font.CR_WHITE, x + 4, y + 2, "INCOMING CALL", 1., 0.8);
		Image("LGWHISK", x + 4, y + 16, 64, 64);
		Text(f, Font.CR_GOLD, x + 74, y + 16, "PROF. WHISKERS", 1., 1.);
		int shown = clamp(int((age - 14) * 1.9), 0, callText.Length());   // typed along with the voice
		String part = callText.Left(shown);
		let lines = f.BreakLines(part, int((w - 80) / 0.8));
		for (int i = 0; i < lines.Count() && i < 7; i++)
			Text(f, Font.CR_WHITE, x + 74, y + 29 + i * 8.5, lines.StringAt(i), 1., 0.8);
	}
}

// The ghost of one of a cat's nine lives, floating up out of the body.
class CatGhost : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		RenderStyle "Stencil";
		StencilColor "FFFFFF";
		Alpha 0.6;
	}
	States
	{
	Spawn:
		#### # 1
		{
			vel.z = 1.2;
			A_FadeOut(0.012);
			scale.x = 1 + sin(GetAge() * 12) * 0.08;
		}
		Loop;
	}
}

// The heist's target: a can of golden tuna. It pops out of the cruiser and, being tuna, comes to you.
class GoldenTuna : Actor
{
	Default
	{
		Radius 14;
		Height 20;
		+NOBLOCKMAP
		+BRIGHT
		Scale 1.8;
		Gravity 0.6;
	}
	override void Tick()
	{
		Super.Tick();
		if (IsFrozen()) return;
		let mo = players[consoleplayer].mo;
		if (level.maptime % 3 == 0)
			A_SpawnParticle(0xFFE060, SPF_FULLBRIGHT, 30, 4, frandom(0, 360), frandom(4, 14), 0, frandom(0, 24), 0, 0, 0.6);
		if (!mo || GetAge() < 95) return;   // first the driver lands, then the tuna comes
		double d = Distance3D(mo);
		if (d < 40)
		{
			let h = LGHandler(EventHandler.Find("LGHandler"));
			if (h) h.TunaTaken();
			A_StartSound("lg/cash", CHAN_AUTO, CHANF_UI, 1., ATTN_NONE);
			Destroy();
			return;
		}
		if (d < 520)
		{
			bNoGravity = true;
			Vector3 to = (mo.pos + (0, 0, 28)) - pos;
			vel = to.Unit() * min(9, 2.5 + (520 - d) / 45);
			A_SpawnParticle(0xFFD040, SPF_FULLBRIGHT, 20, 6, 0, 0, 0, 10, frandom(-1, 1), frandom(-1, 1), frandom(-1, 1));
		}
	}
	States
	{
	Spawn:
		TUNA A -1 Light("LGTUNA");
		Stop;
	}
}
