class_name Help
## Mémos d'écran (maquette E5) : un « ? » dans la barre du haut rouvre trois lignes d'explication.
## Tant qu'un mémo n'a pas été lu, son « ? » est doré.

const MEMOS := {
	"Héros": [
		"Touche un héros pour ouvrir sa fiche : niveau, étoiles, équipement.",
		"Les crédits font monter le niveau ; chaque étoile relève le niveau maximum.",
		"Les étoiles demandent des doublons : un héros déjà possédé, recruté à nouveau.",
	],
	"Recruter": [
		"Les jetons ouvrent des héros ; les jetons d’objet, des caisses d’objets.",
		"L’ouverture ×10 en offre une : dix pour le prix de neuf.",
		"Un héros déjà possédé devient un doublon pour ses étoiles.",
	],
	"Boutique": [
		"Tout s’y achète en cristaux.",
		"L’offre du jour est moins chère, une fois par jour.",
		"Le coffre gratuit revient toutes les 4 heures : pastille rouge quand il est prêt.",
	],
	"L’Aurore": [
		"Les salles produisent même quand tu ne joues pas. Pastille rouge : il y a à récolter.",
		"Affecte des héros aux postes d’une salle pour qu’elle produise plus.",
		"Un chantier à la fois au début, deux à partir du niveau 5 du vaisseau.",
	],
	"Secteurs": [
		"Chaque secteur est une suite de vagues ; un boss garde certains secteurs.",
		"Choisis un secteur déjà vaincu, puis le bouton du bas, pour y retourner.",
		"Au-delà de l’histoire, les zones générées continuent sans fin.",
	],
}


static func has(title: String) -> bool:
	return MEMOS.has(title)


static func seen(title: String) -> bool:
	return Game.tips.has("help:" + title)


## Ouvre le mémo par-dessus l'écran ; un appui n'importe où le ferme.
static func show(host: Control, title: String) -> void:
	if not seen(title):
		Game.tips.append("help:" + title)
		Game.save_game()
	var layer := Control.new()
	layer.size = Vector2(720, UI.H)
	layer.z_index = 4096
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			layer.queue_free())
	host.get_viewport().add_child(layer)
	var box := Control.new()
	box.position = Vector2(40, 120)
	box.size = Vector2(640, 200)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		M3.dialog(box, Rect2(Vector2.ZERO, box.size))
		M3.text(box, Vector2(36, 62), title, 34, UI.TEXT, true, 560)
		var y := 112.0
		for line in MEMOS[title]:
			box.draw_circle(Vector2(46, y - 8), 5, UI.ACCENT)
			y += M3.para(box, Vector2(68, y), String(line), 24, UI.TEXT, 536, 1.35) + 12.0
		M3.text(box, Vector2(36, y + 20), "Touche pour fermer", 20, UI.MUTED, false, 568)
		if absf(box.size.y - (y + 44.0)) > 1.0:
			box.size.y = y + 44.0
			box.queue_redraw())
	layer.add_child(box)
