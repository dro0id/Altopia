"""Bibliothèque d'animations « humaines » pour le squelette Humanoid (49 os) + os de visage (Jaw, Blink, Brow, HairB).
Chaque clip = liste de (image, spec, fx) : spec = rotations en repère monde {os: [(axe, degrés)]}, fx = {os: {"s": échelle, "l": translation locale}}.
Les clips bouclent (première image = dernière). 24 images/s."""
import math

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
DL = 68   # bras le long du corps (A-pose)

def base():
    return {"UpperArm.L": [(Y, DL)], "UpperArm.R": [(Y, -DL)], "UpperLeg.L": [(Y, 2.5)], "UpperLeg.R": [(Y, -2.5)]}

def S(*adds, over=None):
    """Pose de base + ajouts : S(("Head", X, 5), ("Abdomen", Z, 2)). over : remplace des os entiers."""
    d = base()
    if over:
        for k, v in over.items(): d[k] = list(v)
    for b, ax, deg in adds: d[b] = d.get(b, []) + [(ax, deg)]
    return d

def blink(a):
    s = (1.0, max(0.06, 1.0 - 0.94 * a), 1.0)
    return {"Blink.L": {"s": s}, "Blink.R": {"s": s}}

def widen(a):
    s = (1.0, 1.0 + 0.3 * a, 1.0)
    return {"Blink.L": {"s": s}, "Blink.R": {"s": s}}

def face(spec, jaw=0.0, brow_up=0.0, brow_tilt=0.0):
    """Ajoute mâchoire et sourcils à une pose : brow_tilt > 0 = sourcils en colère, < 0 = tristes."""
    if jaw: spec["Jaw"] = spec.get("Jaw", []) + [(X, jaw)]
    if brow_tilt: spec["Brow.L"] = [(Y, brow_tilt)]; spec["Brow.R"] = [(Y, -brow_tilt)]
    return {"Brow.L": {"l": (0, 0.006 * brow_up, 0)}, "Brow.R": {"l": (0, 0.006 * brow_up, 0)}} if brow_up else {}

def merge(*fxs):
    out = {}
    for f in fxs:
        for b, v in f.items(): out.setdefault(b, {}).update(v)
    return out

def hair_sway(spec, ang):
    spec["HairB"] = spec.get("HairB", []) + [(X, ang)]

def blink_track(frames, at, dur=3):
    """images de clignement (ouvert -> fermé -> ouvert) à partir de at"""
    return {at: 0.0, at + 1: 0.8, at + 2: 1.0, at + dur: 0.0}

def clip_idle():
    out = []
    F = 96
    for f in range(1, F + 2, 8):
        t = 2 * math.pi * (f - 1) / F
        s = S(("Chest", X, 1.2 * math.sin(t * 2)), ("Abdomen", X, 0.8 * math.sin(t * 2)), ("Torso", X, 0.5 * math.sin(t * 2)),
              ("Hips", Z, 1.8 * math.sin(t)), ("Torso", Z, -1.2 * math.sin(t)), ("Head", Z, 4 * math.sin(t + 1.0)), ("Head", X, 1.5 * math.sin(t * 2 + 0.5)),
              ("UpperArm.L", Y, 1.2 * math.sin(t * 2)), ("UpperArm.R", Y, -1.2 * math.sin(t * 2)), ("Shoulder.L", Z, 1.0 * math.sin(t * 2)), ("Shoulder.R", Z, -1.0 * math.sin(t * 2)),
              ("LowerArm.L", X, 3 + 1.5 * math.sin(t)), ("LowerArm.R", X, 3 - 1.5 * math.sin(t)))
        hair_sway(s, 2.5 * math.sin(t * 2 + 0.8))
        out.append((f, s, face(s, jaw=0.0, brow_up=0.15 * max(0.0, math.sin(t * 3)))))
    # clignements : on ajoute des images dédiées
    bl = {}
    for at in (30, 78): bl.update(blink_track(F, at))
    return merge_blinks(out, bl, F + 1)

def merge_blinks(frames, bl, last):
    """Insère des images de clignement dans un clip : interpole la pose entre les images existantes."""
    frames = sorted(frames, key=lambda t: t[0])
    def at(f):
        prev = max([x for x in frames if x[0] <= f], key=lambda x: x[0], default=frames[0])
        nxt = min([x for x in frames if x[0] >= f], key=lambda x: x[0], default=frames[-1])
        if prev[0] == nxt[0]: return prev
        u = (f - prev[0]) / (nxt[0] - prev[0])
        spec = {}
        keys = set(prev[1]) | set(nxt[1])
        def acc(lst):
            r = {}
            for ax, d in lst: r[ax] = r.get(ax, 0.0) + d
            return r
        for k in keys:
            if k == "_t":
                pt, nt = prev[1].get("_t", {}), nxt[1].get("_t", {})
                spec[k] = {bn: tuple(pt.get(bn, (0, 0, 0))[i] * (1 - u) + nt.get(bn, (0, 0, 0))[i] * u for i in range(3)) for bn in set(pt) | set(nt)}
                continue
            a = acc(prev[1].get(k, [])); b = acc(nxt[1].get(k, []))
            spec[k] = [(ax, a.get(ax, 0.0) * (1 - u) + b.get(ax, 0.0) * u) for ax in set(a) | set(b)]
        return (f, spec, prev[2])
    out = [x for x in frames]
    have = {x[0] for x in out}
    for f, a in sorted(bl.items()):
        if f in have:
            out = [(ff, sp, merge(fx, blink(a))) if ff == f else (ff, sp, fx) for ff, sp, fx in out]
        else:
            ff, sp, fx = at(f); out.append((f, sp, merge(fx, blink(a))))
    # images d'ouverture explicites autour des clignements pour éviter l'interpolation lente
    return sorted(out, key=lambda t: t[0])

def clip_look():
    F = 120; out = []
    seq = [(1, 0, 0, 0), (20, 28, 4, 5), (50, 28, 4, 5), (66, -22, 2, -4), (96, -22, 2, -4), (121, 0, 0, 0)]
    for f, hz, hx, tz in seq:
        s = S(("Head", Z, hz), ("Head", X, hx), ("Neck", Z, hz * 0.3), ("Torso", Z, tz), ("Chest", Z, tz * 0.5), ("Abdomen", X, 0.8))
        hair_sway(s, -hz * 0.1)
        out.append((f, s, face(s, brow_up=0.3 if f in (20, 50) else 0.0)))
    return merge_blinks(out, {38: 0.0, 39: 0.8, 40: 1.0, 42: 0.0, 104: 0.0, 105: 0.8, 106: 1.0, 108: 0.0}, F + 1)

def walk_pose(ph, amp=1.0, run=False):
    """ph : phase 0..1 (0 = pied gauche devant)"""
    a = 2 * math.pi * ph
    s26 = 26 * amp if not run else 48 * amp
    sw = math.sin(a); co = math.cos(a)
    L = sw; R = -sw
    # flexion du genou : jambe qui revient (derrière -> devant)
    kl = max(0.0, -co) * (35 if not run else 80) * amp * (1 if sw > -1 else 1)
    kr = max(0.0, co) * (35 if not run else 80) * amp
    d = S(("UpperLeg.L", X, -s26 * L), ("UpperLeg.R", X, -s26 * R), ("LowerLeg.L", X, kl if L < 0.6 else 0) , ("LowerLeg.R", X, kr if R < 0.6 else 0),
          ("Foot.L", X, 8 * co * amp), ("Foot.R", X, -8 * co * amp),
          ("UpperArm.L", X, 24 * amp * L * (1.6 if run else 1)), ("UpperArm.R", X, 24 * amp * R * (1.6 if run else 1)),
          ("LowerArm.L", X, (15 if not run else 80) + 10 * max(0, L)), ("LowerArm.R", X, (15 if not run else 80) + 10 * max(0, R)),
          ("Hips", Z, 5 * amp * sw), ("Torso", Z, -4 * amp * sw), ("Chest", Z, -2 * amp * sw), ("Head", Z, 3 * amp * sw), ("Head", X, -3 + 1.5 * abs(co)),
          ("Torso", X, 12 if run else 2), ("Abdomen", X, 4 if run else 0), ("Hips", Y, 2.5 * amp * co))
    bob = (0.012 if not run else 0.035) * amp * abs(math.cos(a))
    d["_t"] = {"Hips": (0, 0, bob)}
    hair_sway(d, 4 * math.cos(a * 2))
    return d

def clip_walk(run=False):
    n = 8 if run else 12   # images clés par cycle
    F = 16 if run else 24
    out = []
    for i in range(0, 9):
        ph = i / 8.0
        f = 1 + round(i * F / 8)
        s = walk_pose(ph, 1.0, run)
        out.append((f, s, face(s, jaw=0.0)))
    return merge_blinks(out, {} if run else {14: 0.0, 15: 1.0, 17: 0.0}, F + 1)

def clip_shoot():
    out = []
    for f, a, rec in ((1, 0, 0), (5, 80, 0), (8, 86, 6), (12, 84, 2), (20, 0, 0)):
        s = S(over={"UpperArm.R": [(Y, -40), (X, a)] if a else [(Y, -DL)]}); s.setdefault("LowerArm.R", []).append((X, 8 if a else 0))
        s.setdefault("Torso", []).append((X, -rec)); s.setdefault("Head", []).append((X, -rec * 0.6 + (4 if a else 0)))
        s.setdefault("Hips", []).append((X, rec * 0.4))
        out.append((f, s, face(s, brow_tilt=8 if a else 0)))
    return out

def clip_talk():
    F = 72; out = []
    import random; rnd = random.Random(7)
    for f in range(1, F + 2, 3):
        t = 2 * math.pi * (f - 1) / F
        j = 0 if f in (1, F + 1) else rnd.choice([0.5, 8.0, 12.0, 4.0, 10.0, 2.0])
        s = S(("Chest", X, 1.0 * math.sin(t * 3)), ("Head", X, 3 * math.sin(t * 2) + (3 if j > 7 else 0)), ("Head", Z, 4 * math.sin(t)), ("Torso", Z, 2 * math.sin(t)),
              ("UpperArm.R", X, 35 + 12 * math.sin(t * 2)), ("UpperArm.R", Y, 20), ("LowerArm.R", X, 70 + 15 * math.sin(t * 3)), ("LowerArm.R", Z, 12 * math.sin(t * 3)),
              ("UpperArm.L", X, 8 * math.sin(t * 2)), ("Hand.R", X, 10 * math.sin(t * 4)))
        s["UpperArm.R"] = [(Y, -DL + 20), (X, 35 + 12 * math.sin(t * 2))] if False else s["UpperArm.R"]
        out.append((f, s, face(s, jaw=j, brow_up=0.5 if j > 7 else 0.15)))
    return merge_blinks(out, {20: 0.0, 21: 0.9, 22: 1.0, 24: 0.0, 55: 0.0, 56: 0.9, 57: 1.0, 59: 0.0}, F + 1)

def clip_wave():
    F = 48; out = []
    for f in range(1, F + 2, 3):
        t = 2 * math.pi * (f - 1) / 24
        ramp = min(1.0, (f - 1) / 6, (F + 1 - f) / 6)
        s = S(); s["UpperArm.R"] = [(Y, -DL + 138 * ramp)]
        s["LowerArm.R"] = [(Y, 30 * math.sin(t) * ramp)]
        s["Hand.R"] = [(Y, 22 * math.sin(t + 1) * ramp)]
        s["Head"] = [(Z, -6 * ramp), (X, 3 * ramp)]; s["Torso"] = [(Z, 3 * ramp)]
        out.append((f, s, face(s, jaw=3 * ramp if (f // 6) % 2 else 0.5, brow_up=0.4 * ramp)))
    return merge_blinks(out, {26: 0.0, 27: 1.0, 29: 0.0}, F + 1)

def clip_nod():
    out = []
    for f, a in ((1, 0), (4, 14), (8, -1), (12, 12), (16, -1), (24, 0)):
        s = S(("Head", X, a), ("Neck", X, a * 0.3), ("Chest", X, a * 0.1)); out.append((f, s, face(s, brow_up=0.3 if a > 10 else 0)))
    return out

def clip_shake():
    out = []
    for f, a in ((1, 0), (4, 22), (9, -22), (14, 20), (19, -18), (24, 0)):
        s = S(("Head", Z, a), ("Neck", Z, a * 0.3), ("Torso", Z, a * 0.1)); out.append((f, s, face(s, brow_tilt=6)))
    return out

def clip_think():
    F = 72; out = []
    for f in range(1, F + 2, 6):
        t = 2 * math.pi * (f - 1) / F
        s = S(over={"UpperArm.R": [(Y, -30), (X, 60)], "LowerArm.R": [(X, 112 + 3 * math.sin(t))]})
        s["Head"] = [(Z, 8 + 3 * math.sin(t)), (X, -6 + 2 * math.sin(t * 2))]; s["Chest"] = [(X, 1 * math.sin(t * 2))]; s["Hips"] = [(Z, 2 * math.sin(t))]
        s["Brow.L"] = [(Y, 0)]
        out.append((f, s, face(s, brow_up=0.6, brow_tilt=-4)))
    return merge_blinks(out, {30: 0.0, 31: 1.0, 33: 0.0}, F + 1)

def clip_point():
    out = []
    for f, a in ((1, 0.0), (8, 1.0), (28, 1.0), (36, 0.0)):
        s = S(); s["UpperArm.R"] = [(Y, -DL * (1 - a)), (Z, 85 * a)]
        s["LowerArm.R"] = [(X, 4 * a)]; s["Torso"] = [(Z, 8 * a)]; s["Head"] = [(Z, 10 * a), (X, 2)]
        out.append((f, s, face(s, brow_up=0.4 * a)))
    return out

def clip_work():
    F = 48; out = []
    for f in range(1, F + 2, 3):
        t = 2 * math.pi * (f - 1) / 12
        s = S(over={"UpperArm.L": [(Y, 25), (Z, -62)], "UpperArm.R": [(Y, -25), (Z, 62)]})
        s["LowerArm.L"] = [(Z, -30 - 5 * math.sin(t))]; s["LowerArm.R"] = [(Z, 30 + 5 * math.sin(t))]
        s["Hand.L"] = [(X, 8 * math.sin(t))]; s["Hand.R"] = [(X, -8 * math.sin(t))]
        s["Abdomen"] = [(X, 9)]; s["Head"] = [(X, 12 + 2 * math.sin(t / 3))]; s["Chest"] = [(X, 1.0 * math.sin(2 * math.pi * (f - 1) / F * 2))]
        out.append((f, s, face(s, brow_tilt=3)))
    return merge_blinks(out, {16: 0.0, 17: 1.0, 19: 0.0, 38: 0.0, 39: 1.0, 41: 0.0}, F + 1)

def clip_salute():
    out = []
    for f, a in ((1, 0.0), (8, 1.0), (28, 1.0), (36, 0.0)):
        s = S(); s["UpperArm.R"] = [(Y, -DL + DL * a), (Z, 30 * a)]; s["LowerArm.R"] = [(Y, 105 * a)]; s["Head"] = [(X, -3 * a)]; s["Chest"] = [(X, -2 * a)]
        out.append((f, s, face(s, brow_tilt=5 * a)))
    return out

def clip_cheer():
    F = 36; out = []
    for f in range(1, F + 2, 3):
        t = 2 * math.pi * (f - 1) / 12
        up = max(0.0, math.sin(t))
        s = S(over={"UpperArm.L": [(Y, -72 + 8 * math.sin(t * 2))], "UpperArm.R": [(Y, 72 - 8 * math.sin(t * 2))]})
        s["LowerArm.L"] = [(X, 10 * up)]; s["LowerArm.R"] = [(X, 10 * up)]
        s["Hips"] = [(X, -4 * up)]; s["Head"] = [(X, -10 + 4 * up), (Z, 6 * math.sin(t / 2))]; s["UpperLeg.L"] = [(Y, 2.5), (X, -10 * up)]; s["UpperLeg.R"] = [(Y, -2.5), (X, -10 * up)]; s["LowerLeg.L"] = [(X, 18 * up)]; s["LowerLeg.R"] = [(X, 18 * up)]
        s["_t"] = {"Hips": (0, 0, 0.07 * up)}
        out.append((f, s, face(s, jaw=10 + 4 * math.sin(t * 2), brow_up=0.8)))
    return out

def clip_surprise():
    out = []
    for f, a in ((1, 0.0), (4, 1.0), (14, 1.0), (24, 0.0)):
        s = S(("Head", X, -8 * a), ("Chest", X, -6 * a), ("Hips", X, 4 * a), ("UpperArm.L", Y, 14 * a), ("UpperArm.R", Y, -14 * a), ("UpperArm.L", X, -6 * a), ("UpperArm.R", X, -6 * a))
        fx = merge(face(s, jaw=14 * a, brow_up=1.2 * a), widen(a)); out.append((f, s, fx))
    return out

def clip_laugh():
    F = 48; out = []
    for f in range(1, F + 2, 2):
        t = 2 * math.pi * (f - 1) / 6
        r = min(1.0, (f - 1) / 6, (F + 1 - f) / 6)
        s = S(("Chest", X, 4 * math.sin(t) * r), ("Abdomen", X, 3 * math.sin(t) * r), ("Head", X, (-12 + 3 * math.sin(t)) * r), ("Shoulder.L", Z, 3 * math.sin(t) * r), ("Shoulder.R", Z, -3 * math.sin(t) * r),
              ("UpperArm.L", Y, 3 * math.sin(t) * r), ("UpperArm.R", Y, -3 * math.sin(t) * r))
        fx = merge(face(s, jaw=(10 + 5 * math.sin(t)) * r, brow_up=0.6 * r), {"Blink.L": {"s": (1, 1 - 0.65 * r, 1)}, "Blink.R": {"s": (1, 1 - 0.65 * r, 1)}})
        out.append((f, s, fx))
    return out

def clip_hit():
    out = []
    for f, a in ((1, 0.0), (3, 1.0), (7, 0.6), (16, 0.0)):
        s = S(("Torso", X, -14 * a), ("Head", X, -18 * a), ("Hips", X, 6 * a), ("UpperArm.L", Y, 12 * a), ("UpperArm.R", Y, -12 * a), ("Head", Z, 10 * a))
        fx = merge(face(s, jaw=8 * a, brow_tilt=14 * a), blink(a)); out.append((f, s, fx))
    return out

CLIPS = {
    "Idle": clip_idle, "Look": clip_look, "Walk": clip_walk, "Run": lambda: clip_walk(True), "Shoot": clip_shoot, "Talk": clip_talk, "Wave": clip_wave,
    "Nod": clip_nod, "Shake": clip_shake, "Think": clip_think, "Point": clip_point, "Work": clip_work, "Salute": clip_salute, "Cheer": clip_cheer,
    "Surprise": clip_surprise, "Laugh": clip_laugh, "Hit": clip_hit,
}
CORE = ("Idle", "Walk", "Shoot")
