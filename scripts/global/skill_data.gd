extends Node

# Skill Data and Synergy Definitions for Cyber Survivor: Protocol Zero

enum Branch { OFFENSE, DEFENSE, OVERCLOCK, HACK, ENGINEER }

const SKILLS = {
	"blaster": {
		"id": "blaster",
		"code": "WPN-01",
		"name": "Імпульсний Бластер",
		"branch": Branch.OFFENSE,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 5,
		"icon_color": Color(0.2, 0.75, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/blaster.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_blueCorner.png",
		"desc": "Базовий плазмовий випромінювач. Збільшує скорострільність, кількість зарядів та шкоду.",
		"per_level": "+20% шкоди, +1 снаряд на 3-му та 5-му рівнях, -15% кулдаун"
	},
	"missiles": {
		"id": "missiles",
		"code": "WPN-02",
		"name": "Мікро-Ракети",
		"branch": Branch.OFFENSE,
		"tier": 2,
		"prereq": "blaster",
		"prereq_lvl": 1,
		"max_lvl": 4,
		"icon_color": Color(0.3, 0.9, 0.4),
		"icon_path": "res://assets/sprites/ui/gi/missiles.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_blueCorner.png",
		"desc": "Запускає залп самонавідних реактивних ракет по скупченнях ворожих ботів.",
		"per_level": "+1 ракета за рівень, +25% радіус вибуху"
	},
	"railgun": {
		"id": "railgun",
		"code": "WPN-03",
		"name": "Рейлган Пробивач",
		"branch": Branch.OFFENSE,
		"tier": 3,
		"prereq": "blaster",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(0.1, 1.0, 0.7),
		"icon_path": "res://assets/sprites/ui/gi/railgun.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_blueCorner.png",
		"desc": "Випускає надзвуковий промінь тахіонів, що пробиває шеренги важких мехів наскрізь.",
		"per_level": "+40% шкоди променя, пробиває +2 ворогів"
	},
	"drones": {
		"id": "drones",
		"code": "WPN-04",
		"name": "Орбітальні Дрони",
		"branch": Branch.OFFENSE,
		"tier": 4,
		"prereq": "missiles",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.8, 0.2),
		"icon_path": "res://assets/sprites/ui/gi/drones.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_blueCorner.png",
		"desc": "Автономні бойові дрони кружляють навколо корабля і збивають ворогів на підльоті.",
		"per_level": "+1 захисний дрон, +20% радіус орбіти та швидкість польоту"
	},
	
	"shield": {
		"id": "shield",
		"code": "DEF-01",
		"name": "Силове Поле",
		"branch": Branch.DEFENSE,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 5,
		"icon_color": Color(0.2, 0.85, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/shield.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_greenCorner.png",
		"desc": "Енергетичний бар'єр поглинає пошкодження перед корпусом. Авто-відновлення при затримці.",
		"per_level": "+30 ємності щита, -1 сек до початку перезарядки"
	},
	"repair": {
		"id": "repair",
		"code": "DEF-02",
		"name": "Нанітне Відновлення",
		"branch": Branch.DEFENSE,
		"tier": 2,
		"prereq": "shield",
		"prereq_lvl": 1,
		"max_lvl": 4,
		"icon_color": Color(0.2, 1.0, 0.5),
		"icon_path": "res://assets/sprites/ui/gi/repair.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_greenCorner.png",
		"desc": "Колонія ремонтних нанітів безперервно відновлює цілісність пошкодженого корпусу.",
		"per_level": "+2.0 HP регенерації кожну секунду"
	},
	"magnet": {
		"id": "magnet",
		"code": "DEF-03",
		"name": "Магнітний Захоплювач",
		"branch": Branch.DEFENSE,
		"tier": 3,
		"prereq": "shield",
		"prereq_lvl": 1,
		"max_lvl": 3,
		"icon_color": Color(0.7, 0.4, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/magnet.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_greenCorner.png",
		"desc": "Потужне гравітаційне поле автоматично притягує нанітний брухт та енергетичні ядра здалеку.",
		"per_level": "+50% радіус притягання брухту"
	},
	"armor": {
		"id": "armor",
		"code": "DEF-04",
		"name": "Титанова Броня",
		"branch": Branch.DEFENSE,
		"tier": 4,
		"prereq": "repair",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(0.85, 0.85, 0.95),
		"icon_path": "res://assets/sprites/ui/gi/armor.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_greenCorner.png",
		"desc": "Багатошарова композитна броня знижує отримані пошкодження та підвищує максимальне HP.",
		"per_level": "-12% шкоди від усіх атак, +35 максимального HP"
	},

	"speed": {
		"id": "speed",
		"code": "OVC-01",
		"name": "Форсаж Двигунів",
		"branch": Branch.OVERCLOCK,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.65, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/speed.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Форсаж маршових і маневрових двигунів корабля.",
		"per_level": "+18% швидкості корабля"
	},
	"cooldown": {
		"id": "cooldown",
		"code": "OVC-02",
		"name": "Тактовий Прискорювач",
		"branch": Branch.OVERCLOCK,
		"tier": 2,
		"prereq": "speed",
		"prereq_lvl": 1,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.35, 0.35),
		"icon_path": "res://assets/sprites/ui/gi/cooldown.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Оверклокінг центрального процесора зменшує час відновлення всіх активних систем.",
		"per_level": "-12% часу кулдауну для всіх збройових систем"
	},
	"emp": {
		"id": "emp",
		"code": "OVC-03",
		"name": "EMP Детонатор",
		"branch": Branch.OVERCLOCK,
		"tier": 3,
		"prereq": "cooldown",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(0.9, 0.25, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/emp.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Періодичний викид електромагнітної хвилі дезактивує та спалює схеми ворожих дронів.",
		"per_level": "+30% радіус та +40 шкоди від імпульсу"
	},
	"conductor": {
		"id": "conductor",
		"code": "OVC-04",
		"name": "Плазмовий Провідник",
		"branch": Branch.OVERCLOCK,
		"tier": 4,
		"prereq": "emp",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(0.4, 0.95, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/conductor.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Надає всім атакам ефект перевантаження плазмою, розкидаючи ланцюгові блискавки.",
		"per_level": "Блискавка вражає +2 додаткових ворогів поруч"
	},
	
	"virus": {
		"id": "virus",
		"code": "HCK-01",
		"name": "Нейро-Вірус",
		"branch": Branch.HACK,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 5,
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/virus.png",
		"desc": "Періодично заражає найближчих ворогів. Заражені втрачають корпус щосекунди, а при знищенні передають вірус сусідам.",
		"per_level": "+1 ціль зараження, +25% шкоди вірусу"
	},
	"glitch_field": {
		"id": "glitch_field",
		"code": "HCK-02",
		"name": "Глітч-Поле",
		"branch": Branch.HACK,
		"tier": 2,
		"prereq": "virus",
		"prereq_lvl": 1,
		"max_lvl": 4,
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/glitch_field.png",
		"desc": "Поле перешкод навколо корабля збиває навігацію ворогів: вони сповільнюються і отримують шкоду.",
		"per_level": "+20% радіус поля, -10% швидкості ворогів у полі"
	},
	"data_spike": {
		"id": "data_spike",
		"code": "HCK-03",
		"name": "Перехоплення",
		"branch": Branch.HACK,
		"tier": 3,
		"prereq": "virus",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/data_spike.png",
		"desc": "Знищений ворог іноді випускає перехоплену ракету, яка сама шукає нову ціль.",
		"per_level": "+6% шанс перехоплення, +20% шкоди ракети"
	},
	"botnet": {
		"id": "botnet",
		"code": "HCK-04",
		"name": "Ботнет",
		"branch": Branch.HACK,
		"tier": 4,
		"prereq": "data_spike",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/botnet.png",
		"desc": "Заражені вороги при знищенні вибухають імпульсом, що оглушує і ранить сусідів.",
		"per_level": "+25% радіус імпульсу, +0.5 с оглушення"
	},

	"turret": {
		"id": "turret",
		"code": "ENG-01",
		"name": "Автотурель",
		"branch": Branch.ENGINEER,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 5,
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/turret.png",
		"desc": "Розгортає стаціонарну турель там, де стоїть корабель. Турель сама стріляє по найближчих ворогах, доки не вичерпає заряд.",
		"per_level": "+1 турель одночасно, +20% шкоди, +2 с роботи"
	},
	"mines": {
		"id": "mines",
		"code": "ENG-02",
		"name": "Мінне Поле",
		"branch": Branch.ENGINEER,
		"tier": 2,
		"prereq": "turret",
		"prereq_lvl": 1,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/mines.png",
		"desc": "Корабель скидає за кормою магнітні міни. Міна вибухає, коли ворог підходить близько.",
		"per_level": "+1 міна за скид, +25% шкоди вибуху"
	},
	"tesla": {
		"id": "tesla",
		"code": "ENG-03",
		"name": "Тесла-Котушка",
		"branch": Branch.ENGINEER,
		"tier": 3,
		"prereq": "turret",
		"prereq_lvl": 2,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/tesla.png",
		"desc": "Турелі отримують тесла-котушку: періодично б'ють розрядом усіх ворогів поруч.",
		"per_level": "+25% радіус розряду, +15 шкоди"
	},
	"missile_battery": {
		"id": "missile_battery",
		"code": "ENG-04",
		"name": "Ракетна Батарея",
		"branch": Branch.ENGINEER,
		"tier": 4,
		"prereq": "tesla",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/missile_battery.png",
		"desc": "Турелі отримують ракетну установку і запускають самонавідні ракети по найближчих цілях.",
		"per_level": "+1 ракета в залпі, -0.5 с перезарядки"
	}
}

const SYNERGIES = {
	"plasma_storm": {
		"id": "plasma_storm",
		"code": "SYN-01",
		"name": "Плазмовий Шторм",
		"req": {"blaster": 3, "conductor": 1},
		"desc": "Імпульсний бластер перетворюється на каскадну плазмову пушку: снаряди пробивають та б'ють ланцюговою блискавкою по 3 ворогах одночасно!",
		"icon_color": Color(0.2, 0.9, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/plasma_storm.png"
	},
	"emp_apocalypse": {
		"id": "emp_apocalypse",
		"code": "SYN-02",
		"name": "Апокаліптичний EMP",
		"req": {"shield": 3, "emp": 2},
		"desc": "При пробитті силового поля або кожні 10 сек вивільняється надпотужний EMP-вибух по всьому екрану, миттєво знищуючи легких дронів!",
		"icon_color": Color(0.9, 0.3, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/emp_apocalypse.png"
	},
	"valkyrie_swarm": {
		"id": "valkyrie_swarm",
		"code": "SYN-03",
		"name": "Рій Валькірія",
		"req": {"missiles": 3, "railgun": 2},
		"desc": "Мікро-ракети оснащуються рейлгановими прискорювачами: пронизують ворогів наскрізь і вибухають подвійним ядерним мікро-зарядом!",
		"icon_color": Color(1.0, 0.45, 0.2),
		"icon_path": "res://assets/sprites/ui/gi/valkyrie_swarm.png"
	},
	"nanite_bastion": {
		"id": "nanite_bastion",
		"code": "SYN-04",
		"name": "Нанітний Бастіон",
		"req": {"repair": 3, "drones": 2},
		"desc": "Дрони утворюють захисне нанітне кільце: спалюють усіх ворогів на периметрі та втричі прискорюють регенерацію корпусу корабля.",
		"icon_color": Color(0.3, 1.0, 0.6),
		"icon_path": "res://assets/sprites/ui/gi/nanite_bastion.png"
	},
	"black_ice": {
		"id": "black_ice",
		"code": "SYN-05",
		"name": "Чорний Лід",
		"req": {"virus": 3, "emp": 2},
		"desc": "EMP-хвиля несе вірус: кожен ворог, якого вона торкнулася, заражений.",
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/black_ice.png"
	},
	"ghost_swarm": {
		"id": "ghost_swarm",
		"code": "SYN-06",
		"name": "Рій-Привид",
		"req": {"data_spike": 2, "drones": 2},
		"desc": "Орбітальні дрони перехоплюють сигнали: шанс перехоплення подвоюється, а ракети пробивають ворогів.",
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/ghost_swarm.png"
	},
	"fortress": {
		"id": "fortress",
		"code": "SYN-07",
		"name": "Фортеця",
		"req": {"turret": 3, "armor": 2},
		"desc": "Турелі тримають захисний периметр: поруч із туреллю корабель отримує на 30% менше шкоди, а турелі стріляють удвічі швидше.",
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/fortress.png"
	},
	"emp_mines": {
		"id": "emp_mines",
		"code": "SYN-08",
		"name": "Імпульсні Міни",
		"req": {"mines": 2, "emp": 2},
		"desc": "Міни заряджаються EMP: вибух оглушує ворогів на 1.5 с і має на 40% більший радіус.",
		"icon_color": Color(0.4, 0.8, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/emp_mines.png"
	}
}

# Doctrine: the branch with the most invested points (at least DOCTRINE_MIN_POINTS)
# defines the play style. Each doctrine gives a strong bonus and a real drawback.
# Mods are multipliers unless noted; a missing key means no change.
#   dmg     ship weapon damage        hp      max hull
#   cd      ship weapon cooldown      speed   move speed
#   taken   damage taken              thorns  contact damage per second to rammers (flat)
#   dot     virus and glitch damage   infect  extra infection targets (flat)
#   turret_dmg, turret_life           turret and mine damage, turret lifetime
#   turret_extra                      extra turrets at once (flat)
const DOCTRINE_MIN_POINTS := 4

const DOCTRINES = {
	Branch.OFFENSE: {
		"name": "Штурмовик",
		"bonus": "+30% шкоди зброї корабля, +10% скорострільності",
		"malus": "-25% максимального HP",
		"mods": {"dmg": 1.3, "cd": 0.9, "hp": 0.75}
	},
	Branch.DEFENSE: {
		"name": "Танк",
		"bonus": "+40% максимального HP, -15% отриманої шкоди, шипи корпусу палять ворогів при зіткненні",
		"malus": "-20% швидкості корабля",
		"mods": {"hp": 1.4, "taken": 0.85, "thorns": 45.0, "speed": 0.8}
	},
	Branch.OVERCLOCK: {
		"name": "Перехоплювач",
		"bonus": "+25% швидкості корабля, -15% кулдауну зброї корабля",
		"malus": "+20% отриманої шкоди",
		"mods": {"speed": 1.25, "cd": 0.85, "taken": 1.2}
	},
	Branch.HACK: {
		"name": "Хакер",
		"bonus": "+50% шкоди вірусу та глітч-поля, +1 ціль зараження",
		"malus": "-20% шкоди зброї корабля",
		"mods": {"dot": 1.5, "infect": 1.0, "dmg": 0.8}
	},
	Branch.ENGINEER: {
		"name": "Інженер",
		"bonus": "+1 турель одночасно, +40% шкоди турелей і мін, турелі працюють на 50% довше",
		"malus": "-25% скорострільності зброї корабля",
		"mods": {"turret_extra": 1.0, "turret_dmg": 1.4, "turret_life": 1.5, "cd": 1.25}
	}
}
