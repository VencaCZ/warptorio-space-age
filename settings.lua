
data:extend(
{
	{type = "string-setting",name="warptorio_factory-tile",order="11b",
	setting_type="startup",default_value="space-platform-foundation"},

  {type = "string-setting",name="warptorio_planets-t1",order="11b",
   setting_type="startup",default_value="nauvis,void"},

  {type = "string-setting",name="warptorio_planets-t2",order="11b",
   setting_type="startup",default_value="gleba,fulgora,vulcanus"},

  {type = "string-setting",name="warptorio_planets-t3",order="11b",
   setting_type="startup",default_value="aquilo",allow_blank=true},

  {type = "string-setting",name="warptorio_planets-t4",order="11b",
   setting_type="startup",default_value="",allow_blank=true},
  
	{type = "string-setting",name="warptorio_ground-tile",order="11b",
	setting_type="startup",default_value="foundation"},

	{type="double-setting",name="warptorio_time-per-jump",order="11b",
	setting_type="startup",default_value=1,
	minimum_value=0.5,maximum_value=10},
  {type="double-setting",name="warptorio_players",order="11b",
   setting_type="startup",default_value=0.51,
   minimum_value=0.01,maximum_value=1.0},

  {type="double-setting",name="warptorio_stuck-in-space-chance",order="11b",
   setting_type="startup",default_value=0.05,
   minimum_value=0.00,maximum_value=1.0},

  {type="double-setting",name="warptorio_going-home-chance",order="11b",
   setting_type="startup",default_value=0.05,
   minimum_value=0.00,maximum_value=1.0},
  
	{type="int-setting",name="warptorio_wave-amount",order="11b",
	setting_type="startup",default_value=5,
	minimum_value=1,maximum_value=100},

	{type="int-setting",name="warptorio_wave-increase",order="11b",
	setting_type="startup",default_value=1,
	minimum_value=1,maximum_value=100},

	{type="int-setting",name="warptorio_wave-change",order="11b",
	setting_type="startup",default_value=10,
	minimum_value=10,maximum_value=100},

	{type="int-setting",name="warptorio_wave-time",order="11b",
	setting_type="startup",default_value=120,
	minimum_value=60,maximum_value=300},

	{type="int-setting",name="warptorio_quality-start",order="11b",
	setting_type="startup",default_value=400,
	minimum_value=100,maximum_value=600},

	{type="int-setting",name="warptorio_quality-step",order="11b",
	setting_type="startup",default_value=40,
	minimum_value=10,maximum_value=100},
  
	{type="int-setting",name="warptorio_jumps",order="11b",
	setting_type="startup",default_value=400,
	minimum_value=1,maximum_value=600},

	{type="double-setting",name="warptorio_research-multiplier",order="11b",
	setting_type="startup",default_value=1,
	minimum_value=0.5,maximum_value=100},
  
	{type="int-setting",name="warptorio_warpout-time",order="11b",
	setting_type="startup",default_value=60,
	minimum_value=60,maximum_value=300},

	{type="bool-setting",name="warptorio_starter",order="11b",
	setting_type="startup",default_value=false},

  	{type="bool-setting",name="warptorio_reset-recipe",order="11b",
	setting_type="startup",default_value=false},
  
	{type="bool-setting",name="warptorio_next-planet-sound",order="11b",
	setting_type="startup",default_value=true},

	{type="bool-setting",name="warptorio_next-planet-text",order="11b",
	setting_type="startup",default_value=true},

  {type="bool-setting",name="warptorio_allow-random-position",order="11b",
	setting_type="startup",default_value=true},
  
  {type="bool-setting",name="warptorio_space-transition",order="11b",
	setting_type="startup",default_value=true},

  {
     type = "string-setting",
     name = "warptorio_size-difficulty",
     setting_type = "startup",
     default_value = "Normal",
     allowed_values = {"SuperEasy", "Easy", "Normal", "Hard", "SuperHard"},
     order = "a1"
  },

  {
     type = "string-setting",
     name = "warptorio_factory-shape",
     setting_type = "startup",
     default_value = "cross",
     allowed_values = {"cross","ellipse","hexagon"},
     order = "a1"
  }
}
)
