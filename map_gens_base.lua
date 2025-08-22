return {
   aquilo = {
        autoplace_controls = {
          aquilo_crude_oil = {},
          fluorine_vent = {},
          lithium_brine = {}
        },
        autoplace_settings = {
          decorative = {
            settings = {
              ["aqulio-ice-decal-blue"] = {},
              ["aqulio-snowy-decal"] = {},
              ["floating-iceberg-large"] = {},
              ["floating-iceberg-small"] = {},
              ["lithium-iceberg-medium"] = {},
              ["lithium-iceberg-small"] = {},
              ["lithium-iceberg-tiny"] = {},
              ["snow-drift-decal"] = {}
            }
          },
          entity = {
            settings = {
              ["crude-oil"] = {},
              ["fluorine-vent"] = {},
              ["lithium-brine"] = {},
              ["lithium-iceberg-big"] = {},
              ["lithium-iceberg-huge"] = {}
            }
          },
          tile = {
            settings = {
              ["ammoniacal-ocean"] = {},
              ["ammoniacal-ocean-2"] = {},
              ["brash-ice"] = {},
              ["ice-rough"] = {},
              ["ice-smooth"] = {},
              ["snow-crests"] = {},
              ["snow-flat"] = {},
              ["snow-lumpy"] = {},
              ["snow-patchy"] = {}
            }
          }
        },
        property_expression_names = {
          aux = "aquilo_aux",
          cliff_elevation = "cliff_elevation_from_elevation",
          cliffiness = "cliffiness_basic",
          elevation = "aquilo_elevation",
          ["entity:crude-oil:probability"] = "aquilo_crude_oil_probability",
          ["entity:crude-oil:richness"] = "aquilo_crude_oil_richness",
          moisture = "moisture_basic",
          temperature = "aquilo_temperature"
        }
   },
   fulgora = {
        autoplace_controls = {
          fulgora_cliff = {},
          fulgora_islands = {},
          scrap = {}
        },
        autoplace_settings = {
          decorative = {
            settings = {
              ["fulgoran-gravewort"] = {},
              ["fulgoran-ruin-tiny"] = {},
              ["medium-fulgora-rock"] = {},
              ["small-fulgora-rock"] = {},
              ["tiny-fulgora-rock"] = {},
              ["urchin-cactus"] = {}
            }
          },
          entity = {
            settings = {
              ["big-fulgora-rock"] = {},
              ["fulgoran-ruin-attractor"] = {},
              ["fulgoran-ruin-big"] = {},
              ["fulgoran-ruin-colossal"] = {},
              ["fulgoran-ruin-huge"] = {},
              ["fulgoran-ruin-medium"] = {},
              ["fulgoran-ruin-small"] = {},
              ["fulgoran-ruin-stonehenge"] = {},
              ["fulgoran-ruin-vault"] = {},
              fulgurite = {},
              scrap = {}
            }
          },
          tile = {
            settings = {
              ["fulgoran-conduit"] = {},
              ["fulgoran-dunes"] = {},
              ["fulgoran-dust"] = {},
              ["fulgoran-machinery"] = {},
              ["fulgoran-paving"] = {},
              ["fulgoran-rock"] = {},
              ["fulgoran-sand"] = {},
              ["fulgoran-walls"] = {},
              ["oil-ocean-deep"] = {},
              ["oil-ocean-shallow"] = {}
            }
          }
        },
        cliff_settings = {
          cliff_elevation_0 = 80,
          cliff_elevation_interval = 40,
          cliff_smoothing = 0,
          control = "fulgora_cliff",
          name = "cliff-fulgora",
          richness = 0.95
        },
        property_expression_names = {
          aux = "aux_basic",
          cliff_elevation = "cliff_elevation_from_elevation",
          cliffiness = "fulgora_cliffiness",
          elevation = "fulgora_elevation",
          moisture = "moisture_basic",
          temperature = "temperature_basic"
        }
   },
   gleba = {
        autoplace_controls = {
          gleba_cliff = {},
          gleba_enemy_base = {},
          gleba_plants = {},
          gleba_stone = {},
          gleba_water = {}
        },
        autoplace_settings = {
          decorative = {
            settings = {
              ["barnacles-decal"] = {},
              ["black-sceptre"] = {},
              ["blood-grape"] = {},
              ["blood-grape-vibrant"] = {},
              brambles = {},
              ["brown-cup"] = {},
              ["coral-land"] = {},
              ["coral-stunted"] = {},
              ["coral-stunted-grey"] = {},
              ["coral-water"] = {},
              ["cracked-mud-decal"] = {},
              ["cream-nerve-roots-veins-dense"] = {},
              ["cream-nerve-roots-veins-sparse"] = {},
              ["curly-roots-orange"] = {},
              ["dark-mud-decal"] = {},
              ["fuchsia-pita"] = {},
              ["green-bush-mini"] = {},
              ["green-carpet-grass"] = {},
              ["green-croton"] = {},
              ["green-cup"] = {},
              ["green-hairy-grass"] = {},
              ["green-lettuce-lichen-1x1"] = {},
              ["green-lettuce-lichen-3x3"] = {},
              ["green-lettuce-lichen-6x6"] = {},
              ["green-lettuce-lichen-water-1x1"] = {},
              ["green-lettuce-lichen-water-3x3"] = {},
              ["green-lettuce-lichen-water-6x6"] = {},
              ["green-pita"] = {},
              ["green-pita-mini"] = {},
              ["grey-cracked-mud-decal"] = {},
              ["honeycomb-fungus"] = {},
              ["honeycomb-fungus-1x1"] = {},
              ["honeycomb-fungus-decayed"] = {},
              ["knobbly-roots"] = {},
              ["knobbly-roots-orange"] = {},
              ["lichen-decal"] = {},
              ["light-mud-decal"] = {},
              ["matches-small"] = {},
              mycelium = {},
              ["pale-lettuce-lichen-1x1"] = {},
              ["pale-lettuce-lichen-3x3"] = {},
              ["pale-lettuce-lichen-6x6"] = {},
              ["pale-lettuce-lichen-cups-1x1"] = {},
              ["pale-lettuce-lichen-cups-3x3"] = {},
              ["pale-lettuce-lichen-cups-6x6"] = {},
              ["pale-lettuce-lichen-water-1x1"] = {},
              ["pale-lettuce-lichen-water-3x3"] = {},
              ["pale-lettuce-lichen-water-6x6"] = {},
              ["pink-lichen-decal"] = {},
              ["pink-phalanges"] = {},
              ["polycephalum-balloon"] = {},
              ["polycephalum-slime"] = {},
              ["purple-nerve-roots-veins-dense"] = {},
              ["purple-nerve-roots-veins-sparse"] = {},
              ["red-desert-bush"] = {},
              ["red-lichen-decal"] = {},
              ["red-nerve-roots-veins-dense"] = {},
              ["red-nerve-roots-veins-sparse"] = {},
              ["red-pita"] = {},
              ["shroom-decal"] = {},
              ["solo-barnacle"] = {},
              ["split-gill-1x1"] = {},
              ["split-gill-2x2"] = {},
              ["split-gill-dying-1x1"] = {},
              ["split-gill-dying-2x2"] = {},
              ["split-gill-red-1x1"] = {},
              ["split-gill-red-2x2"] = {},
              veins = {},
              ["veins-small"] = {},
              ["white-carpet-grass"] = {},
              ["white-desert-bush"] = {},
              ["wispy-lichen"] = {},
              ["yellow-coral"] = {},
              ["yellow-lettuce-lichen-1x1"] = {},
              ["yellow-lettuce-lichen-3x3"] = {},
              ["yellow-lettuce-lichen-6x6"] = {},
              ["yellow-lettuce-lichen-cups-1x1"] = {},
              ["yellow-lettuce-lichen-cups-3x3"] = {},
              ["yellow-lettuce-lichen-cups-6x6"] = {}
            }
          },
          entity = {
            settings = {
              ["copper-stromatolite"] = {},
              ["iron-stromatolite"] = {},
              stone = {}
            }
          },
          tile = {
            settings = {
              ["gleba-deep-lake"] = {},
              ["highland-dark-rock"] = {},
              ["highland-dark-rock-2"] = {},
              ["highland-yellow-rock"] = {},
              ["lowland-brown-blubber"] = {},
              ["lowland-cream-cauliflower"] = {},
              ["lowland-cream-cauliflower-2"] = {},
              ["lowland-cream-red"] = {},
              ["lowland-dead-skin"] = {},
              ["lowland-dead-skin-2"] = {},
              ["lowland-olive-blubber"] = {},
              ["lowland-olive-blubber-2"] = {},
              ["lowland-olive-blubber-3"] = {},
              ["lowland-pale-green"] = {},
              ["lowland-red-infection"] = {},
              ["lowland-red-vein"] = {},
              ["lowland-red-vein-2"] = {},
              ["lowland-red-vein-3"] = {},
              ["lowland-red-vein-4"] = {},
              ["lowland-red-vein-dead"] = {},
              ["midland-cracked-lichen"] = {},
              ["midland-cracked-lichen-dark"] = {},
              ["midland-cracked-lichen-dull"] = {},
              ["midland-turquoise-bark"] = {},
              ["midland-turquoise-bark-2"] = {},
              ["midland-yellow-crust"] = {},
              ["midland-yellow-crust-2"] = {},
              ["midland-yellow-crust-3"] = {},
              ["midland-yellow-crust-4"] = {},
              ["natural-jellynut-soil"] = {},
              ["natural-yumako-soil"] = {},
              ["pit-rock"] = {},
              ["wetland-blue-slime"] = {},
              ["wetland-dead-skin"] = {},
              ["wetland-green-slime"] = {},
              ["wetland-jellynut"] = {},
              ["wetland-light-dead-skin"] = {},
              ["wetland-light-green-slime"] = {},
              ["wetland-pink-tentacle"] = {},
              ["wetland-red-tentacle"] = {},
              ["wetland-yumako"] = {}
            }
          }
        },
        cliff_settings = {
          cliff_elevation_0 = 40,
          cliff_elevation_interval = 60,
          cliff_smoothing = 0,
          control = "gleba_cliff",
          name = "cliff-gleba",
          richness = 0.8
        },
        property_expression_names = {
          aux = "gleba_aux",
          cliff_elevation = "cliff_elevation_from_elevation",
          cliffiness = "gleba_cliffiness",
          ["decorative:cracked-mud-decal:probability"] = "gleba_cracked_mud_probability",
          ["decorative:dark-mud-decal:probability"] = "gleba_dark_mud_probability",
          ["decorative:green-bush-mini:probability"] = "gleba_green_bush_probability",
          ["decorative:green-carpet-grass:probability"] = "gleba_green_carpet_grass_probability",
          ["decorative:green-croton:probability"] = "gleba_green_cronton_probability",
          ["decorative:green-hairy-grass:probability"] = "gleba_green_hairy_grass_probability",
          ["decorative:green-pita-mini:probability"] = "gleba_green_pita_mini_probability",
          ["decorative:green-pita:probability"] = "gleba_green_pita_probability",
          ["decorative:lichen-decal:probability"] = "gleba_orange_lichen_probability",
          ["decorative:light-mud-decal:probability"] = "gleba_light_mud_probability",
          ["decorative:red-desert-bush:probability"] = "gleba_red_desert_bush_probability",
          ["decorative:red-pita:probability"] = "gleba_red_pita_probability",
          ["decorative:shroom-decal:probability"] = "gleba_carpet_shroom_probability",
          ["decorative:white-desert-bush:probability"] = "gleba_white_desert_bush_probability",
          elevation = "gleba_elevation",
          enemy_base_frequency = "gleba_enemy_base_frequency",
          enemy_base_radius = "gleba_enemy_base_radius",
          ["entity:stone:probability"] = "gleba_stone_probability",
          ["entity:stone:richness"] = "gleba_stone_richness",
          moisture = "gleba_moisture",
          temperature = "gleba_temperature"
        }
   },
   nauvis = {
        autoplace_controls = {
          coal = {},
          ["copper-ore"] = {},
          ["crude-oil"] = {},
          ["enemy-base"] = {},
          ["iron-ore"] = {},
          nauvis_cliff = {},
          rocks = {},
          starting_area_moisture = {},
          stone = {},
          trees = {},
          ["uranium-ore"] = {},
          water = {}
        },
        autoplace_settings = {
          decorative = {
            settings = {
              ["brown-asterisk"] = {},
              ["brown-asterisk-mini"] = {},
              ["brown-carpet-grass"] = {},
              ["brown-fluff"] = {},
              ["brown-fluff-dry"] = {},
              ["brown-hairy-grass"] = {},
              ["cracked-mud-decal"] = {},
              ["dark-mud-decal"] = {},
              garballo = {},
              ["garballo-mini-dry"] = {},
              ["green-asterisk"] = {},
              ["green-asterisk-mini"] = {},
              ["green-bush-mini"] = {},
              ["green-carpet-grass"] = {},
              ["green-croton"] = {},
              ["green-desert-bush"] = {},
              ["green-hairy-grass"] = {},
              ["green-pita"] = {},
              ["green-pita-mini"] = {},
              ["green-small-grass"] = {},
              ["light-mud-decal"] = {},
              ["medium-rock"] = {},
              ["medium-sand-rock"] = {},
              ["red-asterisk"] = {},
              ["red-croton"] = {},
              ["red-desert-bush"] = {},
              ["red-desert-decal"] = {},
              ["red-pita"] = {},
              ["sand-decal"] = {},
              ["sand-dune-decal"] = {},
              ["small-rock"] = {},
              ["small-sand-rock"] = {},
              ["tiny-rock"] = {},
              ["white-desert-bush"] = {}
            }
          },
          entity = {
            settings = {
              ["big-rock"] = {},
              ["big-sand-rock"] = {},
              coal = {},
              ["copper-ore"] = {},
              ["crude-oil"] = {},
              fish = {},
              ["huge-rock"] = {},
              ["iron-ore"] = {},
              stone = {},
              ["uranium-ore"] = {}
            }
          },
          tile = {
            settings = {
              deepwater = {},
              ["dirt-1"] = {},
              ["dirt-2"] = {},
              ["dirt-3"] = {},
              ["dirt-4"] = {},
              ["dirt-5"] = {},
              ["dirt-6"] = {},
              ["dirt-7"] = {},
              ["dry-dirt"] = {},
              ["grass-1"] = {},
              ["grass-2"] = {},
              ["grass-3"] = {},
              ["grass-4"] = {},
              ["red-desert-0"] = {},
              ["red-desert-1"] = {},
              ["red-desert-2"] = {},
              ["red-desert-3"] = {},
              ["sand-1"] = {},
              ["sand-2"] = {},
              ["sand-3"] = {},
              water = {}
            }
          }
        },
        aux_climate_control = true,
        cliff_settings = {
          cliff_smoothing = 0,
          control = "nauvis_cliff",
          name = "cliff"
        },
        moisture_climate_control = true,
        property_expression_names = {}
   },
   vulcanus = {
        autoplace_controls = {
          calcite = {},
          sulfuric_acid_geyser = {},
          tungsten_ore = {},
          vulcanus_coal = {},
          vulcanus_volcanism = {}
        },
        autoplace_settings = {
          decorative = {
            settings = {
              ["calcite-stain"] = {},
              ["calcite-stain-small"] = {},
              ["crater-large"] = {},
              ["crater-small"] = {},
              ["medium-volcanic-rock"] = {},
              ["pumice-relief-decal"] = {},
              ["small-sulfur-rock"] = {},
              ["small-volcanic-rock"] = {},
              ["sulfur-rock-cluster"] = {},
              ["sulfur-stain"] = {},
              ["sulfur-stain-small"] = {},
              ["sulfuric-acid-puddle"] = {},
              ["sulfuric-acid-puddle-small"] = {},
              ["tiny-rock-cluster"] = {},
              ["tiny-sulfur-rock"] = {},
              ["tiny-volcanic-rock"] = {},
              ["v-brown-carpet-grass"] = {},
              ["v-brown-hairy-grass"] = {},
              ["v-green-hairy-grass"] = {},
              ["v-red-pita"] = {},
              ["vulcanus-crack-decal-huge-warm"] = {},
              ["vulcanus-crack-decal-large"] = {},
              ["vulcanus-dune-decal"] = {},
              ["vulcanus-lava-fire"] = {},
              ["vulcanus-rock-decal-large"] = {},
              ["vulcanus-sand-decal"] = {},
              ["waves-decal"] = {}
            }
          },
          entity = {
            settings = {
              ["ashland-lichen-tree"] = {},
              ["ashland-lichen-tree-flaming"] = {},
              ["big-volcanic-rock"] = {},
              calcite = {},
              coal = {},
              ["crater-cliff"] = {},
              ["huge-volcanic-rock"] = {},
              ["sulfuric-acid-geyser"] = {},
              ["tungsten-ore"] = {},
              ["vulcanus-chimney"] = {},
              ["vulcanus-chimney-cold"] = {},
              ["vulcanus-chimney-faded"] = {},
              ["vulcanus-chimney-short"] = {},
              ["vulcanus-chimney-truncated"] = {}
            }
          },
          tile = {
            settings = {
              lava = {},
              ["lava-hot"] = {},
              ["volcanic-ash-cracks"] = {},
              ["volcanic-ash-dark"] = {},
              ["volcanic-ash-flats"] = {},
              ["volcanic-ash-light"] = {},
              ["volcanic-ash-soil"] = {},
              ["volcanic-cracks"] = {},
              ["volcanic-cracks-hot"] = {},
              ["volcanic-cracks-warm"] = {},
              ["volcanic-folds"] = {},
              ["volcanic-folds-flat"] = {},
              ["volcanic-folds-warm"] = {},
              ["volcanic-jagged-ground"] = {},
              ["volcanic-pumice-stones"] = {},
              ["volcanic-smooth-stone"] = {},
              ["volcanic-smooth-stone-warm"] = {},
              ["volcanic-soil-dark"] = {},
              ["volcanic-soil-light"] = {}
            }
          }
        },
        cliff_settings = {
          cliff_elevation_0 = 70,
          cliff_elevation_interval = 120,
          name = "cliff-vulcanus"
        },
        property_expression_names = {
          aux = "vulcanus_aux",
          cliff_elevation = "cliff_elevation_from_elevation",
          cliffiness = "cliffiness_basic",
          elevation = "vulcanus_elevation",
          ["entity:calcite:probability"] = "vulcanus_calcite_probability",
          ["entity:calcite:richness"] = "vulcanus_calcite_richness",
          ["entity:coal:probability"] = "vulcanus_coal_probability",
          ["entity:coal:richness"] = "vulcanus_coal_richness",
          ["entity:sulfuric-acid-geyser:probability"] = "vulcanus_sulfuric_acid_geyser_probability",
          ["entity:sulfuric-acid-geyser:richness"] = "vulcanus_sulfuric_acid_geyser_richness",
          ["entity:tungsten-ore:probability"] = "vulcanus_tungsten_ore_probability",
          ["entity:tungsten-ore:richness"] = "vulcanus_tungsten_ore_richness",
          moisture = "vulcanus_moisture",
          temperature = "vulcanus_temperature"
        },
        territory_settings = {
          minimum_territory_size = 10,
          territory_index_expression = "demolisher_territory_expression",
          territory_variation_expression = "demolisher_variation_expression",
          units = {
            "small-demolisher",
            "medium-demolisher",
            "big-demolisher"
          }
        }
   },
}
