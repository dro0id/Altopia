"""Bibliothèque d'animations « humaines » pour le squelette Humanoid (49 os) + os de visage (Jaw, Blink, Brow, Eye, HairB).
Chaque clip = liste de (image, spec, fx) : spec = rotations en repère monde {os: [(axe, degrés)]} (+ "_t" : translations monde),
fx = {os: {"s": échelle, "l": translation locale, "r": (axe, degrés) rotation locale}}. Les clips bouclent. 24 images/s.
Principes : une couche de vie permanente (respiration, micro-mouvements de la tête, doigts détendus, regard) sous chaque geste ;
anticipation, dépassement et amorti sur les gestes ; décalage de phase le long de la colonne, des bras et des cheveux."""
import math, random

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
DL = 68   # bras le long du corps (A-pose)
TAU = 2 * math.pi

def cyc(t, k=1.0, ph=0.0): return math.sin(TAU * (k * t + ph))
def sm(u): u = max(0.0, min(1.0, u)); return u * u * (3 - 2 * u)
def spr(u, z=5.0, w=9.0):
    """dépassement amorti : 0 -> 1 avec un léger rebond"""
    u = max(0.0, u); return 1 - math.exp(-z * u) * math.cos(w * u)
def lerp(a, b, u): return a + (b - a) * u
def wp(t, pts):
    """interpolation lissée entre des points (t, valeur)"""
    if t <= pts[0][0]: return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1: return lerp(v0, v1, sm((t - t0) / max(1e-6, t1 - t0)))
    return pts[-1][1]

FINGERS = [(n, i, w) for n, idx, ws in (("Index", (2, 3, 4), (0.8, 1.0, 0.7)), ("Middle", (2, 3, 4), (0.9, 1.1, 0.8)), ("Ring", (2, 3, 4), (1.0, 1.1, 0.9)),
                                         ("Pinky", (2, 3, 4), (1.1, 1.2, 1.0)), ("Thumb", (2, 3), (0.5, 0.6))) for i, w in zip(idx, ws)]

def fingers(curl, left=None, right=None):
    """curl en degrés (doigts détendus ~15, poing ~70) ; left/right : surcharges par main"""
    fx = {}
    for sd, c in (("L", curl if left is None else left), ("R", curl if right is None else right)):
        for n, i, w in FINGERS: fx["%s%d.%s" % (n, i, sd)] = {"r": (X, -c * w)}
    return fx

def merge(*fxs):
    out = {}
    for f in fxs:
        for b, v in f.items(): out.setdefault(b, {}).update(v)
    return out

def base():
    return {"UpperArm.L": [(Y, DL)], "UpperArm.R": [(Y, -DL)], "UpperLeg.L": [(Y, 2.5)], "UpperLeg.R": [(Y, -2.5)]}

def S(*adds, over=None):
    d = base()
    if over:
        for k, v in over.items(): d[k] = list(v)
    for b, ax, deg in adds: d[b] = d.get(b, []) + [(ax, deg)]
    return d

def blink(a):
    s = (1.0, max(0.06, 1.0 - 0.94 * a), 1.0)
    return {"Blink.L": {"s": s}, "Blink.R": {"s": s}}

def blink_amt(f, events):
    """événements de clignement : liste d'images de départ ; profil fermeture rapide, ouverture un peu plus lente"""
    a = 0.0
    for e in events:
        u = f - e
        if 0 <= u < 5: a = max(a, [0.0, 0.85, 1.0, 0.7, 0.25][int(u)])
    return a

def gaze(gx, gy):
    return {"Eye.L": {"l": (gx * 0.004, gy * 0.004, 0)}, "Eye.R": {"l": (gx * 0.004, gy * 0.004, 0)}}

def face(spec, jaw=0.0, brow_up=0.0, brow_tilt=0.0):
    if jaw: spec["Jaw"] = spec.get("Jaw", []) + [(X, jaw)]
    if brow_tilt: spec["Brow.L"] = [(Y, brow_tilt)]; spec["Brow.R"] = [(Y, -brow_tilt)]
    return {"Brow.L": {"l": (0, 0.006 * brow_up, 0)}, "Brow.R": {"l": (0, 0.006 * brow_up, 0)}} if brow_up else {}

def life(t, a=1.0, curl=15.0):
    """couche de vie : respiration, tête qui flotte, bras et mains détendus, regard ; t = phase 0..1 du clip (période 4 s)"""
    b = cyc(t, 1, 0.0)
    adds = [("Chest", X, 1.4 * a * b), ("Torso", X, 0.9 * a * b), ("Abdomen", X, 0.7 * a * b), ("Neck", X, -0.8 * a * b),
            ("Shoulder.L", Z, 1.0 * a * b), ("Shoulder.R", Z, -1.0 * a * b),
            ("Head", Z, a * (2.2 * cyc(t, 1, 0.2) + 1.0 * cyc(t, 3, 0.5))), ("Head", X, a * (1.4 * cyc(t, 2, 0.1) - 0.5 * b)), ("Neck", Z, 0.5 * a * cyc(t, 1, 0.12)),
            ("UpperArm.L", X, 1.3 * a * cyc(t, 1, 0.28)), ("UpperArm.R", X, -1.3 * a * cyc(t, 1, 0.28)),
            ("LowerArm.L", X, 5 + 1.5 * a * cyc(t, 1, 0.1)), ("LowerArm.R", X, 5 - 1.5 * a * cyc(t, 1, 0.1)),
            ("Hand.L", X, 2 * a * cyc(t, 2, 0.4)), ("Hand.R", X, 2 * a * cyc(t, 2, 0.1)),
            ("HairB", X, 2 * a * cyc(t, 2, 0.8))]
    fx = merge(fingers(curl + 3 * a * cyc(t, 1, 0.3)), gaze(0.4 * a * cyc(t, 1, 0.1), 0.2 * a * cyc(t, 2, 0.5)))
    return adds, fx

def build(F, fn, step=2, blinks=(), extra_frames=()):
    """échantillonne fn(f, t) -> (spec, fx) toutes les `step` images + aux images de clignement ; boucle sur F images (image F+1 = image 1)"""
    frames = set(range(1, F + 2, step)) | {F + 1} | set(extra_frames)
    for e in blinks: frames |= {min(F + 1, e + k) for k in range(5)}
    out = []
    for f in sorted(frames):
        t = ((f - 1) % F) / F if f <= F else 0.0
        spec, fx = fn(f, t)
        if "HairB" in spec:   # les mèches ploient le long de la chaîne : chaque maillon prolonge le mouvement du précédent
            spec["HairB2"] = [(ax, 0.9 * dg) for ax, dg in spec["HairB"]]; spec["HairB3"] = [(ax, 1.1 * dg) for ax, dg in spec["HairB"]]
        ba = blink_amt(f, blinks)
        if ba: fx = merge(fx, blink(ba))
        out.append((f, spec, fx))
    return out

# ------------------------------------------------------------------------------------------------ clips
def clip_idle():
    F = 96
    def fn(f, t):
        ws = cyc(t, 1, 0.0)
        adds, fx = life(t)
        adds += [("Hips", Z, 2.2 * ws), ("Hips", Y, 1.6 * ws), ("Torso", Z, -1.4 * ws), ("Chest", Z, -0.8 * ws), ("Chest", Y, 1.0 * ws), ("Head", Y, -1.5 * ws),
                 ("Shoulder.L", Z, -1.2 * ws), ("Shoulder.R", Z, -1.2 * ws),
                 ("LowerLeg.L", X, 2 + 4 * max(0.0, -ws)), ("LowerLeg.R", X, 2 + 4 * max(0.0, ws)), ("UpperLeg.L", X, -1.5 * max(0.0, -ws)), ("UpperLeg.R", X, -1.5 * max(0.0, ws)),
                 ("Foot.L", X, 1.5 * max(0.0, -ws)), ("Foot.R", X, 1.5 * max(0.0, ws))]
        s = S(*adds); s["_t"] = {"Hips": (0.011 * ws, 0, -0.004 * abs(ws))}
        fx = merge(fx, face(s, jaw=0.4 + 0.3 * cyc(t, 1, 0.5), brow_up=0.25 * max(0.0, cyc(t, 1, 0.45) - 0.5) * 2))
        return s, fx
    return build(F, fn, 2, blinks=(28, 77, 83))

def clip_look():
    F = 120
    yaw = [(0, 0), (12, 0), (26, 28), (54, 28), (68, -22), (98, -22), (112, 0), (120, 0)]
    def fn(f, t):
        y = wp(f, yaw); ylead = wp(f + 4, yaw); ylag = wp(f - 6, yaw)
        adds, fx = life(t, 0.7)
        adds += [("Head", Z, y), ("Head", X, 3 * sm(abs(y) / 28)), ("Neck", Z, 0.3 * y), ("Torso", Z, 0.14 * ylag), ("Chest", Z, 0.1 * ylag), ("Hips", Z, 0.05 * ylag),
                 ("HairB", X, -0.1 * (y - ylag) * 3)]
        s = S(*adds)
        fx = merge(fx, gaze(ylead / 12.0, 0.0), face(s, brow_up=0.5 * sm(abs(ylead) / 28)))
        return s, fx
    return build(F, fn, 2, blinks=(36, 100))

def walk_pose(f, t, run=False):
    a = TAU * t
    sw, co = math.sin(a), math.cos(a)
    amp = 1.7 if run else 1.0
    L, R = sw, -sw
    th = (26 if not run else 46)
    kn = (38 if not run else 85)
    sl = lambda k: math.sin(a - k)           # phases retardées (bras plus lents que les jambes, cheveux en dernier)
    adds, fx = life(t % 1.0, 0.25, 12 if not run else 55)
    adds += [("UpperLeg.L", X, -th * L), ("UpperLeg.R", X, -th * R),
             ("LowerLeg.L", X, kn * max(0.0, -co) * (1 if L < 0.7 else 0) + 7 * max(0.0, co) * max(0.0, 1 - L)), ("LowerLeg.R", X, kn * max(0.0, co) * (1 if R < 0.7 else 0) + 7 * max(0.0, -co) * max(0.0, 1 - R)),
             ("Foot.L", X, 16 * max(0.0, -L) - 10 * max(0.0, L) * 0.6), ("Foot.R", X, 16 * max(0.0, -R) - 10 * max(0.0, R) * 0.6),
             ("UpperArm.L", X, (24 * amp) * sl(0.0) ), ("UpperArm.R", X, -(24 * amp) * sl(0.0)),
             ("LowerArm.L", X, (14 if not run else 78) + (10 * amp) * max(0.0, sl(0.5))), ("LowerArm.R", X, (14 if not run else 78) + (10 * amp) * max(0.0, -sl(0.5))),
             ("Hand.L", X, 8 * sl(1.0)), ("Hand.R", X, -8 * sl(1.0)),
             ("UpperArm.L", Y, 3 * co), ("UpperArm.R", Y, -3 * co),
             ("Hips", Z, 5 * amp * sw), ("Hips", Y, 3.0 * amp * co), ("Torso", Z, -4 * amp * sl(0.25)), ("Chest", Z, -3 * amp * sl(0.45)), ("Torso", Y, -1.5 * amp * co),
             ("Shoulder.L", Z, 3 * sl(0.3)), ("Shoulder.R", Z, -3 * sl(0.3)),
             ("Neck", Z, 2 * amp * sl(0.7)), ("Head", Z, 3 * amp * sl(0.9)), ("Head", X, -3 + 2.2 * abs(sl(0.6)) * amp + (-4 if run else 0)),
             ("Torso", X, 13 if run else 2.5), ("Abdomen", X, 4 if run else 0.5), ("Chest", X, 3 if run else 0.5),
             ("HairB", X, 5 * amp * sl(1.4))]
    s = S(*adds)
    bob = (0.014 if not run else 0.045) * amp * abs(math.cos(a)) + (0.0 if not run else 0.01 * sw * 0)
    s["_t"] = {"Hips": (0.016 * amp * (-sw) , 0, -bob * 0.0 + bob - (0.012 if not run else 0.03))}
    fx = merge(fx, fingers(14 if not run else 62), face(s))
    return s, fx

def clip_walk(run=False):
    F = 16 if run else 24
    def fn(f, t):
        s, fx = walk_pose(f, t, run)
        return s, fx
    return build(F, fn, 2, blinks=() if run else (13,))

def clip_shoot():
    def fn(f, t):
        a = wp(f, [(1, 0), (4, 0), (7, 84), (10, 90), (14, 84), (22, 0), (24, 0)])
        rec = wp(f, [(1, 0), (6, 0), (8, 7), (10, 3), (14, 1), (22, 0)])
        adds, fx = life(0.0, 0.3, 20)
        adds += [("Torso", X, -rec), ("Head", X, -rec * 0.6 + 3 * sm(a / 84)), ("Hips", X, rec * 0.4), ("Chest", X, -rec * 0.4), ("Neck", X, -rec * 0.3),
                 ("HairB", X, 6 * rec), ("Hips", Z, -6 * sm(a / 84)), ("Torso", Z, 8 * sm(a / 84)), ("UpperLeg.R", X, -4 * sm(a / 84)), ("UpperLeg.L", X, 6 * sm(a / 84)), ("LowerLeg.L", X, 6 * sm(a / 84))]
        s = S(*adds, over={"UpperArm.R": [(Y, -DL * (1 - sm(a / 84))), (Z, 0)]})
        s["UpperArm.R"] = [(Y, -DL * (1 - sm(a / 84))), (X, a)]
        s.setdefault("LowerArm.R", []).append((X, 8 * sm(a / 84)))
        fx = merge(fx, fingers(15, right=55 * sm(a / 84)), face(s, brow_tilt=8 * sm(a / 84)), blink(0.7 * sm(a / 84) * (1 if 7 <= f <= 12 else 0)))
        return s, fx
    return build(24, fn, 1)

def clip_talk():
    F = 72; rnd = random.Random(11)
    words = [(rnd.uniform(0.2, 0.6), rnd.uniform(0.4, 1.0)) for _ in range(14)]
    # enveloppe de la parole : pulses lissées
    pulses = []; t0 = 3.0
    for ln, amp in words:
        pulses.append((t0, t0 + ln * 24 * 0.55, amp)); t0 += ln * 24 * 0.55 + rnd.uniform(1.5, 4)
    def env(f):
        e = 0.0
        for a, b, amp in pulses:
            if a <= f <= b: e = max(e, amp * math.sin(math.pi * (f - a) / (b - a)))
        return e
    def fn(f, t):
        e = env(f); e2 = env(f + 3)
        jaw = 3.0 * e + 7.0 * e * abs(math.sin(TAU * f / 3.3 + 1.3 * math.sin(f)))
        adds, fx = life(t, 1.0)
        adds += [("Head", X, 3.5 * e2 - 1.0), ("Head", Z, 3 * cyc(t, 1, 0.1) + 2 * e * cyc(t, 3, 0.2)), ("Neck", X, 1.5 * e2), ("Chest", X, 1.0 * e2),
                 ("UpperArm.R", Y, 22 + 6 * e), ("UpperArm.R", X, 34 + 12 * e2 + 6 * cyc(t, 2, 0.1)), ("LowerArm.R", X, 66 + 16 * e + 10 * cyc(t, 3, 0.3)), ("LowerArm.R", Z, 12 * cyc(t, 3, 0.3) * e),
                 ("Hand.R", X, 14 * cyc(t, 3, 0.55) * e), ("Hand.R", Z, 8 * cyc(t, 3, 0.1) * e), ("UpperArm.L", X, 6 + 3 * e), ("LowerArm.L", X, 12 + 6 * e), ("HairB", X, 3 * e)]
        s = S(*adds)
        fx = merge(fx, fingers(15, right=15 + 20 * e), face(s, jaw=jaw, brow_up=0.15 + 0.9 * e2), gaze(0.3 * cyc(t, 2, 0.2), 0.2))
        return s, fx
    return build(F, fn, 1, blinks=(20, 55))

def clip_wave():
    F = 48
    def fn(f, t):
        u = sm((f - 1) / 8.0); dn = sm((F + 1 - f) / 8.0); ramp = min(u, dn)
        over = spr((f - 1) / 12.0, 4.5, 8.0) * dn
        osc = cyc(f / 24.0, 1.0)
        adds, fx = life(t, 0.7)
        adds += [("Head", Z, -7 * ramp), ("Head", X, 3 * ramp), ("Torso", Z, 4 * ramp), ("Chest", Z, 2 * ramp), ("Shoulder.R", Z, 8 * ramp), ("HairB", X, 4 * ramp * osc),
                 ("Hips", Z, -2 * ramp), ("LowerArm.R", Y, 32 * osc * ramp), ("Hand.R", Y, 24 * cyc(f / 24.0, 1.0, 0.12) * ramp), ("UpperArm.R", Z, 6 * osc * ramp)]
        s = S(*adds); s["UpperArm.R"] = [(Y, -DL + 138 * over), (Z, 6 * osc * ramp)]
        fx = merge(fx, fingers(15, right=8), face(s, jaw=2.5 * ramp * (1 if (f // 6) % 2 else 0.2), brow_up=0.5 * ramp), gaze(0.0, 0.3 * ramp))
        return s, fx
    return build(F, fn, 1, blinks=(26,))

def clip_nod():
    def fn(f, t):
        h = wp(f, [(1, 0), (4, -2), (8, 14), (12, 1), (15, -1), (19, 12), (24, 0)])
        adds, fx = life(0.0, 0.5)
        adds += [("Head", X, h), ("Neck", X, 0.35 * wp(f - 2, [(1, 0), (4, -2), (8, 14), (12, 1), (15, -1), (19, 12), (24, 0)])), ("Chest", X, 0.12 * h), ("Abdomen", X, 0.05 * h)]
        s = S(*adds); fx = merge(fx, face(s, brow_up=0.4 * sm(h / 14), jaw=0.3), gaze(0.0, -0.4 * h / 14))
        return s, fx
    return build(24, fn, 1)

def clip_shake():
    def fn(f, t):
        pts = [(1, 0), (4, 20), (9, -22), (14, 18), (19, -12), (24, 0)]
        h = wp(f, pts)
        adds, fx = life(0.0, 0.5)
        adds += [("Head", Z, h), ("Neck", Z, 0.35 * wp(f - 2, pts)), ("Torso", Z, 0.1 * wp(f - 4, pts)), ("Head", X, 1.5)]
        s = S(*adds); fx = merge(fx, face(s, brow_tilt=6, jaw=0.5), gaze(h / 10.0, 0.0))
        return s, fx
    return build(24, fn, 1, blinks=(10,))

def clip_think():
    F = 72
    def fn(f, t):
        u = sm((f - 1) / 12.0) * sm((F + 1 - f) / 12.0)
        adds, fx = life(t, 0.9)
        adds += [("Head", Z, 9 * u + 2 * cyc(t, 1, 0.1)), ("Head", X, -6 * u + 2 * cyc(t, 2, 0.4)), ("Hips", Z, 2 * u * cyc(t, 1)), ("Torso", Z, 3 * u), ("HairB", X, 2 * u),
                 ("Shoulder.R", Z, 3 * u), ("LowerArm.R", Z, 3 * cyc(t, 3, 0.2) * u)]
        s = S(*adds); s["UpperArm.R"] = [(Y, -DL + (DL - 38) * u), (Z, 55 * u)]; s["LowerArm.R"] = [(X, 5 - 100 * u), (Z, 28 * u)]
        fx = merge(fx, fingers(15, right=15 + 25 * u), face(s, brow_up=0.7 * u, brow_tilt=-4 * u), gaze(-0.8 * u, 0.9 * u))
        return s, fx
    return build(F, fn, 2, blinks=(30, 52))

def clip_point():
    def fn(f, t):
        a = wp(f, [(1, 0), (6, -0.18), (14, 1.0), (17, 1.08), (21, 1.0), (30, 1.0), (38, 0)])
        adds, fx = life(0.0, 0.5)
        adds += [("Torso", Z, 8 * a), ("Chest", Z, 3 * a), ("Head", Z, 10 * a), ("Head", X, 2), ("Hips", Z, 2 * a), ("Shoulder.R", Z, -4 * a), ("HairB", X, -3 * a)]
        s = S(*adds); s["UpperArm.R"] = [(Y, -DL * (1 - max(0.0, a))), (Z, 85 * a)]; s["LowerArm.R"] = [(X, 4 * a)]
        fx = merge(fx, fingers(15, right=15 + 40 * sm(a)), face(s, brow_up=0.4 * a), gaze(1.0 * a, 0.0))
        return s, fx
    return build(38, fn, 1, blinks=(24,))

def clip_work():
    F = 48
    def fn(f, t):
        adds, fx = life(t, 0.8)
        k = lambda ph: max(0.0, cyc(f / 6.0, 1.0, ph))
        adds += [("Abdomen", X, 9), ("Head", X, 12 + 2 * cyc(t, 1, 0.5)), ("Chest", X, 2 * cyc(t, 2)), ("Shoulder.L", Z, 3 * k(0)), ("Shoulder.R", Z, 3 * k(0.5)), ("HairB", X, 2)]
        s = S(*adds, over={"UpperArm.L": [(Y, 25), (Z, -80)], "UpperArm.R": [(Y, -25), (Z, 80)]})
        s["LowerArm.L"] = [(Z, -22 - 5 * cyc(f / 12.0))]; s["LowerArm.R"] = [(Z, 22 + 5 * cyc(f / 12.0, 1, 0.5))]
        s["Hand.L"] = [(X, 6 + 8 * k(0))]; s["Hand.R"] = [(X, 6 + 8 * k(0.5))]
        fx = merge(fx, fingers(30, left=28 + 14 * k(0.1), right=28 + 14 * k(0.6)), face(s, brow_tilt=3), gaze(0.4 * cyc(t, 3), -0.8))
        return s, fx
    return build(F, fn, 2, blinks=(16, 38))

def clip_salute():
    def fn(f, t):
        a = wp(f, [(1, 0), (4, 0), (8, 1.1), (11, 1.0), (28, 1.0), (31, 1.0), (35, -0.05), (38, 0)])
        adds, fx = life(0.0, 0.4)
        adds += [("Head", X, -3 * a), ("Chest", X, -2.5 * a), ("Abdomen", X, -1.5 * a), ("Shoulder.R", Z, 6 * a), ("UpperArm.R", Z, 30 * a), ("LowerArm.R", Y, 105 * a),
                 ("Hand.R", Z, 6 * a * cyc(f / 24.0, 3) * 0.3)]
        s = S(*adds); s["UpperArm.R"] = [(Y, -DL + DL * a), (Z, 30 * a)]
        fx = merge(fx, fingers(15, right=6), face(s, brow_tilt=5 * a, jaw=0.2), gaze(0, 0.3 * a))
        return s, fx
    return build(38, fn, 1)

def clip_cheer():
    F = 36
    def fn(f, t):
        ph = ((f - 1) % 18) / 18.0
        crouch = wp(ph * 18, [(0, 0), (3, 1), (5, 0.9), (7, -0.2), (13, 0), (17, 0.5), (18, 0)])
        air = max(0.0, wp(ph * 18, [(0, 0), (5, 0), (7, 1), (10, 1), (13, 0), (18, 0)]))
        adds, fx = life(t, 0.6)
        arms = air + 0.25 * (1 - air)
        adds += [("Hips", X, -6 * crouch), ("Torso", X, 5 * crouch), ("Head", X, -9 * air + 5 * crouch), ("Head", Z, 5 * cyc(t, 2)),
                 ("UpperLeg.L", X, -22 * crouch - 12 * air), ("UpperLeg.R", X, -22 * crouch - 12 * air), ("LowerLeg.L", X, 40 * crouch + 20 * air), ("LowerLeg.R", X, 40 * crouch + 20 * air),
                 ("Foot.L", X, -12 * crouch + 18 * air), ("Foot.R", X, -12 * crouch + 18 * air), ("Chest", X, -6 * air), ("HairB", X, 8 * air - 6 * crouch)]
        s = S(*adds, over={"UpperArm.L": [(Y, DL - (DL + 72) * arms + 6 * cyc(t, 2))], "UpperArm.R": [(Y, -DL + (DL + 72) * arms - 6 * cyc(t, 2))]})
        s["LowerArm.L"] = [(X, 5 + 20 * air)]; s["LowerArm.R"] = [(X, 5 + 20 * air)]
        s["_t"] = {"Hips": (0, 0, 0.075 * air - 0.05 * crouch)}
        fx = merge(fx, fingers(20, left=20 + 40 * air, right=20 + 40 * air), face(s, jaw=7 + 5 * air, brow_up=0.9))
        return s, fx
    return build(F, fn, 1)

def clip_surprise():
    def fn(f, t):
        a = wp(f, [(1, 0), (4, -0.2), (8, 1.15), (11, 1.0), (20, 1.0), (28, 0)])
        adds, fx = life(0.0, 0.6)
        adds += [("Head", X, -9 * a), ("Chest", X, -6 * a), ("Hips", X, 4 * a), ("Abdomen", X, -3 * a), ("UpperArm.L", Y, 14 * a), ("UpperArm.R", Y, -14 * a), ("UpperArm.L", X, -6 * a), ("UpperArm.R", X, -6 * a),
                 ("LowerArm.L", X, 14 * a), ("LowerArm.R", X, 14 * a), ("UpperLeg.L", X, 3 * a), ("UpperLeg.R", X, -3 * a), ("HairB", X, 8 * a)]
        s = S(*adds); s["_t"] = {"Hips": (0, 0.012 * a, 0)}
        fx = merge(fx, fingers(15 + 25 * a), face(s, jaw=14 * a, brow_up=1.3 * a), {"Blink.L": {"s": (1, 1 + 0.3 * a, 1)}, "Blink.R": {"s": (1, 1 + 0.3 * a, 1)}}, gaze(0, 0.5 * a))
        return s, fx
    return build(28, fn, 1)

def clip_laugh():
    F = 48
    def fn(f, t):
        r = sm((f - 1) / 8.0) * sm((F + 1 - f) / 8.0)
        w = TAU * f / 6.0
        adds, fx = life(t, 0.6)
        adds += [("Chest", X, 4 * math.sin(w) * r), ("Abdomen", X, 3 * math.sin(w + 0.4) * r), ("Torso", X, 2 * math.sin(w + 0.2) * r), ("Head", X, (-12 + 3 * math.sin(w - 0.3)) * r),
                 ("Shoulder.L", Z, 3 * math.sin(w) * r), ("Shoulder.R", Z, -3 * math.sin(w) * r), ("UpperArm.L", Y, 3 * math.sin(w) * r), ("UpperArm.R", Y, -3 * math.sin(w) * r),
                 ("Hips", X, 2 * math.sin(w + 0.8) * r), ("HairB", X, 5 * math.sin(w - 0.6) * r)]
        s = S(*adds); s["_t"] = {"Hips": (0, 0, 0.004 * math.sin(w) * r)}
        sq = 1 - 0.65 * r
        fx = merge(fx, face(s, jaw=(10 + 5 * math.sin(w)) * r, brow_up=0.6 * r), {"Blink.L": {"s": (1, sq, 1)}, "Blink.R": {"s": (1, sq, 1)}})
        return s, fx
    return build(F, fn, 1)

def clip_hit():
    def fn(f, t):
        a = wp(f, [(1, 0), (3, 1.25), (6, 0.8), (10, 0.4), (16, 0)])
        adds, fx = life(0.0, 0.4)
        adds += [("Torso", X, -14 * a), ("Head", X, -18 * a), ("Hips", X, 6 * a), ("UpperArm.L", Y, 12 * a), ("UpperArm.R", Y, -12 * a), ("Head", Z, 10 * a), ("Chest", Z, -5 * a), ("HairB", X, 10 * a),
                 ("UpperLeg.L", X, 8 * a), ("LowerLeg.L", X, 10 * a)]
        s = S(*adds); s["_t"] = {"Hips": (0, 0.02 * a, 0)}
        fx = merge(fx, fingers(15 + 40 * a), face(s, jaw=8 * a, brow_tilt=14 * a), blink(min(1.0, a)))
        return s, fx
    return build(16, fn, 1)

CLIPS = {
    "Idle": clip_idle, "Look": clip_look, "Walk": clip_walk, "Run": lambda: clip_walk(True), "Shoot": clip_shoot, "Talk": clip_talk, "Wave": clip_wave,
    "Nod": clip_nod, "Shake": clip_shake, "Think": clip_think, "Point": clip_point, "Work": clip_work, "Salute": clip_salute, "Cheer": clip_cheer,
    "Surprise": clip_surprise, "Laugh": clip_laugh, "Hit": clip_hit,
}
CORE = ("Idle", "Walk", "Shoot")
