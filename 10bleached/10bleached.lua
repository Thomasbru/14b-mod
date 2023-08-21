-- bleached 10 bit midi to OSC

local mod = require 'core/mods'


include("lib/_midi")
include("lib/_params")

-- MIDI
m = midi.connect()

-- midi channels in order of MSB - LSB
midi_channels = {
  {102, 103},
  {104, 105},
  {106, 107},
  {108, 109},
  {110, 111},
  {112, 113},
  {114, 115}
}

BIT_RESOLUTION = 12

mapped = {} --empty map, should be able to be saved and loaded upon script load.
mod.hook.register("system_post_startup", "midi_tools", function()
  midi_table = _midi.generate_table(midi_channels)
  max_bits = 1 << BIT_RESOLUTION
  map_mode = false
end)

mod.hook.register("script_pre_init", "param_grab", function()
  -- tweak global environment here ahead of the script `init()` function being called
  p_list = _params.generate_list() --generates indexed list of available params
  p_index = 1
end)


-- MIDI
last_msb = 0
last_cc = 0
current_val = 0

m.event = function(data)
	local d = midi.to_msg(data)
	_midi.msghandler(d)
	redraw()
end



-- ENC FUNCTIONS
-- enc 3 changes parameter index
function enc(e, d)
  if e == 3 then
    p_index = util.clamp(p_index + d, 1, #p_list)
    redraw()
  end
end

function key(k, z)
  if k == 1 then
    save_mode = z
  elseif k == 3 and z == 1 and save_mode then
    -- write script map to disk
  elseif k == 2 and z == 1 and save_mode then
    -- load script map from disk
  elseif k == 3 and z == 1 then
    if map_mode == false then
      local mappable = _params.checkmap(p_index)
      if mappable then
        map_mode = true
      else
        redraw_notmap()
      end
    elseif map_mode == true then
      map_mode = false
    end
  elseif k == 3 and z == 0 then
    redraw()
  elseif k == 2 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  end
end

function redraw_notmap()
  screen.clear()
  screen.move(0, 40)
  screen.level(15)
  screen.text("not mappable")
  screen.update()
end
  
function redraw()
  screen.clear()
  -- left side: params
  screen.move(0, 5)
  screen.level(15)
  screen.text("params/")
  screen.move(128, 5)
  screen.text_right("midi")
  -- list all params
  for i = 0, 5 do
    screen.move(0, 20 + (10*i))
    local offset = 2 - i
    if offset == 0 then
      screen.level(15)
    else
      screen.level(3)
    end
    if p_list[p_index-offset] then
      screen.text(p_list[p_index-offset])
      if map_mode == true and offset == 0 then
        screen.move_rel(10, 0)
        screen.text("*")
      end
      
      for j, k in pairs(mapped) do
        if p_index-offset == k then
          screen.move(128, 20 + (10*i))
          screen.text_right(j)
        end
      end
    end
  end
  screen.update()
end
