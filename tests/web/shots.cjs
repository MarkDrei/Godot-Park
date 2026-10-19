// Loads the web export in headless Chromium and takes screenshots for presets.
// Screenshots only: no clicks or key presses (simulated input is unreliable in headless
// Chromium). Behaviour is tested natively with scenario tests (doc/test-scenarios.md).
// Usage: node shots.cjs <playwright-module-dir> <base-url> <out-dir> [preset | perf | scenario:<file>[:<test>] ...]
// Presets with a `budget` are draw-call checks: the game prints its draw calls (autotest=1) and
// the preset fails above the budget. `perf` runs all of them (scripts/web_test.sh perf). Budgets
// are the measured values (Oct 2026, seed=1; runs differ by up to ±4) plus ~4 %: lower them when
// a change saves draw calls, raise them only on purpose.
// scenario:<file> runs a scenario file (tests/scenarios, needs the WebTests export) in a
// phone-sized window with touch and saves a screenshot whenever the test calls shot().
const path = require('path');
const { chromium } = require(path.join(process.argv[2], 'playwright'));
const base = process.argv[3];
const out = process.argv[4];
const PRESETS = {
  title: { q: 'time=10&season=1&weather=0', wait: 9000 },
  overview: { q: 'time=11&season=1&weather=0&freeze=1&cam=-10,60,95,10,0,0', wait: 8000 },
  pond: { q: 'time=10&season=0&weather=0&freeze=1&cam=30,12,40,45,0,6', wait: 8000 },
  pavilion: { q: 'time=16&season=1&weather=0&freeze=1&cam=-20,4,-38,-24,2.5,-52', wait: 8000 },
  food: { q: 'time=13&season=1&weather=0&freeze=1&cam=6,7,30,6,1,48', wait: 8000 },
  bridge: { q: 'time=9&season=2&weather=0&freeze=1&cam=-2,4,6,-8,0,-8', wait: 8000 },
  bridge_wood: { q: 'time=11&season=1&weather=0&freeze=1&cam=-50,3,-27,-58,0,-33', wait: 8000 },
  bridge_duck: { q: 'time=11&season=1&weather=0&freeze=1&cam=80,3.5,19,73,0,13', wait: 8000 },
  path_gravel: { q: 'time=11&season=1&weather=0&freeze=1&cam=16,2.4,-11,19,0,-15', wait: 8000 },
  path_trail: { q: 'time=11&season=1&weather=0&freeze=1&cam=-93,2,-28,-98,0,-40', wait: 8000 },
  plaza: { q: 'time=11&season=1&weather=0&freeze=1&cam=-46,5,30,-56,0,18', wait: 8000 },
  sidewalk: { q: 'time=11&season=1&weather=0&freeze=1&cam=-20,2.5,99,-10,0,93', wait: 8000 },
  trees_close: { q: 'time=11&season=1&weather=0&freeze=1&cam=-26,1.8,14,-31,2.2,7', wait: 8000 },
  path_edges: { q: 'time=11&season=1&weather=0&freeze=1&cam=-24,7,16,-32,0,8', wait: 8000 },
  night: { q: 'time=22.5&season=1&weather=0&freeze=1&cam=-40,10,30,-56,1,18', wait: 8000 },
  winter: { q: 'time=12&season=3&weather=4&freeze=1&cam=60,20,-20,90,4,-58', wait: 9000 },
  play_jens: { q: 'time=10&season=1&weather=0&control=jens&autotest=1', wait: 20000 },
  play_dog: { q: 'time=11&season=1&weather=0&control=bello', wait: 9000 },
  play_duck: { q: 'time=11&season=0&weather=0&control=erwin', wait: 9000 },
  rain: { q: 'time=15&season=2&weather=2&control=peggy', wait: 9000 },
  mg_boule: { q: 'time=11&season=1&weather=0&control=jens&minigame=boule', wait: 12000 },
  stand_hotdog: { q: 'time=13&season=1&weather=0&freeze=1&cam=-72,3.5,11,-72,1.5,21', wait: 8000 },
  stand_icecream: { q: 'time=13&season=1&weather=0&freeze=1&cam=5,3.5,-59,5,1.5,-49', wait: 8000 },
  stand_fries: { q: 'time=13&season=1&weather=0&freeze=1&cam=84,3.5,-2,92,1.5,6', wait: 8000 },
  sit_touch: { q: 'time=11&season=1&weather=0&control=herbert&sit=1&touch=1', wait: 12000 },
  sit: { q: 'time=11&season=1&weather=0&control=herbert&sit=1', wait: 12000 },
  mg_minigolf: { q: 'time=11&season=1&weather=0&control=jens&minigame=minigolf', wait: 10000 },
  mg_shell: { q: 'time=14&season=1&weather=0&control=jens&minigame=shell', wait: 9000 },
  mg_ttt: { q: 'time=14&season=1&weather=0&control=jens&minigame=ttt', wait: 9000 },
  mg_photo: { q: 'time=14&season=1&weather=0&control=jens&minigame=photo', wait: 9000 },
  mg_ducks: { q: 'time=14&season=1&weather=0&control=jens&minigame=ducks', wait: 12000 },
  mg_frisbee: { q: 'time=14&season=1&weather=0&control=jens&minigame=frisbee', wait: 9000 },
  map: { q: 'time=14&season=1&weather=0&control=jens&ui=map', wait: 8000 },
  map_whole: { q: 'time=14&season=1&weather=0&control=jens&ui=map_whole', wait: 8000 },
  map_forest: { q: 'time=14&season=1&weather=0&control=jens&at=-30,-150&ui=map', wait: 8000 },
  bag: { q: 'time=14&season=1&weather=0&control=jens&items=log:24,stone:7,berries:5,apple:3,stone_axe:1,iron_pickaxe:1,gem:2,takeaway_fries:1,birdhouse:1,bread:5,takeaway_hotdog:1&ui=bag', wait: 8000 },
  bag_touch: { q: 'time=14&season=1&weather=0&control=jens&touch=1&items=log:8,twig:12,mushroom:4,fishing_rod:1&ui=chest', wait: 8000 },
  bag_overfull: { q: 'time=14&season=1&weather=0&control=jens&items=log:60,twig:40,stone:40,berries:5,apple:3,gem:2,fish:1,board:5,teddy:1,stone_axe:1&ui=bag', wait: 8000 },
  hud_items: { q: 'time=14&season=1&weather=0&control=jens&items=log:8,twig:12,mushroom:4', wait: 8000 },
  craft: { q: 'time=14&season=1&weather=0&control=jens&at=-35,-162&items=twig:8,stone:5,log:6,board:2,ore:1&ui=workbench', wait: 8000 },
  gather_orchard: { q: 'time=11&season=1&weather=0&freeze=1&cam=96,10,-120,96,1,-140', wait: 8000 },
  gather_glade: { q: 'time=11&season=1&weather=0&freeze=1&cam=-8,4,-196,2,0.5,-204', wait: 8000 },
  gather_quarry: { q: 'time=11&season=1&weather=0&freeze=1&cam=58,4,-218,58,0.5,-232', wait: 8000 },
  mg_axes: { q: 'time=11&season=1&weather=0&control=jens&minigame=axes', wait: 11000 },
  mg_chopping: { q: 'time=11&season=1&weather=0&control=jens&minigame=chopping', wait: 11000 },
  mg_switch: { q: 'time=11&season=1&weather=0&control=jens&minigame=switch', wait: 16000 },
  people_forest: { q: 'time=12&season=1&weather=0&freeze=1&lineup=holger,sepp,waltraud,ilse,berta,hanna,willi', wait: 7000 },
  people_dwarves: { q: 'time=12&season=1&weather=0&freeze=1&lineup=grimbart,brakka,nori,thrain', wait: 7000 },
  forest_farmshop: { q: 'time=11&season=1&weather=0&freeze=1&cam=-2,3,-96,9,1.5,-101', wait: 8000 },
  forest_overview: { q: 'time=11&season=1&weather=0&freeze=1&cam=0,70,-60,0,0,-180', wait: 9000 },
  forest_gate: { q: 'time=11&season=1&weather=0&freeze=1&cam=2,4,-74,0,2,-100', wait: 8000 },
  forest_inside: { q: 'time=11&season=1&weather=0&freeze=1&cam=0,3,-108,-30,2,-155', wait: 8000 },
  forest_mountain: { q: 'time=11&season=1&weather=0&freeze=1&cam=50,6,-222,74,6,-260', wait: 8000 },
  forest_pond: { q: 'time=16&season=1&weather=0&freeze=1&cam=-30,3,-214,-50,0,-226', wait: 8000 },
  forest_bench_glade: { q: 'time=11&season=1&weather=0&freeze=1&cam=4,2.6,-207,2,0.6,-200', wait: 8000 },
  forest_bench_pond: { q: 'time=16&season=1&weather=0&freeze=1&cam=-40,2.8,-231,-44,0.6,-238', wait: 8000 },
  forest_bench_road: { q: 'time=11&season=1&weather=0&freeze=1&cam=-4,2.6,-126,2.7,0.6,-130.3', wait: 8000 },
  forest_camp: { q: 'time=17&season=1&weather=0&freeze=1&cam=-30,5,-146,-42,1,-162', wait: 8000 },
  forest_inn: { q: 'time=12&season=1&weather=0&freeze=1&cam=10,4,-146,28,2,-152', wait: 8000 },
  forest_sawmill: { q: 'time=12&season=1&weather=0&freeze=1&cam=-70,3.5,-114,-72,1.5,-125', wait: 8000 },
  forest_dwarves: { q: 'time=12&season=1&weather=0&freeze=1&cam=46,7,-222,70,2,-246', wait: 8000 },
  forest_night: { q: 'time=22&season=1&weather=0&freeze=1&cam=16,4,-146,30,2,-152', wait: 8000 },
  forest_walk: { q: 'time=11&season=1&weather=0&control=jens&at=-3,-122', wait: 9000 },
  tasks: { q: 'time=14&season=1&weather=0&control=jens&ui=tasks', wait: 8000 },
  // Oststadt (city=1 loads the town at the start).
  park_east: { q: 'time=11&season=1&weather=0&freeze=1&cam=108,4,-14,140,5,-12', wait: 8000 },
  fair_from_park: { q: 'time=11&season=1&weather=0&freeze=1&cam=-108,6,8,-160,5,0', wait: 9000 },
  burg_overview: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-150,70,-60,-265,5,-180', wait: 18000 },
  burg_gate: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-262,4,-80,-265,4,-150', wait: 18000 },
  burg_lists: { q: 'time=14&season=1&weather=0&freeze=1&burg=1&cam=-240,8,-95,-300,1,-125', wait: 18000 },
  burg_market: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-262,7,-150,-268,5,-195', wait: 18000 },
  burg_tavern: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-283,5,-172,-298,2.5,-155', wait: 18000 },
  herbs_burg: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-354.5,5.2,-209,-357,3.6,-211.3', wait: 18000 },
  herbs_park: { q: 'time=11&season=1&weather=0&freeze=1&cam=36.4,1.5,-21.6,38,0.4,-23.3', wait: 12000 },
  herbs_hedges: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-170.5,7.3,-235.5,-173.4,6.2,-238.1', wait: 18000 },
  bag_herbs: { q: 'time=11&season=1&weather=0&control=jens&items=chamomile:4,elder:2,woodruff:3,wild_garlic:2,lavender:2,st_johns_wort:3,rose_hip:2,berries:2,potion_speed:1,potion_herbs:1,potion_mining:1,horseshoe:1&ui=bag', wait: 12000 },
  burg_witch: { q: 'time=14&season=1&weather=0&freeze=1&burg=1&cam=-326,7,-180,-334,5,-183', wait: 18000 },
  burg_square: { q: 'time=15&season=1&weather=0&freeze=1&burg=1&cam=-265,12,-195,-265,7,-230', wait: 18000 },
  burg_top: { q: 'time=11&season=1&weather=0&freeze=1&burg=1&cam=-265,13,-214,-265,10,-240', wait: 18000 },
  burg_night: { q: 'time=21.8&season=1&weather=0&freeze=1&burg=1&cam=-200,30,-110,-265,5,-185', wait: 18000 },
  burg_from_fair: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-262,6,-60,-265,6,-150', wait: 16000 },
  burg_from_forest: { q: 'time=11&season=1&weather=0&freeze=1&cam=-110,8,-195,-220,6,-200', wait: 12000 },
  people_burg1: { q: 'time=12&season=1&weather=0&freeze=1&burg=1&lineup=kunibert,adelheid,eckhard,till,jolanda,gernot,walburga,quirin', wait: 18000 },
  people_burg2: { q: 'time=12&season=1&weather=0&freeze=1&burg=1&lineup=brunhild,wirtin,ferkelsepp,mechthild,fiete,wuerfelfritz,hannes,ludwig', wait: 18000 },
  people_burg4: { q: 'time=12&season=1&weather=0&freeze=1&burg=1&lineup=rudolf,krahliese,fenja,falko,blitz,donner,hafer,wolke', wait: 18000 },
  map_burg: { q: 'time=14&season=1&weather=0&control=jens&at=-265,-205&ui=map', wait: 20000 },
  people_burg3: { q: 'time=12&season=1&weather=0&freeze=1&burg=1&lineup=jo,wendelin,liesel,morwen,ottilie,gunther,irmela,kasimir,hiltrud', wait: 18000 },
  fair_overview: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-140,75,70,-265,0,-10', wait: 16000 },
  fair_booths: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-178,3.5,3,-220,2,3', wait: 16000 },
  fair_stalls: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-203,2.4,1.5,-214,2.6,-4', wait: 22000 },
  fair_stalls_night: { q: 'time=21.8&season=1&weather=0&freeze=1&fair=1&cam=-203,2.4,1.5,-214,2.6,-4', wait: 22000 },
  fair_food: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-238,2.6,58,-242,2.8,66', wait: 22000 },
  fair_carousel: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-310,3.4,34,-300,2.6,24', wait: 22000 },
  fair_chain: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-331,3.5,-12,-318,4.5,-22', wait: 22000 },
  fair_swing: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-281,3.5,73,-292,4,62', wait: 22000 },
  fair_coaster: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-334,4,-38,-344,2.5,-51', wait: 22000 },
  fair_halls: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-276,4,-38,-286,4,-57', wait: 22000 },
  fair_bumper: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-330,4,24,-338,4,10', wait: 22000 },
  fair_arcade_day: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-230,3.5,-42,-236,3.5,-56', wait: 22000 },
  fair_stage: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-192,3,58,-188,2.5,70', wait: 22000 },
  fair_tent: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-364,3,62,-366,2,72', wait: 22000 },
  fair_prizes: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-202,2.8,-44,-206,2.5,-52', wait: 22000 },
  fair_rides_night: { q: 'time=21.8&season=1&weather=0&freeze=1&fair=1&cam=-292,14,-14,-335,3,-55', wait: 16000 },
  fair_wheel: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-250,5,32,-264,9,-8', wait: 16000 },
  fair_rides: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-292,14,-14,-335,3,-55', wait: 16000 },
  fair_south: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-262,10,44,-282,2,64', wait: 16000 },
  fair_east: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-138,12,72,-165,0,25', wait: 16000 },
  fair_night: { q: 'time=21.8&season=1&weather=0&freeze=1&fair=1&cam=-196,14,34,-262,7,-2', wait: 16000 },
  fair_west: { q: 'time=11&season=1&weather=0&freeze=1&fair=1&cam=-312,6,30,-345,2,62', wait: 16000 },
  map_fair: { q: 'time=14&season=1&weather=0&control=jens&at=-200,5&ui=map', wait: 16000 },
  fair_night_high: { q: 'time=21.8&season=1&weather=0&freeze=1&fair=1&cam=-150,90,90,-262,0,-10', wait: 16000 },
  fair_night_garden: { q: 'time=21.8&season=1&weather=0&freeze=1&fair=1&cam=-172,7,72,-160,2,52', wait: 16000 },
  people_fair1: { q: 'time=12&season=1&weather=0&freeze=1&fair=1&lineup=zora,manni,bernd,claudette,doris,erna,rita,dieter', wait: 16000 },
  people_fair2: { q: 'time=12&season=1&weather=0&freeze=1&fair=1&lineup=moritz,gisela,lothar,max,karl,aylin,geistgustav,sascha,esmeralda,zambini', wait: 16000 },
  fair_crowd: { q: 'time=15.5&season=1&weather=0&fair=1&control=jens&at=-205,3', wait: 22000 },
  ride_ferris: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-262,4&minigame=ride_ferris', wait: 34000 },
  ride_ferris_top: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-262,4&minigame=ride_ferris', wait: 48000 },
  ride_ghost_late: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-286,-50&minigame=ride_ghost', wait: 44000 },
  ride_ghost: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-286,-50&minigame=ride_ghost', wait: 34000 },
  ride_bumper: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-322,4&minigame=bumper', wait: 24000 },
  ride_coaster: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-344,-47&minigame=ride_coaster', wait: 30000 },
  ride_chain: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-310,-18&minigame=ride_chain', wait: 34000 },
  perf_park: { q: 'time=14&season=1&weather=0&control=jens&autotest=1&seed=1', wait: 16000, budget: 500 },   // 492 with the herbs (Oct 2026)
  perf_fair_all: { q: 'time=14&season=1&weather=0&areas=all&control=jens&at=-230,3&autotest=1&seed=1', wait: 24000, budget: 425 },
  perf_fair_split: { q: 'time=14&season=1&weather=0&areas=split&control=jens&at=-230,3&autotest=1&seed=1', wait: 24000, budget: 425 },
  perf_burg_all: { q: 'time=14&season=1&weather=0&areas=all&control=jens&at=-265,-160&autotest=1&seed=1', wait: 26000, budget: 520 },
  perf_burg_split: { q: 'time=14&season=1&weather=0&areas=split&control=jens&at=-265,-160&autotest=1&seed=1', wait: 26000, budget: 392 },   // 385 with the herbs
  perf_city: { q: 'time=14&season=1&weather=0&areas=split&control=jens&at=212,-40&autotest=1&seed=1', wait: 32000, budget: 300 },
  perf_city_south: { q: 'time=14&season=1&weather=0&areas=split&control=jens&at=283,30&autotest=1&seed=1', wait: 32000, budget: 190 },
  // On the Kastanienallee the view runs down the whole town both ways (308 when it was added).
  perf_city_allee: { q: 'time=14&season=1&weather=0&areas=split&control=jens&at=432,-40&autotest=1&seed=1', wait: 32000, budget: 315 },
  booth_cans: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_cans', wait: 24000 },
  booth_ducks: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_ducks', wait: 24000 },
  booth_rings: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_rings', wait: 24000 },
  booth_darts: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_darts', wait: 24000 },
  booth_moles: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_moles', wait: 24000 },
  booth_wheel: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_wheel', wait: 24000 },
  booth_striker: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-210,3&minigame=booth_striker', wait: 24000 },
  arcade_snake: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-236,-60&minigame=arcade_snake', wait: 26000 },
  arcade_astro: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-236,-60&minigame=arcade_astro', wait: 26000 },
  arcade_bricks: { q: 'time=14&season=1&weather=0&fair=1&control=jens&at=-236,-60&minigame=arcade_bricks', wait: 26000 },
  arcade_touch: { q: 'time=14&season=1&weather=0&fair=1&control=jens&touch=1&at=-236,-60&minigame=arcade_astro', wait: 26000 },
  fair_arcade_hall: { q: 'time=20.5&season=1&weather=0&freeze=1&fair=1&cam=-236,5,-44,-236,1.5,-66', wait: 16000 },
  fair_ghost: { q: 'time=23&season=1&weather=0&freeze=1&fair=1&cam=-289.5,2.6,-44.5,-293.5,1.4,-51', wait: 16000 },
  city_overview: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=255,110,80,262,0,-95', wait: 22000 },
  city_street: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=212,2.4,-2,209,1.2,-60', wait: 22000 },
  city_crossing: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=225,9,-2,210,0,-12', wait: 22000 },
  city_market: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=226,7,-38,242,1,-52', wait: 22000 },
  city_drivein: { q: 'time=13&season=1&weather=0&freeze=1&city=1&cam=150,7,-32,166,1,-58', wait: 22000 },
  city_cinema: { q: 'time=21.5&season=1&weather=0&freeze=1&city=1&cam=175,6,-168,175,7,-228', wait: 22000 },
  city_petrol: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=163,7,-100,180,1,-125', wait: 22000 },
  city_karting: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=245,28,-158,246,0,-208', wait: 22000 },
  city_scrapyard: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=303,11,-164,326,4,-206', wait: 22000 },
  city_houses: { q: 'time=17&season=1&weather=0&freeze=1&city=1&cam=246,5,20,262,3,40', wait: 22000 },
  city_cars: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=200,2.2,-30,206,0.8,-44', wait: 22000 },
  city_special_cars: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=188,3,4,196,0.8,11', wait: 22000 },
  city_cars_side: { q: 'time=15&season=1&weather=0&freeze=1&city=1&cam=203.5,1.4,-49,213,0.8,-46', wait: 22000 },
  city_lots_cars: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=226,4,-102,236,1,-115', wait: 22000 },
  drive_arrow: { q: 'time=11&season=1&weather=0&control=jens&drive=taxi&minigame=taxi', wait: 26000 },
  city_yards: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=300,16,-2,312,0,22', wait: 22000 },
  city_orchard: { q: 'time=15&season=1&weather=0&freeze=1&city=1&cam=246,4,58,246,1,32', wait: 22000 },
  pg_top: { q: 'time=12&season=1&weather=0&freeze=1&cam=-37,48,104,-37,0,70', wait: 9000 },
  pg_overview: { q: 'time=12&season=1&weather=0&freeze=1&cam=-38,11,98,-38,0,68', wait: 9000 },
  pg_entrance: { q: 'time=11&season=1&weather=0&freeze=1&cam=-40.5,2.3,43.2,-41.5,1.5,50', wait: 9000 },
  perf_playground: { q: 'time=14&season=1&weather=0&control=jens&at=-38,55&autotest=1&seed=1', wait: 16000, budget: 315 },
  pg_swings: { q: 'time=11&season=1&weather=0&freeze=1&cam=-42,2.8,63.5,-50,1.2,63.5', wait: 9000 },
  pg_nest: { q: 'time=11&season=1&weather=0&freeze=1&cam=-42.5,2.4,86,-47,1.3,82.8', wait: 9000 },
  pg_seesaw_carousel: { q: 'time=11&season=1&weather=0&freeze=1&cam=-38.5,2.6,74,-38.5,0.6,68.5', wait: 9000 },
  pg_sandbox: { q: 'time=11&season=1&weather=0&freeze=1&cam=-38,4.2,68.5,-38,0.2,60.5', wait: 9000 },
  pg_tower: { q: 'time=11&season=1&weather=0&freeze=1&cam=-24.5,3.2,64.5,-28,1.4,58', wait: 9000 },
  pg_net_springs: { q: 'time=11&season=1&weather=0&freeze=1&cam=-32,2.8,71.5,-26,1,65', wait: 9000 },
  pg_trampoline_beam: { q: 'time=11&season=1&weather=0&freeze=1&cam=-35,3.2,77.8,-32,0.4,82.5', wait: 9000 },
  city_playground: { q: 'time=15&season=1&weather=0&freeze=1&city=1&cam=352,9,-116,375,0,-128', wait: 22000 },
  city_benches: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=279,2.6,-47,270,0.6,-39', wait: 22000 },
  city_shops: { q: 'time=17.5&season=1&weather=0&freeze=1&city=1&cam=236,3,-14,250,2.5,-3', wait: 22000 },
  city_lots: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=205,12,-15,180,0,-45', wait: 22000 },
  city_overview_south: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=260,70,110,262,0,10', wait: 22000 },
  city_night: { q: 'time=22&season=1&weather=0&freeze=1&city=1&cam=212,6,-4,210,1,-50', wait: 22000 },
  city_allee: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=424,5,10,420,1,-60', wait: 22000 },
  city_allee_crossing: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=440,14,-70,420,0,-90', wait: 22000 },
  city_overview_east: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=520,110,80,520,0,-95', wait: 22000 },
  city_townhall: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=426,4,-51,462,5,-51', wait: 22000 },
  city_east_lots: { q: 'time=11&season=1&weather=0&freeze=1&city=1&cam=545,45,-95,560,0,-175', wait: 22000 },
  city_rosegarden: { q: 'time=15&season=1&weather=0&freeze=1&city=1&cam=525,6,62,525,1,32', wait: 22000 },
  drive_car: { q: 'time=11&season=1&weather=0&control=jens&drive=small', wait: 14000 },
  drive_touch: { q: 'time=11&season=1&weather=0&control=jens&drive=kombi&touch=1', wait: 14000 },
  people_city: { q: 'time=12&season=1&weather=0&freeze=1&city=1&lineup=tanja,kurt,toni,bodo,karla,friedrich,siggi,gianni,petra,egon', wait: 24000 },
  people_city2: { q: 'time=12&season=1&weather=0&freeze=1&city=1&lineup=kerstin,conny,deniz', wait: 24000 },
  mg_crane: { q: 'time=11&season=1&weather=0&city=1&control=jens&minigame=crane', wait: 26000 },
  mg_karts: { q: 'time=11&season=1&weather=0&city=1&control=jens&minigame=karts', wait: 26000 },
  mg_parking: { q: 'time=11&season=1&weather=0&city=1&control=jens&minigame=parking', wait: 26000 },
  // Areas: split (only the player's area loaded): the park's backdrop seen from town, the gate question.
  split_town_west: { q: 'time=11&season=1&weather=0&freeze=1&areas=split&control=jens&at=150,-12&cam=152,10,-4,105,0,-16', wait: 24000 },
  all_town_west: { q: 'time=11&season=1&weather=0&freeze=1&areas=all&control=jens&at=150,-12&cam=152,10,-4,105,0,-16', wait: 24000 },
  split_gate: { q: 'time=11&season=1&weather=0&areas=split&control=jens&at=128.4,-12', wait: 14000 },
  map_city: { q: 'time=14&season=1&weather=0&control=jens&at=212,-40&ui=map', wait: 20000 },
  start: { q: 'time=9&season=0&weather=0', wait: 9000 },
  people1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=jens,herbert,peggy,heinz,dora,kemal', wait: 7000 },
  people2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=mia,boris,pierre,thorsten,gertrud,lena,sabine', wait: 7000 },
  people3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=kalle,lukas,jacques,harry,ricarda,yvonne,bruno', wait: 7000 },
  animals1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=bello,luna,rex,kruemel,fiffi,balu', wait: 7000 },
  animals2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=minka,mikesch,pieps,nussi,stachel,fridolin', wait: 7000 },
  animals3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=erwin,frieda,klecks,gustav,gurrmann,rudi,eulalia', wait: 7000 },
};
// Landscape phone: 844x390 CSS pixels (19.5:9) at device pixel ratio 2.
const PHONE = { viewport: { width: 844, height: 390 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };

// Runs one scenario spec; the game prints "SHOT <label>" and waits for window.__shot.
async function runScenario(browser, spec) {
  const dir = path.join(out, spec.split(':')[0]);
  require('fs').mkdirSync(dir, { recursive: true });
  const page = await browser.newPage(PHONE);
  let failed = false, done = false, shots = 0, queue = Promise.resolve();
  page.on('console', m => {
    const t = m.text();
    if (t.startsWith('SHOT ')) {
      const label = t.slice(5).trim();
      queue = queue.then(async () => {
        // Software rendering of the park can take longer than the default 30 s per frame.
        await page.screenshot({ path: path.join(dir, `${label}.png`), timeout: 120000 });
        await page.evaluate(l => { window.__shot = l; }, label);
        shots++;
      });
    } else if (/^SCENARIO|^    |SCRIPT ERROR|^ERROR/.test(t)) {
      console.log(t);
      if (/^SCENARIO FAIL|SCRIPT ERROR/.test(t)) failed = true;
      if (t.startsWith('SCENARIO DONE')) done = true;
    }
  });
  // After SCENARIO DONE the game quits; the web audio then throws (currentTime of null).
  page.on('pageerror', e => { if (!done) { console.log('pageerror: ' + e.message); failed = true; } });
  await page.goto(`${base}/index.html?scenario=${spec}&seed=1&time=11&season=1&weather=0&touch=1`);
  const t0 = Date.now();
  while (!done && Date.now() - t0 < 1800000) await page.waitForTimeout(500);
  await queue;
  console.log(`${spec}: ${shots} screenshots in ${path.relative(process.cwd(), dir)}${done ? '' : ', TIMEOUT'}`);
  await page.close();
  return failed || !done;
}

(async () => {
  const args = process.argv.slice(5);
  const names = (args.length ? args : Object.keys(PRESETS))
    .flatMap(n => n === 'perf' ? Object.keys(PRESETS).filter(k => PRESETS[k].budget) : [n]);
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  let failed = 0;
  for (const name of names) {
    if (name.startsWith('scenario:')) {
      if (await runScenario(browser, name.slice(9))) failed++;
      continue;
    }
    const p = PRESETS[name];
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    let drawCalls = -1;
    page.on('console', m => {
      const t = m.text();
      if (/ERROR|SCRIPT ERROR/.test(t)) errors.push(t);
      if (t.startsWith('AUTOTEST')) {
        console.log('  ' + t);
        drawCalls = Number((t.match(/draw_calls=(\d+)/) || [])[1] ?? -1);
      }
    });
    page.on('pageerror', e => errors.push('pageerror: ' + e.message));
    await page.goto(`${base}/index.html?${p.q}`);
    // Wait until the game reports it is running, then let it settle.
    try {
      await page.waitForFunction(() => document.title !== '' && !document.querySelector('#status')?.offsetParent, null, { timeout: 120000 });
    } catch (e) { errors.push('timeout waiting for start'); }
    await page.waitForTimeout(p.wait);
    await page.screenshot({ path: path.join(out, `${name}.png`), timeout: 120000 });   // software rendering can be slow
    if (p.budget) {
      if (drawCalls < 0) errors.push('no AUTOTEST line with draw calls');
      else if (drawCalls > p.budget) errors.push(`${drawCalls} draw calls, budget ${p.budget}`);
      else console.log(`  draw calls ${drawCalls} of ${p.budget}`);
    }
    console.log(`${name}: ${errors.length ? 'ERRORS\n  ' + errors.slice(0, 8).join('\n  ') : 'ok'}`);
    if (errors.length) failed++;
    await page.close();
  }
  await browser.close();
  process.exit(failed ? 1 : 0);
})();
