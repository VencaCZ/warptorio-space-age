require("util")
local sounds = require("__base__/prototypes/entity/sounds")

local shadow_shift = { -0.75, -0.40 }
local animation_shift = { 0, 0 }

local adjust_animation = function(animation)

    local animation = util.copy(animation)
    local layers = animation.layers or {animation}

    for k, layer in pairs(layers) do 
        layer.frame_count = layer.direction_count
        layer.direction_count = 0
        layer.animation_speed = 1
        layer.shift = util.add_shift(layer.shift, animation_shift)
    end

    return animation
end

local adjust_shadow = function(shadow_animation)

    local shadow_animation = util.copy(shadow_animation)
    local layers = shadow_animation.layers or {shadow_animation}
  
    for k, layer in pairs (layers) do
        layer.frame_count = layer.direction_count
        layer.direction_count = 0
        layer.animation_speed = 1
        layer.shift = util.add_shift(layer.shift, shadow_shift)
    end
  
    return shadow_animation
  end
  
  local reversed = function(animation)
    local animation = util.copy(animation)
    local layers = animation.layers or {animation}
  
    for k, layer in pairs (layers) do
        layer.run_mode = "backward"     
    end
  
    return animation
end

local animations = 
{
    defender_unit = 
    {
        base_animation = 
        {
            layers = 
            {
                {
                    filename = "__base__/graphics/entity/defender-robot/defender-robot.png",
                    priority = "high",
                    line_length = 16,
                    width = 56,
                    height = 59,
                    -- frame_count = 1,
                    direction_count = 16,
                    shift = util.by_pixel(0, 0.25),
                  },
                  {
                    filename = "__base__/graphics/entity/defender-robot/defender-robot-mask.png",
                    priority = "high",
                    line_length = 16,
                    width = 28,
                    height = 21,
                    direction_count = 16,
                    shift = util.by_pixel(0, -4.75),
                    apply_runtime_tint = true,
                    scale = 0.5
                }
            }
        },

        shadow_base_animation = 
        {
            filename = "__base__/graphics/entity/defender-robot/defender-robot-shadow.png",
            priority = "high",
            line_length = 16,
            width = 88,
            height = 50,
            direction_count = 16,
            shift = util.by_pixel(25.5, 19),
            draw_as_shadow = true,
            scale = 0.5
        },	
        
        animation = 
        {
            layers = 
            {
                {
                    filename = "__base__/graphics/entity/defender-robot/defender-robot.png",
                    priority = "high",
                    line_length = 16,
                    width = 56,
                    height = 59,
                    animation_speed = 1,
                    direction_count = 16,
                    shift = util.by_pixel(0, 0.25),
                    y = 59,
                    scale = 0.5
                },
                {
                    filename = "__base__/graphics/entity/defender-robot/defender-robot-mask.png",
                    priority = "high",
                    line_length = 16,
                    width = 28,
                    height = 21,
                    animation_speed = 1,
                    direction_count = 16,
                    shift = util.by_pixel(0, -4.75),
                    apply_runtime_tint = true,
                    y = 21,
                    scale = 0.5
                }
            }
        },

        shadow_animation = 
        {
            filename = "__base__/graphics/entity/defender-robot/defender-robot-shadow.png",
            priority = "high",
            line_length = 16,
            width = 88,
            height = 50,
            animation_speed = 1,
            direction_count = 16,
            shift = util.by_pixel(25.5, 19),
            scale = 0.5,
            draw_as_shadow = true,
        }
    },

    sentry_unit = 
    -- {
    --     idle =
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 38,
    --         height = 33,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(0, -2.5),
    --         scale = 0.5,
    --     },
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot-mask.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 24,
    --         height = 21,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(0, -6.25),
    --         apply_runtime_tint = true,
    --         scale = 0.5,
    --     },
    --     shadow_idle =
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot-shadow.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 49,
    --         height = 30,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(32.5, 19),
    --         draw_as_shadow = true,
    --         scale = 0.5,
    --     },
    --     in_motion = 
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 38,
    --         height = 33,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(0, -2.5),
    --         y = 62,
    --         scale = 0.5,
    --     },
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot-mask.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 24,
    --         height = 21,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(0, -6.25),
    --         apply_runtime_tint = true,
    --         y = 37,
    --         scale = 0.5,
    --     },
        
    --     shadow_in_motion = 
    --     {
    --         filename = "__base__/graphics/entity/distractor-robot/distractor-robot-shadow.png",
    --         priority = "high",
    --         line_length = 16,
    --         width = 49,
    --         height = 30,
    --         frame_count = 1,
    --         direction_count = 16,
    --         shift = util.by_pixel(32.5, 19),
    --         scale = 0.5,
    --         draw_as_shadow = true,
    --     }
    {

        idle =
        {
          layers =
          {
            {
              filename = "__base__/graphics/entity/distractor-robot/distractor-robot.png",
              priority = "high",
              line_length = 16,
              width = 72,
              height = 62,
              direction_count = 16,
              shift = util.by_pixel(0, -2.5),
              scale = 0.5
            },
            {
              filename = "__base__/graphics/entity/distractor-robot/distractor-robot-mask.png",
              priority = "high",
              line_length = 16,
              width = 42,
              height = 37,
              direction_count = 16,
              shift = util.by_pixel(0, -6.25),
              apply_runtime_tint = true,
              scale = 0.5
            }
          }
        },
        shadow_idle =
        {
          filename = "__base__/graphics/entity/distractor-robot/distractor-robot-shadow.png",
          priority = "high",
          line_length = 16,
          width = 96,
          height = 59,
          direction_count = 16,
          shift = util.by_pixel(32.5, 19.25),
          scale = 0.5,
          draw_as_shadow = true
        },
        in_motion =
        {
          layers =
          {
            {
              filename = "__base__/graphics/entity/distractor-robot/distractor-robot.png",
              priority = "high",
              line_length = 16,
              width = 72,
              height = 62,
              direction_count = 16,
              shift = util.by_pixel(0, -2.5),
              y = 62,
              scale = 0.5
            },
            {
              filename = "__base__/graphics/entity/distractor-robot/distractor-robot-mask.png",
              priority = "high",
              line_length = 16,
              width = 42,
              height = 37,
              direction_count = 16,
              shift = util.by_pixel(0, -6.25),
              apply_runtime_tint = true,
              y = 37,
              scale = 0.5
            }
          }
        },
        shadow_in_motion =
        {
          filename = "__base__/graphics/entity/distractor-robot/distractor-robot-shadow.png",
          priority = "high",
          line_length = 16,
          width = 96,
          height = 59,
          direction_count = 16,
          shift = util.by_pixel(32.5, 19.25),
          scale = 0.5,
          draw_as_shadow = true
        }
    },
    
    destroyer_unit = 
    {
        base_animation = 
        {
            layers = 
            { 
                {
                    filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot.png",
                    priority = "high",
                    line_length = 32,
                    width = 88,
                    height = 77,
                    y = 77,
                    direction_count = 32,
                    shift = util.by_pixel(2.5, -1.25),
                    scale = 0.5,
                },
                {
                    filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot-mask.png",
                    priority = "high",
                    line_length = 32,
                    width = 52,
                    height = 42,
                    y = 42,
                    direction_count = 32,
                    shift = util.by_pixel(2.5, -7),
                    apply_runtime_tint = true,
                    scale = 0.5,
                }
            }
        },
        
        shadow_base_animation = 
        {
            filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot-shadow.png",
            priority = "high",
            line_length = 32,
            width = 108,
            height = 66,
            direction_count = 32,
            shift = util.by_pixel(2.5, -7),
            scale = 0.5,
            draw_as_shadow = true,
        },
        
        animation = 
        {
            layers = 
            {
                {           
                    filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot.png",
                    priority = "high",
                    line_length = 32,
                    width = 88,
                    height = 77,
                    direction_count = 32,
                    shift = util.by_pixel(2.5, -1.25),
                    scale = 0.5,
                },
                {
                    filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot-mask.png",
                    priority = "high",
                    line_length = 32,
                    width = 52,
                    height = 42,
                    direction_count = 32,
                    shift = util.by_pixel(2.5, -7),
                    apply_runtime_tint = true,
                    scale = 0.5,
                }
            }
        },
        
        shadow_animation =
        {
            filename = "__base__/graphics/entity/destroyer-robot/destroyer-robot-shadow.png",
            priority = "high",
            line_length = 32,
            width = 108,
            height = 66,
            direction_count = 32,
            shift = util.by_pixel(2.5, -7),
            scale = 0.5,
            draw_as_shadow = true,
        }
    },

    make_robot_particle = function(prototype)

        local particle_name = prototype.name.."-dying-particle"

        if not prototype.in_motion then return end
        local animation = adjust_animation(prototype.in_motion)
        if not prototype.shadow_in_motion then return end
        local shadow_animation = adjust_shadow(prototype.shadow_in_motion)

        local unit_name = prototype.name:gsub( "-unit", "")
        
        if unit_name:find("sentry") then
            unit_name = unit_name:gsub( "sentry", "distractor" )
        end
    
        local particle =
        {
            type = "optimized-particle",
            name = particle_name,
            pictures = {animation, reversed(animation)},
            shadows = {shadow_animation, reversed(shadow_animation)},
            movement_modifier = 0.95,
            life_time = 1000,
            regular_trigger_effect_frequency = 2,
            regular_trigger_effect =
            {
                {
                    type = "create-trivial-smoke",
                    smoke_name = "smoke-fast",
                    starting_frame_deviation = 5,
                    probability = 0.5
                },
                {
                    type = "create-particle",
                    particle_name = "spark-particle",
                    tail_length = 10,
                    tail_length_deviation = 5,
                    tail_width = 5,
                    probability = 0.2,
                    initial_height = 0.2,
                    initial_vertical_speed = 0.15,
                    initial_vertical_speed_deviation = 0.05,
                    speed_from_center = 0.1,
                    speed_from_center_deviation = 0.05,
                    offset_deviation = {{-0.25, -0.25},{0.25, 0.25}}
                }
            },
            ended_on_ground_trigger_effect =
            {
                {
                    type = "create-entity",
                    entity_name = unit_name.."-remnants",
                    offsets = {{0, 0}}
                },
                {
                    type = "play-sound",
                    sound = sounds.robot_die_impact,
                },
            }
        }
        
        data:extend{particle}
        
        prototype.dying_trigger_effect =
        {
            {
                type = "create-particle",
                particle_name = particle_name,
                initial_height = 1.8,
                initial_vertical_speed = 0,
                frame_speed = 1,
                frame_speed_deviation = 0.5,
                speed_from_center = 0,
                speed_from_center_deviation = 0.2,
                offset_deviation = {{-0.01, -0.01},{0.01, 0.01}},
                offsets = {{0, 0.5}}
            },
            {
                type = "play-sound",
                sound = sounds.robot_die_whoosh,
            }, 
            {
                type = "play-sound",
                sound = sounds.robot_die_vox,
            },
        }
            
        prototype.destroy_action =
        {
            type = "direct",
            action_delivery =
            {
                type = "instant",
                source_effects = 
                {
                    {
                        type = "create-particle",
                        particle_name = particle_name,
                        initial_height = 1.8,
                        initial_vertical_speed = 0,
                        frame_speed = 0.5,
                        frame_speed_deviation = 0.5,
                        speed_from_center = 0,
                        speed_from_center_deviation = 0.1,
                        offset_deviation = {{-0.01, -0.01},{0.01, 0.01}},
                        offsets = {{0, 0.5}}
                    },
                    {
                        type = "play-sound",
                        sound = sounds.robot_die_whoosh,
                    },
                    {
                        type = "play-sound",
                        sound = sounds.robot_die_vox,
                    },
                    {
                        type = "play-sound",
                        sound = sounds.robot_selfdestruct,
                    },    
                }
            }
        }
      
    end
}

return animations