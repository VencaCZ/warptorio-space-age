local warp_settings = require("internal_settings")

data.raw["technology"]["rocket-silo"].prerequisites = {"promethium-science-pack"}
data.raw["technology"]["rocket-silo"].unit = {
  count_formula = "1",
  ingredients =
  {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"utility-science-pack", 1},
    {"space-science-pack", 1},
    --{"criogenic-science-pack", 1},
  },
  time = 60
}
data.raw["technology"]["rocket-silo"].hidden = true
data.raw["technology"]["space-platform-thruster"].hidden = true

data.raw["technology"]["space-science-pack"].prerequisites = {"processing-unit","low-density-structure"}
data.raw["technology"]["space-science-pack"].research_trigger = nil
data.raw["technology"]["space-science-pack"].unit = {
  count_formula = "100",
  ingredients =
  {
    {"metallurgic-science-pack", 1},
    {"agricultural-science-pack", 1},
    {"chemical-science-pack", 1},
    {"electromagnetic-science-pack", 1},
  },
  time = 60
}

-- Change landfill
local landfill = data.raw["technology"]["landfill"]
if landfill then
  landfill.unit = nil
  landfill.research_trigger = {
    type = "craft-item",
    item = "nutrients",
    count = 50
  }
end

-- improve researches
data.raw["technology"]["artillery-shell-damage-1"].effects = {
   {
      ammo_category = "artillery-shell",
      modifier = 1.0,
      type = "ammo-damage"
   }
}

-- Warptorio technologies
local warp_platform_base = table.deepcopy(data.raw["technology"]["space-platform"])

local function mysplit (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

local function istable(t) return type(t)=="table" end
local function rgb(r,g,b,a) a=a or 255 return {r=r/255,g=g/255,b=b/255,a=a/255} end
function table.deepmerge(s,t) for k,v in pairs(t)do if(istable(v) and s[k] and istable(s[k]))then table.deepmerge(s[k],v) else s[k]=v end end end
function table.merge(s,t) local x={} for k,v in pairs(s)do x[k]=v end for k,v in pairs(t)do x[k]=v end return x end
local techPacks={
   red="automation-science-pack",green="logistic-science-pack",blue="chemical-science-pack",
   black="military-science-pack",	purple="production-science-pack",yellow="utility-science-pack",
   white="space-science-pack",vulcanus="metallurgic-science-pack",gleba="agricultural-science-pack",
   aquilo="cryogenic-science-pack",fulgora="electromagnetic-science-pack",final="promethium-science-pack"}
if mods["exotic-space-industries"] then
   techPacks={red="ei-dark-age-tech",green="ei-steam-age-tech",blue="ei-electricity-age-tech",
              black="military-science-pack",	purple="ei-computer-age-tech",
              yellow="ei-computer-age-tech",
              white="ei-quantum-age",vulcanus="metallurgic-science-pack",gleba="agricultural-science-pack",
              aquilo="cryogenic-science-pack",fulgora="electromagnetic-science-pack",final="promethium-science-pack"}
end
local multiplier = settings.startup["warptorio_research-multiplier"].value
local function SciencePacks(x) local t={} for k,v in pairs(x)do table.insert(t,{techPacks[k],v}) end return t end
local function ExtendTech(t,d,s)
   local x=table.merge(t,d)
   if(s)then
      x.unit.ingredients=SciencePacks(s)
   end
   if x.unit.count then
      x.unit.count = x.unit.count*multiplier
   end
   data:extend{x}
   return x
end

local triggers = {
   "none", warp_settings.trigger_research, warp_settings.trigger_space, warp_settings.trigger_end }
local names = {}
for i=2,#triggers do
   local v = triggers[i]
   for _,b in ipairs(warp_settings.surfaces[i].triggers) do
      local t = table.deepcopy(data.raw["technology"][b])
      table.insert(names,b)
      local packs = warp_settings.surfaces[i].science
      local count = warp_settings.surfaces[i].count
      ExtendTech(
         t,
         {
            name=b,
            unit={count=count,ingredients = packs,time=60},
            prerequisites={v}
         }
      )
   end
   --[[if warp_settings.surfaces[i].extra then
      for research_name,_ in pairs(data.raw["technology"]) do
         local parts = mysplit(i,"-")
         if #parts == 3 and parts[1] == "planet" and parts[2] == "discovery" then
            for _,saved_name in ipairs(names) do
               if saved_name == research_name then
                  goto continue
               end
            end
         end

         local t = table.deepcopy(data.raw["technology"][research_name])
         local packs = warp_settings.surfaces[i].science
         local count = warp_settings.surfaces[i].count
         ExtendTech(
            t,
            {
               name=i,
               unit={count=count,ingredients = packs,time=60},
               prerequisites={v}
            }
         )

         ::continue::
      end
      end]]
end

local t = table.deepcopy(data.raw["technology"]["rocket-silo"])
t.icons = {{icon="__warptorio-space-age__/graphics/destinations/asteroid.png",icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{
  name="warp-end-prepare",
  unit={count=5000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1,vulcanus=1,fulgora=1,aquilo=1,gleba=1}),time=120},
  prerequisites={"warp-ground-platform-7","warp-factory-platform-6","warp-time-4"},
  effects={{recipe = "warp-promethium",type = "unlock-recipe"}}})
local t = table.deepcopy(data.raw["technology"]["rocket-silo"])
t.icons = {{icon="__warptorio-space-age__/graphics/locations/black-hole.png",icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-end-win",unit={count=25000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1,vulcanus=1,fulgora=1,aquilo=1,gleba=1,final=1}),time=120}, prerequisites={"warp-end-prepare"},effects={}})

local t = table.deepcopy(data.raw["technology"]["rocket-silo"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
local prerequisites = { "automation" }
if mods["exotic-space-industries"] then
   prerequisites = { "ei-burner-assembler" }
end
ExtendTech(t,{name="warp-ground-platform-1",unit={count=25,ingredients = SciencePacks({red=1}),time=60}, prerequisites=prerequisites,effects={}})
ExtendTech(t,{name="warp-ground-platform-2",unit={count=100,ingredients = SciencePacks({red=1}),time=60}, prerequisites={"warp-ground-platform-1"},effects={}})
ExtendTech(t,{name="warp-ground-platform-3",unit={count=100,ingredients = SciencePacks({red=1,green=1}),time=60}, prerequisites={"warp-ground-platform-2"},effects={}})
ExtendTech(t,{name="warp-ground-platform-4",unit={count=250,ingredients = SciencePacks({red=1,green=1}),time=60}, prerequisites={"warp-ground-platform-3"},effects={}})
ExtendTech(t,{name="warp-ground-platform-5",unit={count=500,ingredients = SciencePacks({red=1,green=1,blue=1}),time=60}, prerequisites={"warp-ground-platform-4","warp-factory-platform-3"},effects={}})
ExtendTech(t,{name="warp-ground-platform-6",unit={count=1000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1}),time=60}, prerequisites={"warp-ground-platform-5"},effects={}})
ExtendTech(t,{name="warp-ground-platform-7",unit={count=5000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1}),time=60}, prerequisites={"warp-ground-platform-6"},effects={}})
ExtendTech(t,{name="warp-ground-platform-8",unit={count=10000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1}),time=60}, prerequisites={"warp-ground-platform-7"},effects={}})

local t = table.deepcopy(data.raw["technology"]["rocket-silo"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =true
t.localised_name = nil
local weapon_effects = {
  {
    ammo_category = "laser",
    modifier = 0.5,
    type = "ammo-damage"
  },
  {
    ammo_category = "laser",
    modifier = 0.5,
    type = "gun-speed"
  },
  {
    ammo_category = "bullet",
    modifier = 0.5,
    type = "ammo-damage"
  },
  {
    modifier = 0.5,
    turret_id = "gun-turret",
    type = "turret-attack"
  },
  {
    ammo_category = "shotgun-shell",
    modifier = 0.5,
    type = "ammo-damage"
  },
  {
    ammo_category = "bullet",
    modifier = 0.5,
    type = "gun-speed"
  },
  {
    ammo_category = "shotgun-shell",
    modifier = 0.5,
    type = "gun-speed"
  }
}
ExtendTech(t,{name="warp-weapons-1",unit={count=1,ingredients = SciencePacks({red=1}),time=120}, prerequisites={},effects=weapon_effects})
ExtendTech(t,{name="warp-weapons-2",unit={count=1,ingredients = SciencePacks({red=1}),time=120}, prerequisites={},effects=weapon_effects})
ExtendTech(t,{name="warp-weapons-3",unit={count=1,ingredients = SciencePacks({red=1}),time=120}, prerequisites={},effects=weapon_effects})
ExtendTech(t,{name="warp-weapons-4",unit={count=1,ingredients = SciencePacks({red=1}),time=120}, prerequisites={},effects=weapon_effects})

local t = table.deepcopy(data.raw["technology"]["automation"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-factory-platform-1",unit={count=25,ingredients = SciencePacks({red=1}),time=60}, prerequisites={"warp-ground-platform-1"},effects={}})
ExtendTech(t,{name="warp-factory-platform-2",unit={count=100,ingredients = SciencePacks({red=1,green=1}),time=60}, prerequisites={"warp-factory-platform-1"},effects={}})
ExtendTech(t,{name="warp-factory-platform-3",unit={count=200,ingredients = SciencePacks({red=1,green=1,gleba=1}),time=60}, prerequisites={"warp-factory-platform-2"},effects={}})
ExtendTech(t,{name="warp-factory-platform-4",unit={count=500,ingredients = SciencePacks({red=1,green=1,fulgora=1}),time=60}, prerequisites={"warp-factory-platform-3"},effects={}})
ExtendTech(t,{name="warp-factory-platform-5",unit={count=1000,ingredients = SciencePacks({red=1,green=1,vulcanus=1}),time=60}, prerequisites={"warp-factory-platform-4"},effects={}})
ExtendTech(t,{name="warp-factory-platform-6",unit={count=2000,ingredients = SciencePacks({red=1,green=1,aquilo=1}),time=60}, prerequisites={"warp-factory-platform-5"},effects={}})
ExtendTech(t,{name="warp-factory-platform-7",unit={count=10000,ingredients = SciencePacks({vulcanus=1,fulgora=1,aquilo=1,gleba=1}),time=60}, prerequisites={"warp-factory-platform-6"},effects={}})

local t = table.deepcopy(data.raw["technology"]["space-platform"])
t.research_trigger = nil
t.effects = {
   {
      recipe = "warp-asteroid-chest",
      type = "unlock-recipe"
   },
   {
      recipe = "crusher",
      type = "unlock-recipe"
   },
   {
      recipe = "metallic-asteroid-crushing",
      type = "unlock-recipe"
   },
   {
      recipe = "carbonic-asteroid-crushing",
      type = "unlock-recipe"
   },
   {
      recipe = "oxide-asteroid-crushing",
      type = "unlock-recipe"
   },
}
ExtendTech(t,{name="space-platform",unit={count=500,ingredients = SciencePacks({red=1,green=1,gleba=1,blue=1}),time=60}, prerequisites={"warp-factory-platform-3"}})

local t = table.deepcopy(data.raw["technology"]["biochamber"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
t.research_trigger = nil
ExtendTech(t,{name="warp-biochamber-platform-1",unit={count=500,ingredients = SciencePacks({red=1,green=1,gleba=1,blue=1}),time=60}, prerequisites={"warp-ground-platform-3","warp-water"},effects={}})
ExtendTech(t,{name="warp-biochamber-platform-2",unit={count=1000,ingredients = SciencePacks({red=1,green=1,gleba=1,blue=1}),time=60}, prerequisites={"warp-biochamber-platform-1"},effects={}})
ExtendTech(t,{name="warp-biochamber-platform-3",unit={count=5000,ingredients = SciencePacks({red=1,green=1,gleba=1,blue=1,white=1}),time=60}, prerequisites={"warp-biochamber-platform-2"},effects={}})
ExtendTech(t,{
              name="warp-biochamber-platform-4",
              unit={count_formula="(10000*(L-3)*(L-3))",time=30},
              max_level="infinite",
              prerequisites={"warp-biochamber-platform-3","warp-end-prepare"},
              effects={}
             },
           {red=1,green=1,blue=1,purple=1,yellow=1,white=1,vulcanus=1,fulgora=1,aquilo=1,gleba=1,final=1}
)

local t = table.deepcopy(data.raw["technology"]["logistics"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-belt-1",unit={count=30,ingredients = SciencePacks({red=1}),time=60}, prerequisites={"warp-ground-platform-1"},effects={}})

local t = table.deepcopy(data.raw["technology"]["logistics-2"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-belt-2",unit={count=300,ingredients = SciencePacks({red=1,green=1}),time=60}, prerequisites={"warp-ground-platform-2","warp-belt-1"},effects={}})

local t = table.deepcopy(data.raw["technology"]["logistics-3"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-belt-3",unit={count=600,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1}),time=60}, prerequisites={"warp-ground-platform-4","warp-belt-2"},effects={}})

local t = table.deepcopy(data.raw["technology"]["turbo-transport-belt"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-belt-4",unit={count=1200,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1}),time=60}, prerequisites={"warp-ground-platform-6","warp-belt-3"},effects={}})

local t = table.deepcopy(data.raw["technology"]["radar"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-time-1",unit={count=100,ingredients = SciencePacks({red=1,green=1}),time=60}, prerequisites={"warp-factory-platform-1"},effects={}})
ExtendTech(t,{name="warp-time-2",unit={count=250,ingredients = SciencePacks({gleba=1}),time=60}, prerequisites={"warp-factory-platform-2","warp-belt-1","warp-time-1"},effects={}})
ExtendTech(t,{name="warp-time-3",unit={count=500,ingredients = SciencePacks({fulgora=1}),time=60}, prerequisites={"warp-factory-platform-4","warp-belt-2","warp-time-2"},effects={}})
ExtendTech(t,{name="warp-time-4",unit={count=1000,ingredients = SciencePacks({vulcanus=1}),time=60}, prerequisites={"warp-factory-platform-6","warp-belt-3","warp-time-3"},effects={}})
ExtendTech(t,{name="warp-time-5",unit={count=1000,ingredients = SciencePacks({white=1}),time=60}, prerequisites={"warp-factory-platform-6","warp-belt-3","warp-time-4"},effects={}})

local t = table.deepcopy(data.raw["technology"]["mining-productivity-1"])
t.icons[1].tint={r=0.3,g=0.3,b=1,a=1}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warptorio-mining-prod-1",unit={count_formula="20*L",time=30},max_level=5,prerequisites={}}, {red=1})
ExtendTech(t,{name="warptorio-mining-prod-6",unit={count_formula="(20*L)-50",time=30},max_level=10,prerequisites={"warptorio-mining-prod-1","logistic-science-pack"}}, {red=2,green=1})
ExtendTech(t,{name="warptorio-mining-prod-11",unit={count_formula="(20*L)-100",time=30},max_level=15,prerequisites={"warptorio-mining-prod-6","chemical-science-pack"}}, {red=2,green=2,blue=1} )
ExtendTech(t,{name="warptorio-mining-prod-16",unit={count_formula="(20*L)-150",time=30},max_level=20,prerequisites={"warptorio-mining-prod-11","production-science-pack"}}, {red=3,green=3,blue=1,purple=1} )
ExtendTech(t,{name="warptorio-mining-prod-21",unit={count_formula="(20*L)-200",time=30},max_level=25,prerequisites={"warptorio-mining-prod-16","utility-science-pack"}}, {red=3,green=3,blue=2,purple=1,yellow=1} )

local t = table.deepcopy(data.raw["technology"]["steel-axe"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.research_trigger = nil
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warptorio-axe-speed-1",unit={count_formula="50*L",time=30},prerequisites={"steel-axe","warp-ground-platform-1"},max_level=4}, {red=1})

local t = table.deepcopy(data.raw["technology"]["toolbelt-equipment"])
t.localised_name = nil
t.icons[1].tint={r=0.3,g=0.3,b=1,a=1}
t.effects={ {type="character-inventory-slots-bonus",modifier=10} }
ExtendTech(t,{name="warptorio-character-inventory",unit={count_formula="200*L",time=30},prerequisites={"warp-factory-platform-1"},max_level=5}, {red=1})

local t = table.deepcopy(data.raw["technology"]["logistic-system"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
--ExtendTech(t,{name="warp-container-right",unit={count=100,ingredients = SciencePacks({gleba=1}),time=60}, prerequisites={"warp-factory-platform-3"},effects={}})
ExtendTech(t,{name="warp-container-left",unit={count=100,ingredients = SciencePacks({blue=1}),time=60}, prerequisites={"warp-ground-platform-5"},effects={}})

local t = table.deepcopy(data.raw["technology"]["fluid-handling"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
--ExtendTech(t,{name="warp-container-right",unit={count=100,ingredients = SciencePacks({gleba=1}),time=60}, prerequisites={"warp-factory-platform-3"},effects={}})
ExtendTech(t,{name="warp-water",unit={count=250,ingredients = SciencePacks({blue=1}),time=60}, prerequisites={"warp-ground-platform-5"},effects={{recipe = "ice-melting",type = "unlock-recipe"}}})

local t = table.deepcopy(data.raw["technology"]["electric-energy-accumulators"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warp-power-1",unit={count=1000,ingredients = SciencePacks({red=1,green=1,blue=1,purple=1,yellow=1,white=1}),time=60}, prerequisites={"warp-ground-platform-6"},effects={}})
ExtendTech(t,
    { name = "warp-power-2", unit = { count = 5000, ingredients = SciencePacks({ vulcanus = 1, fulgora = 1, aquilo = 1, gleba = 1 }), time = 60 }, prerequisites = { "warp-ground-platform-7", "warp-power-1" }, effects = {} })

local t = table.deepcopy(data.raw["technology"]["repair-pack"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,{name="warptorio-platform-repair",unit={count_formula="100*L*L",time=60},prerequisites={"warp-ground-platform-1"},max_level="infinite"}, {red=1})

local t = table.deepcopy(data.raw["technology"]["railway"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,
           { name = "warp-train", unit = { count = 1000, ingredients = SciencePacks({ blue = 1, fulgora = 1, gleba = 1 }), time = 60 }, prerequisites = { "warp-ground-platform-5", "warp-factory-platform-4" }, effects = {} })

local t = table.deepcopy(data.raw["technology"]["circuit-network"])
t.icons = {{icon=t.icon,tint={r=0.3,g=0.3,b=1,a=1},icon_size=256,}}
t.hidden =false
t.localised_name = nil
ExtendTech(t,
           { name = "warp-circuit-network", unit = { count = 1000, ingredients = SciencePacks({ red = 1, green = 1, }), time = 30 }, prerequisites = { "warp-ground-platform-3", "warp-factory-platform-2" }, effects = {  {
    type  = "unlock-recipe",
    recipe = "warp-constant-combinator"
  }} })
