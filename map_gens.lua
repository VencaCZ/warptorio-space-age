local base = require("map_gens_base")

local planets = require("planets.init")

local size = {
   0,
   1/2,
   1/math.sqrt(2),
   1,
   2,
   3,
   4,
   5,
   6
}

local example_settings = {
   resources = {
      frequency = 1,
      size = 1,
      richness = 1,
   },
   world = {
      decorative = {
         frequency = 1,
         size = 1,
         richness = 1,
      },
      entity = {
         frequency = 1,
         size = 1,
         richness = 1,
      },
      tile = {
         frequency = 1,
         size = 1,
         richness = 1,
      },
   },
   starting_area = 1,
   no_enemies_mode = false,
   enemy = {
      frequency = 1,
      size = 1,
      richness = 1,
   }
}

local enemy_settings = {
   "enemy-base",
   "gleba-enemy-base",
   "electric_enemies",
   "hot_enemy_base",
   "frost_enemy_base",
   "toxic_enemy_base"
}

local function deepcopy(o, seen)
  seen = seen or {}
  if o == nil then return nil end
  if seen[o] then return seen[o] end

  local no
  if type(o) == 'table' then
    no = {}
    seen[o] = no

    for k, v in next, o, nil do
      no[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    setmetatable(no, deepcopy(getmetatable(o), seen))
  else -- number, string, boolean, etc
    no = o
  end
  return no
end

local function single_number(number)
   if number < 1 then number = 1 end
   if number > #size  then number = #size end
   return number
end

local function copyValues(a, b)
    for key, value in pairs(a) do
        if b[key] ~= nil then  -- key exists in b
            if type(value) ~= "table" then
                b[key] = value
            else
                -- both a[key] and b[key] are tables
                if type(b[key]) == "table" then
                    copyValues(value, b[key])
                end
            end
        end
    end
end

local function numbers_to_values(settings_table)
   return {
      frequency = size[single_number(settings_table["frequency"])],
      size = size[single_number(settings_table["size"])],
      richness = size[single_number(settings_table["frequency"])],
   }
end

local function fill_planet(name,settings,base_settings)
   if settings == "normal" then
      return base_settings
   end
   local planet = deepcopy(base_settings)
   local replacer = planets[name.."_"..settings]
   if not replacer or not planet then
      game.print("Could not find "..name.."_"..settings)
      return base_settings
   end

   copyValues(replacer,planet)
   
   return planet
end


return {
   variant_list = {
      "rich",
      "normal",
      "dwarf",
      "dangerous",
      "ribon"
   },
   planets = planets,
   functions = {
      generate = fill_planet
   }
}
