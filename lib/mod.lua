-- bleached >7 bit midi to param mapping

local mod = require 'core/mods'

-- Includes not needed for mod.
-- include("/14b-mod/lib/_midi")
-- include("/14b-mod/lib/_params")

local n = {}

-- MIDI
local m = {}

--[[
---   SETUP AREA ---
This mod is meant to work with a custom bleached firmware providing 14 bit midi 
(but in reality only 12 bits, due to Teensy LC read resolution).

For robustness and compatibility the user would have to tweak their own midi MSB/LSB channel routing below
in the array midi_channels, if other devices are used. Array can be any size, as long as it has valid channel pairs.

As midi channels are upscaled in bleached firmware, the user can also downscale the resolution of incoming midi to the correct bit size,
tweaking the BIT_RESOLUTION variable.
--]]

-- midi channel array with pairs of of {MSB, LSB}
local midi_channels = {
  {102, 103},
  {104, 105},
  {106, 107},
  {108, 109},
  {110, 111},
  {112, 113},
  {114, 115}
}
-- wanted resolution of midi controller
-- from bleached 
local BIT_RESOLUTION = 12 -- 7 to 14 should be valid.

--[[
---   SETUP AREA END ---
--]]

-- empty tables, decleared, to be filled in hooks
local midi_table = {}
local p_list = {}
local p_index = 1 -- current index of p_list

-- some variables
local max_bits = 1 << BIT_RESOLUTION
local map_mode = false
local save_mode = false
local last_msb = 0
local last_cc = 0
local current_script

-- The mapped presets
local mapped = {} --empty map, should be able to be saved and loaded upon script load.


-- MOD HOOKS
mod.hook.register("system_post_startup", "midi_tools", function()
  m = _norns.midi.add()
  midi_table = n.generate_table(midi_channels)
  -- max_bits = 1 << BIT_RESOLUTION
  -- map_mode = false
  -- p_index = 1
  p_list = n.generate_list()
end)

mod.hook.register("script_pre_init", "param_grab", function()
  m = _norns.midi.add()
  -- tweak global environment here ahead of the script `init()` function being called
  p_list = n.generate_list() --generates indexed list of available params
  p_index = 1
  current_script = norns.state.name
end)

--[[
mod.hook.register("script_pre_init", "param_grab", function()
  m = _norns.midi.add()
  -- tweak global environment here ahead of the script `init()` function being called
  p_list = n.generate_list() --generates indexed list of available params
  p_index = 1
  current_script = norns.state.name
end)
--]]

-- init/deinit functions
n.init = function()
  --
end --on init 

n.deinit = function() 
  screen.clear()  
end -- on menu exit


-- ENC FUNCTIONS
-- enc 3 changes parameter index
n.enc = function(e, d)
  if e == 3 then
    p_index = util.clamp(p_index + d, 1, #p_list)
    n.redraw()
  end
end


-- KEY FUNCTIONS
-- K1 + K2 loads map
-- K1 + K3 saves map
-- K3 puts mod in "learn mode"
-- K2 exits
n.key = function(k, z)
  if k == 1 then
    save_mode = z
  elseif k == 3 and z == 1 and save_mode then
    -- write script map to disk
    n.save_maps()
  elseif k == 2 and z == 1 and save_mode then
    -- load script map from disk
    n.load_maps()
  elseif k == 3 and z == 1 then
    if map_mode == false then
      local mappable = n.checkmap(p_index)
      if mappable then
        map_mode = true
      else
        n.redraw_notmap()
      end
    elseif map_mode == true then
      map_mode = false
    end
  elseif k == 3 and z == 0 then
    n.redraw()
  elseif k == 2 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  end
end

n.redraw_notmap = function()
  screen.clear()
  screen.move(0, 40)
  screen.level(15)
  screen.text("not mappable")
  screen.update()
end
  
n.redraw = function()
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

--- parameter functions

function n.generate_list()
  -- generates a table of available parameters by name
  -- should be called upon norns startup and script start
  local list = {}
  for i = 1, #params.params do
    list[i] = params.params[i].id
  end
  return list
end


function n.map(note, index)
  -- maps midi note to preset index
  mapped[note] = index
end

function n.checkmap(inx)
  -- checks if parameter type in list is mappable
  local mappable
  local type = params:t(inx)
  if type == 1 or type == 2 or type == 3 or type == 5 or type == 6 then
    mappable = true
  else
    mappable = false
  end
  return mappable
end


function n.lookup(note, val)
  -- Function for looking up mapped params and scale input accordingly.
  -- Code is borrowed and modified from jaseknighter's osc-mod 
  -- (found at https://github.com/jaseknighter/osc-mod/)
  local param = mapped[note]

  -- param types
  -- 0: separator
  -- 1: number
  -- 2: options
  -- 3: control
  -- 5: taper
  -- 6: trigger
  -- 7: group
  -- 8: text

  if param then
    local type = params:t(param)
    local min, max, mapped_val

    if type == 1 then      -- 1: number
      min = params:get_range(param)[1]
      max = params:get_range(param)[2]
      mapped_val = util.linlin(0,max_bits,min,max,val)
      params:set(param, mapped_val)
    elseif type == 2 then  -- 2: options
      min = 1
      max = params:lookup_param(param).count
      params:set(param, val)
    elseif type == 3 or type == 5 then  -- 3: control/ 5: taper
      -- local raw = param.raw
      -- min = param.controlspec.minval
      -- max = param.controlspec.maxval
      -- mapping for control/taper params
      local pre_mapped_val = util.linlin(0,max_bits,0,1,val)
      mapped_val = params:lookup_param(param).controlspec:map(pre_mapped_val)
      params:set(param, mapped_val)
      -- print(param, mapped_val)
    elseif type == 6 then  -- 6: trigger
      if val == 1 then
        params:set(param, 1)
      end
    end
  end
end


-- midi functions

_norns.midi.event = function(id, data)
  local d = midi.to_msg(data)
  n.msghandler(d)
end

function n.generate_table(channels)
  -- generates an associative table of MSB and LSB pairs
  
  local table = {}
  for i = 1, #channels do
    table[channels[i][1]] = channels[i][2]
  end
  return table
end


function n.msghandler(d)
  -- if map_mode = true, maps next midi msb to param
  -- if not map_mode, determines MSB or LSB of a preset midi pair 
  -- and sends value to mapped parameter
  
  if d.type == "cc" then
    if map_mode == true then
      -- map selected param to midi channel
      for j, k in pairs(mapped) do
        if k == p_index then
          tab.remove(mapped, j)
        end
      end
      mapped[d.cc] = p_index
      map_mode = false
      n.redraw()
    else
		  if midi_table[d.cc] then
			  -- MSB
			  last_cc = d.cc
			  last_msb = d.val << 7
		  elseif d.cc == midi_table[last_cc] then
			  -- LSB
			  local full_val = last_msb | d.val
			  local scaled_val = full_val >> (14 - BIT_RESOLUTION)
			  n.lookup(last_cc, scaled_val)
		  end
		end
	end
end

-- Save/load mappings

function n.save_maps()
  local save_name
  if current_script then
    save_name = current_script
  else
    save_name = "none"
  tab.save(mapped, _path.data .. "14b-mod/" .. save_name .. .txt)
end

function n.load_maps()
  local load_name
  if current_script then
    load_name = current_script
  else
    load_name = "none"
  mapped = tab.load(_path.data .. "14b-mod/" .. load_name .. .txt)
end

function n.reset_maps()
  mapped = {}
end


-- register the mod menu
--
-- NOTE: `mod.this_name` is a convienence variable which will be set to the name
-- of the mod which is being loaded. in order for the menu to work it must be
-- registered with a name which matches the name of the mod in the dust folder.
--
mod.menu.register(mod.this_name, n)


--
-- [optional] returning a value from the module allows the mod to provide
-- library functionality to scripts via the normal lua `require` function.
--
-- NOTE: it is important for scripts to use `require` to load mod functionality
-- instead of the norns specific `include` function. using `require` ensures
-- that only one copy of the mod is loaded. if a script were to use `include`
-- new copies of the menu, hook functions, and state would be loaded replacing
-- the previous registered functions/menu each time a script was run.
--
-- here we provide a single function which allows a script to get the mod's
-- state table. using this in a script would look like:
--
-- local mod = require 'name_of_mod/lib/mod'
-- local the_state = mod.get_state()
--

local api = {}

api.get_state = function()
  return state
end

return api
