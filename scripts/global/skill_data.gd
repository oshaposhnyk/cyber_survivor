extends Node

# Skill Data and Synergy Definitions for Cyber Survivor: Protocol Zero

enum Branch { OFFENSE, DEFENSE, OVERCLOCK }

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
		"icon_path": "res://assets/sprites/ui/icons/target.png",
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
		"icon_path": "res://assets/sprites/ui/icons/fastForward.png",
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
		"icon_path": "res://assets/sprites/ui/cyber/crossair_blue.png",
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
		"icon_path": "res://assets/sprites/ui/icons/gear.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_blueCorner.png",
		"desc": "Автономні бойові дрони обертаються навколо андроїда і знищують ворогів на підльоті.",
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
		"icon_path": "res://assets/sprites/ui/icons/power.png",
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
		"icon_path": "res://assets/sprites/ui/icons/wrench.png",
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
		"icon_path": "res://assets/sprites/ui/icons/signal3.png",
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
		"icon_path": "res://assets/sprites/ui/icons/power.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_greenCorner.png",
		"desc": "Багатошарова композитна броня знижує отримані пошкодження та підвищує максимальне HP.",
		"per_level": "-12% шкоди від усіх атак, +35 максимального HP"
	},

	"speed": {
		"id": "speed",
		"code": "OVC-01",
		"name": "Серво-Оверклокінг",
		"branch": Branch.OVERCLOCK,
		"tier": 1,
		"prereq": "",
		"prereq_lvl": 0,
		"max_lvl": 4,
		"icon_color": Color(1.0, 0.65, 0.15),
		"icon_path": "res://assets/sprites/ui/icons/fastForward.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Форсування сервоприводів ніг і маневрових дюз андроїда.",
		"per_level": "+18% швидкості руху андроїда"
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
		"icon_path": "res://assets/sprites/ui/icons/cpu.png",
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
		"icon_path": "res://assets/sprites/ui/icons/signal3.png",
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
		"icon_path": "res://assets/sprites/ui/icons/star.png",
		"frame_style": "res://assets/sprites/ui/cyber/metalPanel_yellowCorner.png",
		"desc": "Надає всім атакам ефект перевантаження плазмою, розкидаючи ланцюгові блискавки.",
		"per_level": "Блискавка вражає +2 додаткових ворогів поруч"
	}
}

const SYNERGIES = {
	"plasma_storm": {
		"id": "plasma_storm",
		"code": "SYN-01",
		"name": "⚡ Плазмовий Шторм",
		"req": {"blaster": 3, "conductor": 1},
		"desc": "Імпульсний бластер перетворюється на каскадну плазмову пушку: снаряди пробивають та б'ють ланцюговою блискавкою по 3 ворогах одночасно!",
		"icon_color": Color(0.2, 0.9, 1.0),
		"icon_path": "res://assets/sprites/ui/icons/star.png"
	},
	"emp_apocalypse": {
		"id": "emp_apocalypse",
		"code": "SYN-02",
		"name": "💥 Апокаліптичний EMP",
		"req": {"shield": 3, "emp": 2},
		"desc": "При пробитті силового поля або кожні 10 сек вивільняється надпотужний EMP-вибух по всьому екрану, миттєво знищуючи легких дронів!",
		"icon_color": Color(0.9, 0.3, 1.0),
		"icon_path": "res://assets/sprites/ui/icons/signal3.png"
	},
	"valkyrie_swarm": {
		"id": "valkyrie_swarm",
		"code": "SYN-03",
		"name": "🚀 Рій Валькірія",
		"req": {"missiles": 3, "railgun": 2},
		"desc": "Мікро-ракети оснащуються рейлгановими прискорювачами: пронизують ворогів наскрізь і вибухають подвійним ядерним мікро-зарядом!",
		"icon_color": Color(1.0, 0.45, 0.2),
		"icon_path": "res://assets/sprites/ui/icons/fastForward.png"
	},
	"nanite_bastion": {
		"id": "nanite_bastion",
		"code": "SYN-04",
		"name": "🛡️ Нанітний Бастіон",
		"req": {"repair": 3, "drones": 2},
		"desc": "Дрони утворюють захисне нанітне кільце: спалюють усіх ворогів на периметрі та втричі прискорюють регенерацію корпуса андроїда!",
		"icon_color": Color(0.3, 1.0, 0.6),
		"icon_path": "res://assets/sprites/ui/icons/wrench.png"
	}
}
