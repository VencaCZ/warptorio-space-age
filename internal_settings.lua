local techPacks={red="automation-science-pack",green="logistic-science-pack",blue="chemical-science-pack",black="military-science-pack",
	purple="production-science-pack",yellow="utility-science-pack",white="space-science-pack",vulcanus="metallurgic-science-pack",gleba="agricultural-science-pack",aquilo="cryogenic-science-pack",fulgora="electromagnetic-science-pack",final="promethium-science-pack"}
local function SciencePacks(x) local t={} for k,v in pairs(x)do table.insert(t,{techPacks[k],v}) end return t end

local function mysplit (inputstr, sep,extra)
   local extra = extra or ""
   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, extra..str)
   end
   return t
end

local warp_sizes = require("factory_sizes")

local function internal_loot()
   local items = {}
   if not prototypes then return {} end
   for _,item in pairs(prototypes.item) do
      if item.group.name == "intermediate-products"  and
         item.name ~= "coin" and item.name ~= "science" and
         item.subgroup.name ~= "barrel" and
         item.hidden == false then
         table.insert(items,item.name)
      end
   end
   return items
end

local local_settings = {
  floor = {
    levels={
	    [1]=6,
	    [2]=12,
	    [3]=18,
	    [4]=24,
	    [5]=30,
	    [6]=36,
	    [7]=52,
	    [8]=70,
    }
  },
  train = {
     ground_station = "WarpGround",
     factory_station = "WarpFactory"
  },
  starter_items = {
     ["coal"]=1000,["iron-plate"]=500,["copper-plate"]=200,
     ["wooden-chest"]=10,["transport-belt"]=100,["underground-belt"]=25,["splitter"]=10,
     ["burner-mining-drill"]=20,["assembling-machine-1"]=2,
     ["small-electric-pole"]=10,["steam-engine"]=1,["boiler"]=1,
     ["gun-turret"]=4,["firearm-magazine"]=400,
  },
  platforms = {
       loot_items = internal_loot(),
       save_triggers = {
          "warp-ground-platform-2",
          "warp-ground-platform-3",
          "warp-ground-platform-4",
          "warp-ground-platform-5",
          "warp-ground-platform-6",
          "warp-ground-platform-7",
          "warp-ground-platform-8",
          "warp-end-prepare",
       },
       position = {
          x = {min=32*4,max=32*8},
          y = {min=32*4,max=32*8}
       },
       weapons = {
          {name="gun-turret",fluid=false,ammo={ name = "firearm-magazine", count = 10 }},
          {name="flamethrower-turret",fluid=true,ammo={ name = "heavy-oil", amount = 100 }}
       },
       spawn_chance = 0.5,
       spawn_timer = 60*60*8,
       tresholds = {0,0.15,0.5,0.9},
       minimum_entities = 60,
       duration = 5*60*60,
       items = {min=10,max=50,chance=0.75,scale=25}
  },
  surfaces = {
     -- Define Surfaces that will be used and sorted
     -- First set is unlocked at the start of the game
     {
        names = mysplit(settings.startup["warptorio_planets-t1"].value,","),
        triggers = {},
        science = {},
        count = 0
     },
     -- Second set is triggered at trigger_research
     {
        names = mysplit(settings.startup["warptorio_planets-t2"].value,","),
        triggers = mysplit(settings.startup["warptorio_planets-t2"].value,",","planet-discovery-"),
        science = SciencePacks({red=1,green=1}),
        count = 200,
     },
     -- Third trigger is triggered at trigger_space
     {
        names = mysplit(settings.startup["warptorio_planets-t3"].value,","),
        triggers = mysplit(settings.startup["warptorio_planets-t3"].value,",","planet-discovery-"),
        science = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1,vulcanus=1,fulgora=1,gleba=1}),
        count = 500
     },
     -- Last trigger is triggered at trigger_end
     {
        names = mysplit(settings.startup["warptorio_planets-t4"].value,","),
        triggers = mysplit(settings.startup["warptorio_planets-t4"].value,",","planet-discovery-"),
        science = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1,vulcanus=1,fulgora=1,gleba=1,aquilo=1,final=1}),
        count = 1000,
     }
  },
  space = {
     time_per_warp = 0.75,
     transition = settings.startup["warptorio_space-transition"].value,
     transition_spawn_timer = 10,
     transition_spawn_amount = 5,
     speed = 0.05,
     edge_chance = 0.75,
     multiplier = 0.5,
     -- not used
     asteroid_chance = 5000,
     base_time = 20,
     trigger_factory_level = 2,
     tresholds = {0,0.10,0.4,0.7},
     asteroids = {
        {"small-carbonic-asteroid","small-metallic-asteroid","small-oxide-asteroid"},
        {"medium-carbonic-asteroid","medium-metallic-asteroid","medium-oxide-asteroid"},
        {"big-carbonic-asteroid","big-metallic-asteroid","big-oxide-asteroid"},
        {"huge-carbonic-asteroid","huge-metallic-asteroid","huge-oxide-asteroid"},
        {"huge-carbonic-asteroid","huge-metallic-asteroid","huge-oxide-asteroid"},
        -- Promethium asterids should be handled differently
     }
  },
  tiles = {
     ground = "warp_tile_world",
     factory = "warp_tile_platform"
  },
  factory = {
    levels={
	    [1]={width=10,height=10,arm=6},
	    [2]={width=24,height=24,arm=6},
	    [3]={width=40,height=40,arm=9},
	    [4]={width=56,height=56,arm=12},
	    [5]={width=72,height=72,arm=15},
	    [6]={width=90,height=90,arm=18},
	    [7]={width=120,height=120,arm=24},
    },
    shape = "cross"
  },
  garden = {
    platform = {
       width = 31,
       height = 2 + 31 *2
    },
    yumako={
        parts = {
            -- Parts that are combined into garden in correct order
            {width=31,height=31,tile="refined-concrete"},
            -- Water has to be generated in waves, to prevent deleting buildings
            {width=2,height=27,y=0,x=-12,tile="water"},
            {width=2,height=27,y=0,x=13,tile="water"},
            {width=27,height=2,y=-12,x=0,tile="water"},
            {width=27,height=2,y=13,x=0,tile="water"},
            {width=23,height=23,tile="refined-concrete"},
            {width=21,height=21,tile="artificial-yumako-soil"},
            {width=3,height=3,tile="refined-concrete"}
        },
        y=15,
        x=31,
        offset=2
    },
    jellynut={
        parts = {
            -- Parts that are combined into garden in correct order
            {width=31,height=31,tile="refined-concrete"},
            -- Water has to be generated in waves, to prevent deleting buildings
            {width=2,height=27,y=0,x=-12,tile="water"},
            {width=2,height=27,y=0,x=13,tile="water"},
            {width=27,height=2,y=-12,x=0,tile="water"},
            {width=27,height=2,y=13,x=0,tile="water"},
            {width=23,height=23,tile="refined-concrete"},
            {width=21,height=21,tile="artificial-jellynut-soil"},
            {width=3,height=3,tile="refined-concrete"}
        },
        y=-15,
        x=31,
        offset=-3
    }
  },
  time = {
    round = 60*10,
    upgrade = 60*10,
    warp_out = 60,
    grace_period = 3*60,
    limit = 20*60,
    extra_transition_time = 1,
    add_per_jump=settings.startup["warptorio_time-per-jump"].value,
    clicks_to_teleport = settings.startup["warptorio_players"].value
  },
  biter = {
    entity_type = {
       default = {
         --[[ For now removing warp enemies so I can remake them
        {"warp-entity-bullet","warp-entity-laser"},
        {"warp-entity-bullet","warp-entity-laser"},
        {"warp-entity-bullet-2","warp-entity-laser-2"},
            {"warp-entity-bullet-3","warp-entity-laser-3"}
         ]]
          {"small-biter","small-spitter","small-wriggler-pentapod"},
          {"medium-biter","medium-spitter","big-wriggler-pentapod"},
          {"big-biter","big-spitter","small-strafer-pentapod"},
          {"behemoth-biter","behemoth-spitter","medium-strafer-pentapod"},
      },
      nauvis = {
        {"small-biter","small-spitter"},
        {"medium-biter","medium-spitter"},
        {"big-biter","big-spitter"},
        {"behemoth-biter","behemoth-spitter"}
      },
      --nauvis = {"warp-biter","warp-spitter"},
      --vulcanus = {"warp-demolisher"}
      boss = {
        {"warp-demolisher"},
        {"medium-strafer-pentapod","medium-stomper-pentapod"},
        {"big-strafer-pentapod","big-stomper-pentapod"},
        {"big-strafer-pentapod","big-stomper-pentapod", "small-demolisher"},
      }
    },
    tresholds = {0,0.15,0.5,0.9},
    extra_time_planet = {},
    extra_time_amount = 2*60,
    quality_step = settings.startup["warptorio_quality-step"].value,
    quality = {
      "normal",
      "uncommon",
      "rare",
      "epic",
      "legendary",
    },
    quality_time = 3*60,
    wave_change_index = 20,
    wave_change_chance = 0.3,
    wave_change_max = 40,
    wave_amount = settings.startup["warptorio_wave-amount"].value,
    wave_increase = settings.startup["warptorio_wave-increase"].value,
    amount = 5,
    time = settings.startup["warptorio_wave-time"].value,
    change = settings.startup["warptorio_wave-change"].value,
    min = 15,
    radius = 8,
    max_bosses = 7,
    evolution = {
       base = 0,
       researches = {
          {name = "warp-ground-platform-3", factor = 0.1},
          {name = "warp-factory-platform-3", factor = 0.2},
          {name = "warp-ground-platform-4", factor = 0.3},
          {name = "warp-factory-platform-4", factor = 0.4},
          {name = "warp-ground-platform-5", factor = 0.51},
          {name = "warp-factory-platform-5", factor = 0.6},
          {name = "warp-ground-platform-6", factor = 0.7},
          {name = "warp-factory-platform-6", factor = 0.8},
          {name = "warp-ground-platform-7", factor = 0.91},
          {name = "warp-end-prepare", factor = 1.0},
       }
    },
  },
  polution = {
    time = settings.startup["warptorio_warpout-time"].value,
    amount = 1
  },
  starter = settings.startup["warptorio_starter"].value,
  reset_recipe = settings.startup["warptorio_reset-recipe"].value,
  planet_timer = 30,
  stuck_in_space_chance = settings.startup["warptorio_stuck-in-space-chance"].value,
  going_home_chance = settings.startup["warptorio_going-home-chance"].value,
  go_home_chance = 0.0,
  allow_random_position = settings.startup["warptorio_allow-random-position"].value,
  random_position_offset = 3,
  next_planet_text = settings.startup["warptorio_next-planet-text"].value,
  next_planet_sound = settings.startup["warptorio_next-planet-sound"].value,
  trigger_research = "chemical-science-pack",
  trigger_wave = "logistic-science-pack",
  trigger_space = "space-science-pack",
  trigger_end = "promethium-science-pack",
  blocked_planets = {"nauvis","void"},
  dmg_research = true,
  -- This character - has to be escaped with %-
  techs = {
     ground = "warp%-ground%-platform",
     factory = "warp%-factory%-platform",
     biochamber = "warp%-biochamber%-platform",
     container_left = "warp%-container%-left",
     belt = "warp%-belt",
     power = "warp%-power",
     time = "warp%-time",
     win = "warp%-end%-win"
  },
  gui = {
     holder = "WarptorioGUI",
     label = "WarpLabel",
     value = "WarpValue",
     data = {
        {
           name = "time",
           label = {"warptorio.gui-warp-time"},
           value = "01:00/60:00"
        },
        {
           name = "amount",
           label = {"warptorio.gui-warp-amount"},
           value = "400"
        },
        {
           name = "wave-amount",
           label = {"warptorio.gui-wave-amount"},
           value = "30"
        },
        {
           name = "wave-time",
           label = {"warptorio.gui-wave-time"},
           value = "1:30"
        },
        {
           name = "warpout-time",
           label = {"warptorio.gui-warpout-time"},
           value = "0:45"
        },
        {
           name = "next-planet",
           label = {"warptorio.gui-next-planet"},
           value = "Unknown"
        },
     }
  }
}

local_settings.factory.levels = warp_sizes[settings.startup["warptorio_size-difficulty"].value].factory
local_settings.floor.levels = warp_sizes[settings.startup["warptorio_size-difficulty"].value].floor
local_settings.factory.shape = settings.startup["warptorio_factory-shape"].value

if not script then return local_settings end

for name, version in pairs(script.active_mods) do
  if name == "Cold_biters" then
    local_settings.biter.entity_type["aquilo"] = {
      {"small-cold-spitter","small-cold-biter"},
      {"medium-cold-spitter","medium-cold-biter"},
      {"big-cold-spitter","big-cold-biter"},
      {"behemoth-cold-spitter","behemoth-cold-biter"},
    }
    -- Increase ods by doing this multiple times
    local prefix = "maf-boss-frost"
    local variants = {"biter","spitter"}
    local amount = 4
    --for _=1,2 do
    for i=1,amount do
       for _,var in ipairs(variants) do
          table.insert(local_settings.biter.entity_type["boss"][i],prefix.."-"..var.."-"..i)
       end
    end
    --end
    --local_settings.biter.max_bosses = 1
  end
  if name == "Explosive_biters" then
    local_settings.biter.entity_type["vulcanus"] = {
      {"small-explosive-spitter","small-explosive-biter"},
      {"medium-explosive-spitter","medium-explosive-biter"},
      {"big-explosive-spitter","big-explosive-biter"},
      {"behemoth-explosive-spitter","behemoth-explosive-biter"},
    }
    -- Increase ods by doing this multiple times
    local prefix = "maf-boss-explosive"
    local variants = {"biter","spitter"}
    local amount = 4
    --for _=1,2 do
    for i=1,amount do
       for _,var in ipairs(variants) do
          table.insert(local_settings.biter.entity_type["boss"][i],prefix.."-"..var.."-"..i)
       end
    end
    --local_settings.biter.max_bosses = 1
  end
  if name == "Electric_flying_enemies" then
    local_settings.biter.entity_type["fulgora"] = {
      {"flying-electric-unit-1","walking-electric-unit-1"},
      {"flying-electric-unit-2","walking-electric-unit-2"},
      {"flying-electric-unit-3","walking-electric-unit-3"},
      {"flying-electric-unit-4","walking-electric-unit-4"},
    }
    local_settings.dmg_research = false
  end
  if name == "Toxic_biters" then
    local_settings.biter.entity_type["gleba"] = {
      {"small-toxic-spitter","small-toxic-biter"},
      {"medium-toxic-spitter","medium-toxic-biter"},
      {"big-toxic-spitter","big-toxic-biter"},
      {"behemoth-toxic-spitter","behemoth-toxic-biter"},
    }
    -- Increase ods by doing this multiple times
    local prefix = "maf-boss-toxic"
    local variants = {"biter","spitter"}
    local amount = 4
    --for _=1,2 do
    for i=1,amount do
       for _,var in ipairs(variants) do
          table.insert(local_settings.biter.entity_type["boss"][i],prefix.."-"..var.."-"..i)
       end
    end
    --local_settings.biter.max_bosses = 1
  end
  if name == "exotic-space-industries" then
    local_settings.biter.trigger_research = "ei-electricity-age"
    local_settings.biter.trigger_wave = "ei-steam-age"
  end
end

return local_settings
