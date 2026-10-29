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
		"desc": "Базовий плазмовий випромінювач. Болт, що зустрів ворожий снаряд, знищує його разом із собою.",
		"per_level": "+6 шкоди, -0.06 с перезарядки, +1 снаряд на 3-му та 5-му рівнях"
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
		"desc": "Залп самонавідних ракет. Перша ракета летить у стрільця, який зараз цілиться в корабель.",
		"per_level": "+1 ракета в залпі, +15 шкоди, +10 до радіуса вибуху"
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
		"desc": "Тахіонний промінь пробиває всіх ворогів на лінії і спалює ворожі снаряди, відкриваючи безпечний коридор. Спершу цілить у стрільців, що прицілюються.",
		"per_level": "+45 шкоди променя, -0.35 с перезарядки"
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
		"desc": "Бойові дрони кружляють навколо корабля, збивають ворогів на підльоті і перехоплюють ворожі снаряди.",
		"per_level": "+1 захисний дрон, +20% радіус орбіти та швидкість польоту"
	},
	"orbital_strike": {
		"id": "orbital_strike",
		"code": "WPN-05",
		"name": "Орбітальний Удар",
		"branch": Branch.OFFENSE,
		"tier": 5,
		"prereq": "drones",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(1.0, 0.25, 0.3),
		"icon_path": "res://assets/sprites/ui/gi/hazard.png",
		"desc": "Супутник б'є по найщільнішому скупченню або по стрільцю, що цілиться: кільце-попередження 0.6 с, потім вибух, що стирає ворожі снаряди.",
		"per_level": "+75 шкоди, +20 до радіуса, -1 с перезарядки"
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
		"desc": "Енергетичний бар'єр поглинає шкоду перед корпусом. Поки щит тримається, частина ворожих снарядів відбивається назад у стрільців.",
		"per_level": "+35 ємності щита, -0.6 с до відновлення, шанс відбиття 35% (+6% за рівень)"
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
		"per_level": "+2.2 HP регенерації щосекунди"
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
		"per_level": "+60 до радіуса притягання брухту"
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
	"shield_reboot": {
		"id": "shield_reboot",
		"code": "DEF-05",
		"name": "Перезапуск Щита",
		"branch": Branch.DEFENSE,
		"tier": 5,
		"prereq": "armor",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(0.2, 0.85, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/hp.png",
		"desc": "Коли щит пробито, корабель випускає ударну хвилю 220 px: ранить і відкидає ворогів, стирає снаряди, а щит одразу відновлюється на 50%.",
		"per_level": "+30 шкоди хвилі, -4 с між перезапусками (20 с на 1-му рівні)"
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
		"desc": "Форсаж двигунів. Ривок лишає вакуумний слід, що поглинає ворожі снаряди на лінії польоту.",
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
		"desc": "Оверклокінг процесора. Разом з Форсажем створює поле дилатації (200 px): ворожі снаряди в ньому летять на 50% повільніше, з 3-го рівня обох навичок — на 60%.",
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
		"desc": "Періодична електромагнітна хвиля оглушує ворожих дронів і стирає всі ворожі снаряди на своєму шляху.",
		"per_level": "+40 до радіуса, +20 шкоди та +0.5 с оглушення імпульсу"
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
		"desc": "Снаряди бластера, дронів і турелей перескакують ланцюговою блискавкою на сусідніх ворогів.",
		"per_level": "Блискавка вражає +2 ворогів поруч"
	},
	"stasis": {
		"id": "stasis",
		"code": "OVC-05",
		"name": "Стоп-Кадр",
		"branch": Branch.OVERCLOCK,
		"tier": 5,
		"prereq": "conductor",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(1.0, 0.85, 0.2),
		"icon_path": "res://assets/sprites/ui/gi/time.png",
		"desc": "Періодично зупиняє час: усі вороги поблизу оглушені, ворожі снаряди застигають у повітрі.",
		"per_level": "+0.5 с зупинки (1.5 с на 1-му рівні), -3 с між зупинками (22 с)"
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
		"desc": "Періодично заражає найближчих ворогів. Заражені втрачають міцність щосекунди, стріляють у 2.5 раза рідше, а при знищенні передають вірус сусідам і стирають снаряди поруч.",
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
		"desc": "Поле перешкод сповільнює ворогів і ранить їх. Стрільці в полі втрачають наведення: розкид 90°, і їхні снаряди б'ють своїх.",
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
		"desc": "Знищений ворог іноді випускає перехоплену ракету. Ворожий снаряд біля корабля може бути зламаний: він зеленіє і летить у найближчого ворога.",
		"per_level": "+6% шанс ракети, +20% її шкоди, злам снаряда 20% (+6.7% за рівень)"
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
	"mind_control": {
		"id": "mind_control",
		"code": "HCK-05",
		"name": "Контроль Розуму",
		"branch": Branch.HACK,
		"tier": 5,
		"prereq": "botnet",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(0.2, 1.0, 0.55),
		"icon_path": "res://assets/sprites/ui/gi/pilot.png",
		"desc": "Найближчий стрілець тимчасово переходить на ваш бік: не таранить корабель і стріляє зеленими снарядами по ворогах.",
		"per_level": "+2 с контролю (4 с на 1-му рівні), -2 с між зламами (12 с)"
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
		"desc": "Стаціонарна турель стріляє по найближчих ворогах. Її корпус зупиняє ворожі снаряди і відволікає частину вогню на себе.",
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
		"desc": "Корабель скидає за кормою магнітні міни. Вибух міни ранить ворогів і знищує ворожі снаряди в радіусі.",
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
		"desc": "Турелі отримують тесла-котушку: б'ють розрядом ворогів поруч і збивають ворожі снаряди в радіусі 140 px.",
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
		"desc": "Турелі отримують ракетну установку і зенітний модуль: збивають ворожі снаряди поруч і запускають ракети.",
		"per_level": "+1 ракета в залпі, -0.5 с перезарядки"
	},
	"dome": {
		"id": "dome",
		"code": "ENG-05",
		"name": "Генератор Купола",
		"branch": Branch.ENGINEER,
		"tier": 5,
		"prereq": "missile_battery",
		"prereq_lvl": 2,
		"max_lvl": 3,
		"icon_color": Color(1.0, 0.55, 0.15),
		"icon_path": "res://assets/sprites/ui/gi/home.png",
		"desc": "Турелі розгортають купол: він стирає ворожі снаряди, а корабель усередині відновлює корпус.",
		"per_level": "+20 до радіуса купола (110 на 1-му рівні), +2 HP/с ремонту (3 на 1-му рівні)"
	}
}

const SYNERGIES = {
	"plasma_storm": {
		"id": "plasma_storm",
		"code": "SYN-01",
		"name": "Плазмовий Шторм",
		"req": {"blaster": 3, "conductor": 1},
		"desc": "Бластер стріляє трьома снарядами, кожен пробиває двох ворогів, а ланцюгова блискавка вражає на одну ціль більше.",
		"icon_color": Color(0.2, 0.9, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/plasma_storm.png"
	},
	"emp_apocalypse": {
		"id": "emp_apocalypse",
		"code": "SYN-02",
		"name": "Апокаліптичний EMP",
		"req": {"shield": 3, "emp": 2},
		"desc": "Кожен EMP-імпульс накриває весь екран з подвійною шкодою та оглушенням на 4 с. Пробиття силового поля теж вивільняє такий імпульс.",
		"icon_color": Color(0.9, 0.3, 1.0),
		"icon_path": "res://assets/sprites/ui/gi/emp_apocalypse.png"
	},
	"valkyrie_swarm": {
		"id": "valkyrie_swarm",
		"code": "SYN-03",
		"name": "Рій Валькірія",
		"req": {"missiles": 3, "railgun": 2},
		"desc": "Мікро-ракети отримують рейлганові прискорювачі: летять на 35% швидше, пробивають двох ворогів і вибухають у півтора раза ширше.",
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
		"bonus": "+40% HP, -15% шкоди, шипи корпусу; купол «Егіда» на 2.5 с зупиняє снаряди після сильного удару або кожні 15 с",
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
