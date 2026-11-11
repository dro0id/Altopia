extends Node
## État de la partie (autoload « Game ») : niveaux des héros, crédits, éclats, étage atteint, étoiles, coffres, sauvegarde, gains hors ligne.

const Data = preload("res://scripts/data.gd")

signal changed

const SAVE_VERSION := 4
const AUTOSAVE_EVERY := 10.0

var save_path := "user://save.json"
var credits := 0.0
var shards := 0                 # éclats de verre (paliers d'évolution, plus tard)
var levels := {}                # héros -> niveau
var stage := 1                  # étage en cours
var best_stage := 1             # étage le plus haut débloqué
var stars := {}                 # étage -> meilleures étoiles (1 à 3)
var pity := {"leg": 0, "ult": 0}
var perseverance := 0          # défaites d'affilée : +5 % de statistiques chacune, remis à zéro à la victoire
var boosts: Array = []         # renforts actifs jusqu'au prochain boss
var wild := 0                   # doublons « au choix » : à répartir sur n'importe quel héros
var pending_chest := {}        # coffre gagné mais pas encore ouvert à l'écran
var owned := {}                # héros possédés (id -> true)
var hero_stars := {}           # héros -> rang d'étoiles (1 à 5, 6 = « 5★ max »)
var fragments := {}            # héros -> doublons pour la prochaine étoile
var squad: Array = []          # les 5 héros au combat, un par emplacement (0 = première ligne au centre)
var seen_scenes: Array = []      # scènes d'histoire déjà vues (branche 2)
var story_choices := {}          # réponse choisie par le Capitaine, par scène
var chapters_done: Array = []
var tips: Array = []
var inf_diff := 1.0                # difficulté adaptative des secteurs générés (vise 85 % de victoires)
var gen_tries := 0
var gen_wins := 0
var sectors_seen: Array = []       # secteurs générés déjà présentés               # astuces déjà montrées (ex. « items »)    # chapitres terminés (récompense versée)
var item_tokens := 0           # jetons d'objet (caisses d'équipement)
var item_pack_pity := {"epic": 0, "leg": 0}
var item_pulls: Array = []       # derniers objets ouverts {slot, rarity}, les plus récents en tête
var tokens := 0                # jetons de recrutement (gagnés en jeu)
var crystals := 0              # cristaux d'Altopia (monnaie de la boutique)
var recruit_pity := {"rare": 0, "epic": 0}
var pulls := 0                 # nombre total de tirages
var auto_cast := true
var speed := 1.0
var sfx_on := true
var music_vol := 0.7
var sfx_vol := 1.0
var haptics := true
var dmg_numbers := true
var battery_saver := false
var reduce_shake := false
var battery_auto := true          # passe à 30 images par seconde quand la batterie descend sous 20 %
var text_size := 0                # 0 normal, 1 grand, 2 très grand (réglage de lisibilité)
var music_on := true
var tutorial_done := false
var intro_seen := false
var last_seen := 0
var last_free_chest := 0
var items: Array = []             # tous les objets possédés (portés ou en inventaire)
var next_item := 1
var stash: Array = []             # objets trouvés alors que l'inventaire était plein
var auto_recycle := true          # recyclage automatique des objets communs
var item_pity := 0                # gros boss de suite sans objet légendaire
var last_drop: Dictionary = {}    # dernier objet reçu {item, status} pour l'écran de butin
var last_pulls: Array = []       # derniers héros obtenus au recrutement (id, rareté), les plus récents en tête
var daily_day := -1             # jour (UTC) de l'offre du jour déjà achetée
var boost_until := 0            # fin du boost de crédits ×2 (secondes Unix)
var offline_report := {}        # {seconds, credits} calculé au chargement
var orders := Orders.new()
var board := BoardEvents.new()
var talents := {}                  # héros -> {"2": 0 ou 1, "3": …} (maquette WG)     # événements à bord (maquette WK)       # ordres du jour et solde de la semaine (maquette WJ)
var ship := ShipState.new()      # le vaisseau l'Aurore (branche 5)
var rng := RandomNumberGenerator.new()
var _timer := 0.0
var _ship_t := 0.0
signal ship_events(events: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.H = maxf(1280.0, get_viewport().get_visible_rect().size.y)
	rng.randomize()
	reset()
	load_game()


func _process(delta: float) -> void:
	_ship_t += delta
	if _ship_t >= 1.0:
		_ship_t = 0.0
		ship_update()
		# événements à bord : seulement une fois le voyage du chapitre 1 terminé (pas pendant le tutoriel)
		if mission_open() and tips.has("ship"):
			if not board.update(1.0, ship, rng, int(Time.get_unix_time_from_system())).is_empty():
				changed.emit()
	_timer += delta
	if _timer >= AUTOSAVE_EVERY:
		_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func reset() -> void:
	orders = Orders.new()
	talents = {}
	board = BoardEvents.new()
	items = []
	next_item = 1
	stash = []
	auto_recycle = true
	item_pity = 0
	last_drop = {}
	last_pulls = []
	item_tokens = 4
	seen_scenes = []
	story_choices = {}
	chapters_done = []
	tips = []
	item_pack_pity = {"epic": 0, "leg": 0}
	item_pulls = []
	daily_day = -1
	boost_until = 0
	credits = 0.0
	shards = 0
	levels = {}
	for id in Data.ALL_HEROES:
		levels[id] = 1
		hero_stars[id] = 1
		fragments[id] = 0
	owned = {}
	for id in Data.STARTER:
		owned[id] = true
	squad = Data.STARTER.duplicate()
	tokens = 6                  # deux tirages offerts pour découvrir le recrutement
	crystals = 0
	recruit_pity = {"rare": 0, "epic": 0}
	pulls = 0
	stage = 1
	best_stage = 1
	stars = {}
	pity = {"leg": 0, "ult": 0}
	perseverance = 0
	boosts = []
	wild = 0
	pending_chest = {}
	auto_cast = true
	speed = 1.0
	sfx_on = true
	music_on = true
	tutorial_done = false
	intro_seen = false
	last_free_chest = 0
	offline_report = {}
	ship = ShipState.new()


func team() -> Array:
	var out: Array = []
	var mods: Dictionary = synergy().mods
	for id in squad:
		if id == "" or id == null:
			continue
		out.append({"id": id, "level": int(levels[id]), "evo": tier(id), "bonus": 1.0 + Data.PERSEVERANCE_STEP * perseverance, "stars": int(hero_stars[id]), "mods": mods, "eq": Items.totals(hero_items(id)), "ship": ship_combat(), "tal": talent_fx(id)})
	return out


# ---------------------------------------------------------------- talents (maquette WG)

## Choix du talent pour une étoile (0 ou 1), ou -1.
func talent_choice(id: String, tier: int) -> int:
	return int(talents.get(id, {}).get(str(tier), -1))


## Étoiles atteintes dont le talent n'est pas encore choisi.
func talents_open(id: String) -> int:
	if not is_owned(id):
		return 0
	var n := 0
	for tier in Data.TALENT_TIERS:
		if int(hero_stars.get(id, 1)) >= tier and talent_choice(id, tier) < 0:
			n += 1
	return n


## Choisit un talent ; changer d'avis coûte des éclats. Renvoie "" ou la raison du refus.
func set_talent(id: String, tier: int, i: int) -> String:
	if int(hero_stars.get(id, 1)) < tier:
		return "Étoile %d★ requise" % tier
	var cur := talent_choice(id, tier)
	if cur == i:
		return ""
	if cur >= 0:
		if shards < Data.TALENT_RESPEC:
			return "Il faut %d éclats pour changer d’avis" % Data.TALENT_RESPEC
		shards -= Data.TALENT_RESPEC
	if not talents.has(id):
		talents[id] = {}
	talents[id][str(tier)] = i
	changed.emit()
	return ""


## Effets cumulés des talents choisis d'un héros.
func talent_fx(id: String) -> Dictionary:
	var out := {}
	var role := String(Data.HEROES[id].role)
	for tier in Data.TALENT_TIERS:
		var c := talent_choice(id, tier)
		if c < 0 or int(hero_stars.get(id, 1)) < tier:
			continue
		var fx: Dictionary = Data.TALENTS[role][tier][c].fx
		for k in fx:
			out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out


## Héros réellement présents dans l'escouade (sans emplacement vide).
func squad_ids() -> Array:
	var out: Array = []
	for id in squad:
		if id != "" and id != null:
			out.append(id)
	return out


func synergy() -> Dictionary:
	return Data.synergies(squad_ids())


func squad_avg_level() -> float:
	var ids := squad_ids()
	var t := 0.0
	for id in ids:
		t += float(levels[id])
	return t / maxf(1.0, float(ids.size()))


func power() -> float:
	var p := Data.team_power(levels, squad_ids())
	for id in squad_ids():
		p += hero_item_power(id)
	return p


func is_owned(id: String) -> bool:
	return owned.has(id)


## Complète les emplacements vides avec des héros possédés qui ne sont pas encore dans l'escouade.
func _normalize_squad() -> void:
	for i in Data.SQUAD_SIZE:
		if squad[i] == "":
			for id in Data.ALL_HEROES:
				if owned.has(id) and not squad.has(id):
					squad[i] = id
					break


## Met un héros possédé dans un emplacement ; s'il est déjà dans l'escouade, les deux emplacements s'échangent.
func set_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= Data.SQUAD_SIZE or not is_owned(id):
		return false
	var other := squad.find(id)
	if other >= 0 and other != slot:
		squad[other] = squad[slot]
	squad[slot] = id
	ship.clean_posts(self)
	changed.emit()
	return true


func star_cost(id: String) -> int:
	return Data.star_cost(int(hero_stars[id]))


## Doublons disponibles pour ce héros : les siens, plus les doublons au choix.
func copies_for(id: String) -> int:
	return int(fragments[id]) + wild


func can_star_up(id: String) -> bool:
	return is_owned(id) and int(hero_stars[id]) < Data.MAX_STARS and copies_for(id) >= star_cost(id)


## Monte d'une étoile : on dépense d'abord les doublons du héros, puis les doublons au choix.
func star_up(id: String) -> bool:
	if not can_star_up(id):
		return false
	var cost := star_cost(id)
	var own := mini(int(fragments[id]), cost)
	fragments[id] = int(fragments[id]) - own
	wild -= cost - own
	hero_stars[id] = int(hero_stars[id]) + 1
	changed.emit()
	return true


## Recrutement : `count` tirages (1 ou 10). Renvoie la liste des résultats {id, rarity, new, fragments}, vide si pas assez de jetons.
func recruit(count: int) -> Array:
	var cost: int = Data.RECRUIT_COST_10 if count == 10 else Data.RECRUIT_COST * count
	if tokens < cost:
		return []
	tokens -= cost
	orders.track("recruit", count)
	var out: Array = []
	for i in count:
		var rarity := Data.roll_recruit(rng, recruit_pity)
		var pool := Data.heroes_of_rarity(rarity)
		var id: String = pool[rng.randi() % pool.size()]
		if rarity == "epic" and rng.randf() < 0.5:
			id = Data.featured_hero(_today())
		if pulls == 0 and (is_owned(id) or id == "vance"):
			# première recrue du voyage (chapitre 1) : toujours un nouveau visage
			# Vance est déjà à bord dans l'histoire (il pilote l'Aurore) : la première recrue est quelqu'un d'autre
			var fresh: Array = Data.ALL_HEROES.filter(func(h): return not is_owned(h) and h != "vance" and Data.HEROES[h].rarity == rarity)
			if fresh.is_empty():
				fresh = Data.ALL_HEROES.filter(func(h): return not is_owned(h) and h != "vance")
			if not fresh.is_empty():
				id = fresh[rng.randi() % fresh.size()]
				rarity = String(Data.HEROES[id].rarity)
		var is_new := not is_owned(id)
		var frag := 0
		if is_new:
			owned[id] = true
		else:
			frag = Data.DUP_COPIES
			fragments[id] = int(fragments[id]) + frag
		pulls += 1
		last_pulls.push_front({"id": id, "rarity": rarity})
		if last_pulls.size() > 5:
			last_pulls.pop_back()
		out.append({"id": id, "rarity": rarity, "new": is_new, "fragments": frag})
	changed.emit()
	return out


## Ouverture de caisses d'équipement : `count` 1 ou 10. Renvoie [{item, status}] (status : added / stash / recycled), vide si pas assez de jetons.
func open_item_packs(count: int) -> Array:
	var cost: int = Data.ITEM_PACK_COST_10 if count == 10 else Data.ITEM_PACK_COST * count
	if item_tokens < cost:
		return []
	item_tokens -= cost
	var out: Array = []
	var guard := count >= 10
	for i in count:
		var r := Items.roll_pack_rarity(rng, item_pack_pity, guard and i == count - 1 and not _has_rare(out))
		var res := receive_item(Items.roll(rng, r, maxi(1, best_stage)))
		out.append(res)
		item_pulls.push_front({"slot": res.item.slot, "rarity": res.item.rarity})
		if item_pulls.size() > 6:
			item_pulls.pop_back()
	changed.emit()
	return out


func _has_rare(res: Array) -> bool:
	for r in res:
		if Items.rarity_index(r.item.rarity) >= 2:
			return true
	return false


## Achat en boutique avec des cristaux. Renvoie un texte de résultat, vide si l'achat est impossible.
func buy(item_id: String) -> String:
	var items: Array = Data.SHOP_ITEMS.duplicate()
	items.append(Data.DAILY_OFFER)
	for it in items:
		if it.id != item_id:
			continue
		if crystals < int(it.cost):
			return ""
		if it.id == "daily":
			if not daily_available():
				return ""
			daily_day = _today()
		crystals -= int(it.cost)
		var msg: Array = []
		if it.has("boost"):
			boost_until = maxi(boost_until, int(Time.get_unix_time_from_system())) + int(float(it.boost) * 3600.0)
			msg.append("Boost ×2 actif : %s" % UI.duration(boost_remaining()))
		if it.has("tokens"):
			tokens += int(it.tokens)
			msg.append("+ %d jetons" % int(it.tokens))
		if it.has("copies"):
			wild += int(it.copies)
			msg.append("+ %d doublons au choix" % int(it.copies))
		if it.has("item_tokens"):
			item_tokens += int(it.item_tokens)
			msg.append("+ %d jetons d'objet" % int(it.item_tokens))
		if it.has("chest"):
			var c := open_chest(String(it.chest), maxi(1, best_stage - 1))
			msg.append("Coffre %s : + %s crédits, + %d éclats" % [String(Data.RARITY_NAMES[c.rarity]).to_lower(), Data.fmt(c.credits), int(c.shards)])
		changed.emit()
		return " · ".join(msg)
	return ""


func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func daily_available() -> bool:
	return daily_day != _today()


## Secondes avant le renouvellement de l'offre du jour (minuit UTC).
func daily_remaining() -> float:
	return 86400.0 - fmod(Time.get_unix_time_from_system(), 86400.0)


func boost_remaining() -> float:
	return maxf(0.0, float(boost_until) - Time.get_unix_time_from_system())


func boost_active() -> bool:
	return boost_remaining() > 0.0


# ---------------------------------------------------------------- équipement

func item_by_id(id: int) -> Dictionary:
	for it in items:
		if int(it.id) == id:
			return it
	return {}


func inventory_items() -> Array:
	var out: Array = []
	for it in items:
		if it.on == "":
			out.append(it)
	return out


## Tentative sur un étage généré (à la frontière) : la difficulté monte un peu après une victoire et baisse
## nettement après une défaite. L'équilibre de ces deux pas donne environ 85 % de victoires.
func record_generated(at_stage: int, won: bool) -> void:
	if not Sector.is_generated(at_stage):
		return
	gen_tries += 1
	if won:
		gen_wins += 1
	inf_diff = clampf(inf_diff * (Sector.STEP_WIN if won else Sector.STEP_LOSS), Sector.MIN_FACTOR, Sector.MAX_FACTOR)
	Sector.factor = inf_diff
	changed.emit()


func equipped_any() -> bool:
	for it in items:
		if it.on != "":
			return true
	return false


## Marque une scène comme vue (et retient la réponse du Capitaine, -1 sans choix).
func see_scene(id: String, choice := -1) -> void:
	if not seen_scenes.has(id):
		seen_scenes.append(id)
	if choice >= 0:
		story_choices[id] = choice
	changed.emit()


## Sauvegardes d'avant le chapitre 1 à bord : les chapitres prennent un numéro de plus, et une partie déjà
## commencée dans le Trou de verre a fait le voyage (chapitre 1 marqué fait, scènes rangées dans le journal, sans récompense).
func _migrate_story() -> void:
	var shifted: Array = []
	for n in chapters_done:
		shifted.append(int(n) + 1)
	chapters_done = shifted
	if best_stage > 1 or seen_scenes.has("c1_entree") or ship.unlocked:
		for sc in Story.chapter_scenes(1):
			if not seen_scenes.has(String(sc.id)):
				seen_scenes.append(String(sc.id))
		if not chapters_done.has(1):
			chapters_done.append(1)
	if ship.unlocked:
		vance_aboard()


## Vance pilote l'Aurore depuis le prologue : il est à bord dès le départ, hors escouade, au poste du Pont.
func vance_aboard() -> void:
	if not is_owned("vance"):
		owned["vance"] = true
	if not squad.has("vance") and ship.post_of("vance") == "" and (ship.posts.get("pont", []) as Array).size() < ship.max_posts("pont"):
		(ship.posts["pont"] as Array).append("vance")


## La mission (le combat) s'ouvre à l'arrivée, à la fin du chapitre 1.
func mission_open() -> bool:
	return chapters_done.has(1)


## Objectifs de bord du chapitre 1 remplis, dans l'ordre (0 à 6).
func voyage_done() -> int:
	var has_post := false
	for r in ship.posts:
		for h in ship.posts[r]:
			if String(h) != "vance":
				has_post = true
	var conds := [ship.harvests > 0, pulls > 0, has_post,
		ship.level >= 2 or not ship.building("pont").is_empty(),
		ship.room_level("raffinerie") >= 2 or not ship.building("raffinerie").is_empty(),
		seen_scenes.has("b1_signal")]
	var n := 0
	for c in conds:
		if not c:
			break
		n += 1
	return n


## Fin d'un chapitre : verse sa récompense une seule fois. Renvoie la récompense, ou {} si déjà versée.
func complete_chapter(n: int) -> Dictionary:
	if chapters_done.has(n):
		return {}
	var c := Story.chapter(n)
	if c.is_empty():
		return {}
	chapters_done.append(n)
	wild += int(c.reward.get("copies", 0))
	if c.reward.has("badge") and not tips.has("badge:" + String(c.reward.badge)):
		tips.append("badge:" + String(c.reward.badge))
	credits += float(c.reward.credits)
	shards += int(c.reward.shards)
	tokens += int(c.reward.tokens)
	changed.emit()
	return c.reward


## Scènes d'étages déjà bien dépassés (nouveau chapitre écrit après coup) : débloquées dans le journal sans être jouées,
## et la récompense d'un chapitre ainsi terminé est versée une seule fois.
func story_catch_up() -> void:
	for s0 in Story.behind(seen_scenes, best_stage):
		seen_scenes.append(String(s0.id))
		if s0.has("end"):
			complete_chapter(int(s0.end))


func inventory_count() -> int:
	return inventory_items().size()


func hero_items(hid: String) -> Array:
	var out: Array = []
	for it in items:
		if it.on == hid:
			out.append(it)
	return out


func slot_item(hid: String, slot: String) -> Dictionary:
	for it in items:
		if it.on == hid and it.slot == slot:
			return it
	return {}


func slot_unlocked(hid: String, slot: String) -> bool:
	return int(levels.get(hid, 1)) >= int(Items.SLOT_UNLOCK[slot])


## Ajoute un objet reçu. Renvoie {item, status} : "added", "recycled" (communs recyclés auto) ou "stash" (inventaire plein).
func receive_item(item: Dictionary) -> Dictionary:
	var norm := _load_items([item])
	if norm.is_empty():
		return {}
	var it: Dictionary = norm[0]
	it.id = next_item
	next_item += 1
	if auto_recycle and it.rarity == "commun":
		shards += int(Items.RECYCLE_SHARDS[it.rarity])
		credits += float(Items.recycle_credits(it))
		return {"item": it, "status": "recycled"}
	if inventory_count() >= Items.INVENTORY_MAX:
		stash.append(it)
		return {"item": it, "status": "stash"}
	items.append(it)
	return {"item": it, "status": "added"}


## Remet dans l'inventaire les objets gardés de côté tant qu'il y a de la place.
func release_stash() -> void:
	while not stash.is_empty() and inventory_count() < Items.INVENTORY_MAX:
		items.append(stash.pop_front())


## Gain de puissance si `hero` porte `item` à la place de ce qu'il porte dans cet emplacement. Un tank frappe peu : son arme compte moins.
func power_gain(item: Dictionary, hid: String) -> float:
	var cur := slot_item(hid, item.slot)
	var g := Items.power(item) - (Items.power(cur) if cur.get("id", -1) != item.id else 0.0)
	if item.slot == "arme" and Data.HEROES[hid].role == "tank":
		g *= 0.3
	return round(g)


## Héros de l'escouade qui profite le plus de l'objet : {hero, gain}.
func best_hero_for(item: Dictionary) -> Dictionary:
	var best := {"hero": "", "gain": -1.0e9}
	for hid in squad_ids():
		if not slot_unlocked(hid, item.slot):
			continue
		if item.bound != "" and item.bound != hid and int(item.moves) >= 1 and credits < Items.REBIND_COST:
			continue
		var g := power_gain(item, hid)
		if g > best.gain:
			best = {"hero": hid, "gain": g}
	return best


## Coût pour porter l'objet sur ce héros : 0 s'il n'est lié à personne, au premier changement ou s'il revient sur son héros.
func equip_cost(item: Dictionary, hid: String) -> int:
	if item.bound == "" or item.bound == hid or int(item.moves) < 1:
		return 0
	return Items.REBIND_COST


func equip(item_id: int, hid: String) -> String:
	var it := item_by_id(item_id)
	if it.is_empty() or not is_owned(hid) or not slot_unlocked(hid, it.slot):
		return "Emplacement verrouillé"
	var cost := equip_cost(it, hid)
	if cost > 0 and credits < cost:
		return "Il manque %d crédits pour délier l'objet" % int(cost - credits)
	if cost > 0:
		credits -= cost
	if it.bound != "" and it.bound != hid:
		it.moves = int(it.moves) + 1
	var old := slot_item(hid, it.slot)
	if not old.is_empty():
		old.on = ""
	it.on = hid
	orders.track("equip")
	it.bound = hid
	changed.emit()
	return ""


func unequip(item_id: int) -> bool:
	var it := item_by_id(item_id)
	if it.is_empty() or it.on == "":
		return false
	if inventory_count() >= Items.INVENTORY_MAX:
		return false
	it.on = ""
	changed.emit()
	return true


## Équipe le meilleur objet disponible dans chaque emplacement débloqué (objets libres ou déjà liés à ce héros).
func equip_best(hid: String) -> int:
	var n := 0
	for slot in Items.SLOTS:
		if not slot_unlocked(hid, slot):
			continue
		var best := {}
		var best_gain := 0.0
		for it in items:
			if it.slot != slot or it.on != "" and it.on != hid:
				continue
			if it.bound != "" and it.bound != hid:
				continue
			var g := power_gain(it, hid)
			if g > best_gain:
				best_gain = g
				best = it
		if not best.is_empty() and equip(int(best.id), hid) == "":
			n += 1
	return n


func equip_best_all() -> int:
	var n := 0
	for hid in squad_ids():
		n += equip_best(hid)
	return n


func unequip_all(hid: String) -> void:
	for it in hero_items(hid):
		if inventory_count() < Items.INVENTORY_MAX:
			it.on = ""
	changed.emit()


## Niveau maximum d'un objet : celui de son héros s'il est lié, sinon son maximum de rareté.
func item_cap(it: Dictionary) -> int:
	var cap := Items.max_level(it)
	if it.bound != "":
		cap = mini(cap, int(levels.get(it.bound, 1)))
	return cap


func upgrade_item(item_id: int) -> bool:
	var it := item_by_id(item_id)
	if it.is_empty() or int(it.level) >= item_cap(it):
		return false
	var c := Items.upgrade_cost(it)
	if credits < c:
		return false
	credits -= c
	it.level = int(it.level) + 1
	changed.emit()
	return true


func recycle_items(ids: Array) -> Dictionary:
	var sh := 0
	var cr := 0
	var n := 0
	for id in ids:
		var it := item_by_id(int(id))
		if it.is_empty() or it.on != "" or it.locked:
			continue
		sh += int(Items.RECYCLE_SHARDS[it.rarity])
		cr += Items.recycle_credits(it)
		items.erase(it)
		n += 1
	shards += sh
	credits += float(cr)
	release_stash()
	changed.emit()
	return {"count": n, "shards": sh, "credits": cr}


## Trois objets libres de même emplacement et même rareté donnent un objet de rareté supérieure. Renvoie l'objet ou {}.
func fuse_items(ids: Array) -> Dictionary:
	if ids.size() != 3:
		return {}
	var base := item_by_id(int(ids[0]))
	if base.is_empty() or base.rarity == "ultime":
		return {}
	var lv := 0
	for id in ids:
		var it := item_by_id(int(id))
		if it.is_empty() or it.on != "" or it.locked or it.slot != base.slot or it.rarity != base.rarity:
			return {}
		lv += int(it.level)
	var nr: String = Items.RARITIES[Items.rarity_index(base.rarity) + 1]
	var cost := Items.fuse_cost(nr)
	if credits < cost:
		return {}
	credits -= cost
	for id in ids:
		items.erase(item_by_id(int(id)))
	var out := Items.roll(rng, nr, maxi(1, best_stage - 1), base.slot, true)
	out.level = clampi(int(round(float(lv) / 3.0)), 1, Items.max_level(out))
	out.id = next_item
	next_item += 1
	items.append(out)
	changed.emit()
	return out


## Puissance apportée par tout l'équipement d'un héros.
func hero_item_power(hid: String) -> float:
	var p := 0.0
	for it in hero_items(hid):
		p += Items.power(it)
	return p


func _load_items(raw: Array) -> Array:
	var out: Array = []
	for r in raw:
		if typeof(r) != TYPE_DICTIONARY or not r.has("slot") or not Items.SLOTS.has(String(r.slot)) or not Items.RARITIES.has(String(r.get("rarity", ""))):
			continue
		var subs: Array = []
		for s in r.get("subs", []):
			if typeof(s) == TYPE_DICTIONARY and Items.BONUS.has(String(s.get("k", ""))):
				subs.append({"k": String(s.k), "v": float(s.get("v", 1.0))})
		out.append({"id": int(r.get("id", 0)), "slot": String(r.slot), "rarity": String(r.rarity), "name": String(r.get("name", "Objet")), "level": maxi(1, int(r.get("level", 1))), "scale": float(r.get("scale", 1.0)), "subs": subs, "set": String(r.get("set", "")), "on": String(r.get("on", "")), "bound": String(r.get("bound", "")), "moves": int(r.get("moves", 0)), "locked": bool(r.get("locked", false))})
	return out


## Applique le réglage d'économie de batterie (30 images par seconde au lieu de 60).
func apply_performance() -> void:
	var low := battery_auto and battery_level() >= 0 and battery_level() < 20
	Engine.max_fps = 30 if (battery_saver or low) else 60
	UI.text_scale = [1.0, 1.1, 1.2][clampi(text_size, 0, 2)]


## Niveau de batterie en % (lu dans le système du téléphone), ou -1 s'il n'est pas lisible.
func battery_level() -> int:
	for path in ["/sys/class/power_supply/battery/capacity", "/sys/class/power_supply/Battery/capacity", "/sys/class/power_supply/BAT0/capacity"]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var txt := f.get_as_text().strip_edges()
				if txt.is_valid_int():
					return clampi(int(txt), 0, 100)
	return -1


## Petite vibration (si activée) : achat, étoile, coffre.
func buzz(ms: int = 30) -> void:
	if haptics:
		Input.vibrate_handheld(ms)


## Trois vibrations, trois sens (maquette E4) : "tap" courte (appui), "reward" double (récompense), "alert" longue (boss).
func haptic(kind: String) -> void:
	if not haptics:
		return
	match kind:
		"tap":
			Input.vibrate_handheld(8)
		"reward":
			Input.vibrate_handheld(30)
			get_tree().create_timer(0.12, true).timeout.connect(func(): Input.vibrate_handheld(30))
		"alert":
			Input.vibrate_handheld(220)


func add_credits(v: float) -> void:
	credits += v * (1.0 + ship.research_bonus("prospection"))
	changed.emit()


func level_cost(id: String) -> int:
	return Data.level_cost(int(levels[id]))


## Palier de puissance du combat (0 à 2) : le pouvoir et les statistiques gagnent à 2★ et 3★.
func tier(id: String) -> int:
	return clampi(int(hero_stars[id]) - 1, 0, 2)


## Niveau maximal atteint pour l'étoile actuelle : il faut une étoile de plus pour continuer.
func at_cap(id: String) -> bool:
	return int(levels[id]) >= Data.level_cap(int(hero_stars[id]))


func can_level(id: String) -> bool:
	return not at_cap(id) and credits >= level_cost(id)


## Un héros au niveau maximal de son étoile a besoin d'une étoile de plus (donc de doublons) pour continuer.
func needs_star(id: String) -> bool:
	return is_owned(id) and at_cap(id) and int(hero_stars[id]) < 5


func level_up(id: String) -> bool:
	var c := level_cost(id)
	if at_cap(id) or credits < c:
		return false
	credits -= c
	levels[id] = int(levels[id]) + 1
	changed.emit()
	return true


## Hero dont l'amélioration apporte le plus de puissance par crédit dépensé (étiquette « Meilleur achat »).
func best_buy() -> String:
	var best := ""
	var best_ratio := -1.0
	for id in squad_ids():
		if at_cap(id):
			continue
		var h: Dictionary = Data.HEROES[id]
		var lv := int(levels[id])
		var gain: float = (h.hp * 0.25 + h.atk * 6.0 + h.def * 3.0) * (Data.hero_mult(lv + 1) - Data.hero_mult(lv))
		var ratio: float = gain / float(Data.level_cost(lv))
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	return best


# ---------------------------------------------------------------- étages

func is_frontier() -> bool:
	return stage >= best_stage


## Étage vaincu : enregistre les étoiles, débloque le suivant. Renvoie le coffre obtenu {rarity, credits, shards}.
## Avec `defer`, le butin du coffre n'est versé qu'à l'ouverture (voir claim_pending) : l'écran de résultat l'affiche après l'animation.
func stage_cleared(star_count: int, combo: int = 1, defer: bool = false) -> Dictionary:
	stars[stage] = maxi(int(stars.get(stage, 0)), star_count)
	perseverance = 0
	var loot := Data.combo_loot(combo)
	claim_pending()    # un coffre oublié est toujours versé avant le suivant
	var chest := open_chest(Data.roll_chest(stage, star_count, rng, pity), stage, loot, defer, Data.boss_type(stage) == "big")
	if Data.boss_type(stage) == "big":
		chest["crystals"] = int(Data.BIG_BOSS_CRYSTALS[clampi(star_count, 1, 3)])
		chest["copies"] = int(Data.BIG_BOSS_COPIES[clampi(star_count, 1, 3)])
		if defer:
			pending_chest = chest
		else:
			crystals += int(chest.crystals)
			wild += int(chest.copies)
	if Data.is_boss_stage(stage):
		boosts = []
	if stage >= best_stage:
		best_stage = stage + 1
	changed.emit()
	return chest


func open_chest(rarity: String, at_stage: int, loot_bonus: float = 0.0, defer: bool = false, big_boss := false) -> Dictionary:
	var rw := Data.chest_rewards(at_stage, rarity)
	if Sector.is_generated(at_stage):
		# plus la difficulté adaptative est haute, plus le butin est généreux
		rw = {"credits": rw.credits * Sector.factor, "shards": int(round(float(rw.shards) * Sector.factor))}
	if Sector.is_generated(at_stage) and ship.room_level("observatoire") > 0:
		var ob := Ship.observatory_bonus(ship.room_level("observatoire")) * (1.0 + ship.workers_bonus("observatoire"))
		rw = {"credits": rw.credits * (1.0 + ob), "shards": int(round(float(rw.shards) * (1.0 + ob)))}
	rw = {"credits": rw.credits * (1.0 + ship.research_bonus("prospection")), "shards": int(round(float(rw.shards) * (1.0 + ship.research_bonus("tamisage"))))}
	var cr: float = round(rw.credits * (1.0 + loot_bonus))
	var chest := {"rarity": rarity, "credits": cr, "shards": rw.shards, "combo_bonus": loot_bonus, "tokens": int(Data.CHEST_TOKENS[rarity]), "crystals": 0, "item_tokens": 1 if big_boss else 0}
	chest["item"] = _roll_chest_item(rarity, at_stage, big_boss)
	if defer:
		pending_chest = chest
	else:
		_pay(chest)
	changed.emit()
	return chest


## Objet du coffre : tirage selon la rareté du coffre, avec la garantie d'un légendaire au plus tard au 3e gros boss.
func _roll_chest_item(chest_rarity: String, at_stage: int, big_boss: bool) -> Dictionary:
	var r := Items.roll_rarity(chest_rarity, rng)
	if big_boss:
		if Items.rarity_index(r) >= 4:
			item_pity = 0
		else:
			item_pity += 1
			if item_pity >= Items.PITY_BOSSES:
				r = "legendaire"
				item_pity = 0
	return Items.roll(rng, r, at_stage)


func _pay(chest: Dictionary) -> void:
	if chest.has("item") and typeof(chest.item) == TYPE_DICTIONARY and not chest.item.is_empty():
		last_drop = receive_item(chest.item)
	credits += float(chest.credits)
	shards += int(chest.shards)
	tokens += int(chest.get("tokens", 0))
	item_tokens += int(chest.get("item_tokens", 0))
	crystals += int(chest.get("crystals", 0))
	wild += int(chest.get("copies", 0))


## Verse le coffre en attente (à l'ouverture, ou à la fermeture de l'écran si on le quitte avant).
func claim_pending() -> void:
	if pending_chest.is_empty():
		return
	_pay(pending_chest)
	pending_chest = {}
	changed.emit()


## Défaite : un cran de persévérance en plus.
func defeated() -> void:
	perseverance = mini(Data.PERSEVERANCE_MAX, perseverance + 1)
	changed.emit()


func perseverance_pct() -> int:
	return int(round(perseverance * Data.PERSEVERANCE_STEP * 100.0))


## Trois renforts distincts tirés au hasard.
func offer_boosts() -> Array:
	var pool: Array = Data.BOOST_IDS.duplicate()
	var out: Array = []
	for i in 3:
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out


func add_boost(id: String) -> void:
	boosts.append(id)
	changed.emit()


func go_to(n: int) -> void:
	stage = clampi(n, 1, best_stage)
	changed.emit()


func advance() -> void:
	go_to(stage + 1)


## Défaite : on redescend d'un étage.
func retreat() -> void:
	stage = maxi(1, stage - 1)
	changed.emit()


# ---------------------------------------------------------------- hors ligne et coffre gratuit

## Crédits par minute hors ligne : équivalent du butin d'un étage déjà maîtrisé, à raison d'un combat par minute.
func offline_rate_per_minute() -> float:
	var s := maxi(1, best_stage - 1)
	var sc := Data.stage_scale(s)
	return (3.0 * sc * 3.4 * Data.WAVES_PER_STAGE + 25.0 * sc) * 0.6


func compute_offline(away_seconds: float) -> Dictionary:
	var capped := minf(away_seconds, offline_cap_hours() * 3600.0)
	var gain := offline_rate_per_minute() * capped / 60.0
	# quelques éclats de verre aussi : environ 1 par heure et par tranche de 8 étages atteints
	var sh := int(floor(capped / 3600.0 * maxf(0.5, float(best_stage) / 8.0)))
	return {"seconds": capped, "credits": gain, "shards": sh}


## Plafond des gains hors ligne : 8 h, ou l'autonomie de l'Aurore si elle est plus longue (Centrale).
func offline_cap_hours() -> float:
	return maxf(Data.OFFLINE_CAP_HOURS, ship.autonomy_hours()) if ship.unlocked else Data.OFFLINE_CAP_HOURS


# ---------------------------------------------------------------- vaisseau

## Fait avancer le vaisseau (production, chantiers, recherche, entraînement, navettes) et signale ce qui s'est passé.
func ship_update() -> Dictionary:
	if not ship.unlocked:
		if best_stage > Ship.UNLOCK_STAGE:
			ship.unlock()
			# prime de départ de l'Amirauté et soute de la Raffinerie déjà pleine : de quoi lancer les objectifs du chapitre 1
			credits += float(Ship.START_CREDITS)
			ship.stock["raffinerie"] = maxf(float(ship.stock.get("raffinerie", 0.0)), 10.0)
			vance_aboard()
			changed.emit()
		return {}
	var ev := ship.tick(self)
	if not ev.done.is_empty() or ev.research != "" or not ev.trained.is_empty() or not ev.shuttles.is_empty():
		ship_events.emit(ev)
		changed.emit()
	return ev


## Bonus du Labo appliqués au combat.
func ship_combat() -> Dictionary:
	return {"hp": ship.research_bonus("blindage"), "atk": ship.research_bonus("armement"), "cdr": ship.research_bonus("reacteurs"), "boss": ship.research_bonus("briseur"), "tactic": ship.rank("tactique") > 0}


func free_chest_remaining() -> float:
	var now := int(Time.get_unix_time_from_system())
	return maxf(0.0, last_free_chest + Data.FREE_CHEST_HOURS * 3600.0 - now)


func free_chest_ready() -> bool:
	return free_chest_remaining() <= 0.0


func claim_free_chest() -> Dictionary:
	if not free_chest_ready():
		return {}
	last_free_chest = int(Time.get_unix_time_from_system())
	var rarity := "normal" if rng.randf() < 0.3 else "commun"
	return open_chest(rarity, maxi(1, best_stage - 1))


# ---------------------------------------------------------------- sauvegarde

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var star_save := {}
	for k in stars:
		star_save[str(k)] = stars[k]
	_write_atomic(JSON.stringify({
		"version": SAVE_VERSION, "credits": credits, "shards": shards, "levels": levels, "stage": stage, "best": best_stage,
		"stars": star_save, "pity": pity, "auto": auto_cast, "speed": speed, "sfx": sfx_on, "music": music_on, "music_vol": music_vol, "sfx_vol": sfx_vol, "haptics": haptics, "dmg_numbers": dmg_numbers, "battery_saver": battery_saver, "reduce_shake": reduce_shake, "text_size": text_size, "battery_auto": battery_auto,
		"tutorial": tutorial_done, "intro": intro_seen, "last_seen": last_seen, "free_chest": last_free_chest,
		"perseverance": perseverance, "boosts": boosts, "wild": wild, "pending": pending_chest,
		"owned": owned.keys(), "hero_stars": hero_stars, "fragments": fragments, "squad": squad, "tokens": tokens, "crystals": crystals,
		"recruit_pity": recruit_pity, "pulls": pulls, "items": items, "next_item": next_item, "stash": stash, "auto_recycle": auto_recycle, "item_pity": item_pity, "item_tokens": item_tokens, "seen_scenes": seen_scenes, "story_choices": story_choices, "chapters_done": chapters_done, "story_v": 2, "tips": tips, "inf_diff": inf_diff, "gen_tries": gen_tries, "gen_wins": gen_wins, "sectors_seen": sectors_seen, "item_pack_pity": item_pack_pity, "item_pulls": item_pulls, "daily_day": daily_day, "last_pulls": last_pulls, "boost_until": boost_until, "ship": ship.to_dict(), "orders": orders.to_dict(), "board": board.to_dict(), "talents": talents,
	}))


## Écriture sûre : fichier temporaire relu et vérifié, copie de secours de l'ancienne sauvegarde, puis remplacement.
## Si le téléphone coupe pendant l'écriture, l'ancienne sauvegarde (ou sa copie) reste intacte.
func _write_atomic(text: String) -> bool:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if _read_save(tmp).is_empty():
		push_warning("Sauvegarde illisible : l'ancienne est conservée")
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	return DirAccess.rename_absolute(tmp, save_path) == OK


## Lit une sauvegarde ; renvoie un dictionnaire vide si le fichier manque, est tronqué ou d'une version inconnue.
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var ver := int(parsed.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		return {}
	return parsed


func load_game() -> bool:
	# sauvegarde principale, sinon la copie de secours, sinon une écriture complète restée en attente
	var parsed: Dictionary = {}
	for path in [save_path, save_path + ".bak", save_path + ".tmp"]:
		parsed = _read_save(path)
		if not parsed.is_empty():
			break
	if parsed.is_empty():
		return false
	var ver := int(parsed.get("version", 0))
	daily_day = int(parsed.get("daily_day", -1))
	items = _load_items(parsed.get("items", []))
	stash = _load_items(parsed.get("stash", []))
	next_item = maxi(1, int(parsed.get("next_item", 1)))
	for it in items + stash:
		next_item = maxi(next_item, int(it.id) + 1)
	auto_recycle = bool(parsed.get("auto_recycle", true))
	item_pity = int(parsed.get("item_pity", 0))
	item_tokens = maxi(0, int(parsed.get("item_tokens", 4)))
	seen_scenes = []
	for sid in parsed.get("seen_scenes", []):
		seen_scenes.append(String(sid))
	story_choices = {}
	var sc: Dictionary = parsed.get("story_choices", {})
	for k in sc:
		story_choices[String(k)] = int(sc[k])
	inf_diff = clampf(float(parsed.get("inf_diff", 1.0)), Sector.MIN_FACTOR, Sector.MAX_FACTOR)
	Sector.factor = inf_diff
	gen_tries = int(parsed.get("gen_tries", 0))
	gen_wins = int(parsed.get("gen_wins", 0))
	sectors_seen = []
	for k in parsed.get("sectors_seen", []):
		sectors_seen.append(int(k))
	tips = []
	for tp in parsed.get("tips", []):
		tips.append(String(tp))
	chapters_done = []
	for n in parsed.get("chapters_done", []):
		chapters_done.append(int(n))
	var ipp: Dictionary = parsed.get("item_pack_pity", {})
	item_pack_pity = {"epic": int(ipp.get("epic", 0)), "leg": int(ipp.get("leg", 0))}
	item_pulls = []
	for lp in parsed.get("item_pulls", []):
		if typeof(lp) == TYPE_DICTIONARY and lp.has("slot") and Items.SLOTS.has(String(lp.slot)) and Items.RARITIES.has(String(lp.get("rarity", ""))):
			item_pulls.append({"slot": String(lp.slot), "rarity": String(lp.rarity)})
	last_pulls = []
	for lp in parsed.get("last_pulls", []):
		if typeof(lp) == TYPE_DICTIONARY and Data.HEROES.has(String(lp.get("id", ""))):
			last_pulls.append({"id": String(lp.id), "rarity": String(lp.get("rarity", "common"))})
	boost_until = int(parsed.get("boost_until", 0))
	credits = float(parsed.get("credits", 0.0))
	shards = int(parsed.get("shards", 0))
	var saved: Dictionary = parsed.get("levels", {})
	for id in Data.ALL_HEROES:
		levels[id] = maxi(1, int(saved.get(id, 1)))
	best_stage = maxi(1, int(parsed.get("best", 1)))
	stage = clampi(int(parsed.get("stage", 1)), 1, best_stage)
	stars = {}
	var star_save: Dictionary = parsed.get("stars", {})
	for k in star_save:
		stars[int(k)] = clampi(int(star_save[k]), 1, 3)
	var pt: Dictionary = parsed.get("pity", {})
	pity = {"leg": int(pt.get("leg", 0)), "ult": int(pt.get("ult", 0))}
	auto_cast = bool(parsed.get("auto", true))
	speed = clampf(float(parsed.get("speed", 1.0)), 1.0, 3.0)
	sfx_on = bool(parsed.get("sfx", true))
	music_on = bool(parsed.get("music", true))
	music_vol = clampf(float(parsed.get("music_vol", 0.7)), 0.0, 1.0)
	sfx_vol = clampf(float(parsed.get("sfx_vol", 1.0)), 0.0, 1.0)
	haptics = bool(parsed.get("haptics", true))
	dmg_numbers = bool(parsed.get("dmg_numbers", true))
	battery_saver = bool(parsed.get("battery_saver", false))
	reduce_shake = bool(parsed.get("reduce_shake", false))
	text_size = clampi(int(parsed.get("text_size", 0)), 0, 2)
	battery_auto = bool(parsed.get("battery_auto", true))
	apply_performance()
	tutorial_done = bool(parsed.get("tutorial", ver == 1))
	intro_seen = bool(parsed.get("intro", ver == 1))
	# parties commencées avant l'histoire : on ne rejoue pas les scènes des étages déjà passés
	if not parsed.has("seen_scenes") and intro_seen:
		seen_scenes.append("prologue")
	if seen_scenes.has("prologue"):
		story_catch_up()
	last_seen = int(parsed.get("last_seen", 0))
	last_free_chest = int(parsed.get("free_chest", 0))
	perseverance = clampi(int(parsed.get("perseverance", 0)), 0, Data.PERSEVERANCE_MAX)
	boosts = []
	for b in parsed.get("boosts", []):
		if Data.BOOSTS.has(String(b)):
			boosts.append(String(b))
	wild = maxi(0, int(parsed.get("wild", 0)))
	pending_chest = {}
	var pc: Dictionary = parsed.get("pending", {})
	var pending_load := pc
	# collection : les anciennes sauvegardes (avant la branche 3) n'ont que les cinq héros de départ
	if parsed.has("owned"):
		owned = {}
		for id in parsed.owned:
			if Data.HEROES.has(String(id)):
				owned[String(id)] = true
		var hs: Dictionary = parsed.get("hero_stars", {})
		var fr: Dictionary = parsed.get("fragments", {})
		for id in Data.ALL_HEROES:
			hero_stars[id] = clampi(int(hs.get(id, 1)), 1, Data.MAX_STARS)
			fragments[id] = maxi(0, int(fr.get(id, 0)))
		squad = []
		for id in parsed.get("squad", []):
			squad.append(String(id) if owned.has(String(id)) else "")
		while squad.size() < Data.SQUAD_SIZE:
			squad.append("")
		squad = squad.slice(0, Data.SQUAD_SIZE)
		var seen := {}
		for i in squad.size():
			if squad[i] != "" and seen.has(squad[i]):
				squad[i] = ""
			seen[squad[i]] = true
		tokens = maxi(0, int(parsed.get("tokens", 0)))
		crystals = maxi(0, int(parsed.get("crystals", 0)))
		var rp: Dictionary = parsed.get("recruit_pity", {})
		recruit_pity = {"rare": int(rp.get("rare", 0)), "epic": int(rp.get("epic", 0))}
		pulls = maxi(0, int(parsed.get("pulls", 0)))
	else:
		tokens = 6                       # cadeau de bienvenue pour les parties existantes
	if squad_ids().is_empty():
		squad = Data.STARTER.duplicate()
		for id in squad:
			owned[id] = true
	_normalize_squad()
	if pending_load.has("credits"):
		_pay(pending_load)                    # un coffre non ouvert avant la fermeture est versé au rechargement
	ship = ShipState.from_dict(parsed.get("ship", {}))
	orders = Orders.from_dict(parsed.get("orders", {}))
	board = BoardEvents.from_dict(parsed.get("board", {}))
	talents = parsed.get("talents", {}) if parsed.get("talents", {}) is Dictionary else {}
	if int(parsed.get("story_v", 1)) < 2:
		_migrate_story()
	var away := maxi(0, int(Time.get_unix_time_from_system()) - last_seen)
	if last_seen > 0 and away > 60:
		offline_report = compute_offline(float(away))
		credits += float(offline_report.credits)
		shards += int(offline_report.shards)
		var sev := ship.tick(self)
		if ship.unlocked:
			offline_report["ship"] = sev
	else:
		ship.tick(self)
	return true
