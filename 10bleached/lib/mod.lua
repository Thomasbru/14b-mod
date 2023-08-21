-- bleached 10 bit midi to OSC

local mod = require 'core/mods'

include("/10bleached/lib/_midi")
include("/10bleached/lib/_params")

local n = {}

-- MIDI
local m = {}
  
-- midi channels in order of MSB - LSB
local midi_channels = {
  {102, 103},
  {104, 105},
  {106, 107},
  {108, 109},
  {110, 111},
  {112, 113},
  {114, 115}
}

local BIT_RESOLUTION = 12
local midi_table = {}
local p_list = {}
local max_bits = 1 << BIT_RESOLUTION
local map_mode = false
local p_index = 1

local mapped = {} --empty map, should be able to be saved and loaded upon script load.
mod.hook.register("system_post_startup", "midi_tools", function()
  m = _norns.midi.add()
  midi_table = _midi.generate_table(midi_channels)
  max_bits = 1 << BIT_RESOLUTION
  map_mode = false
  p_index = 1
  p_list = _params.generate_list()
end)

mod.hook.register("script_pre_init", "param_grab", function()
  -- tweak global environment here ahead of the script `init()` function being called
  p_list = _params.generate_list() --generates indexed list of available params
  p_index = 1
end)

n.init = function()
  p_list = _params.generate_list() --generates indexed list of available params
end


-- MIDI
local last_msb = 0
local last_cc = 0
local current_val = 0

_norns.midi.event = function(id, data)
	local d = midi.to_msg(data)
	_midi.msghandler(d)
end



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
  elseif k == 2 and z == 1 and save_mode then
    -- load script map from disk
  elseif k == 3 and z == 1 then
    if map_mode == false then
      local mappable = _params.checkmap(p_index)
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

n.deinit = function() 
  screen.clear()  
end -- on menu exit


--- _params

_params = {}

function _params.generate_list()
  -- generates list of available parameters by name
  local p_list = {}
  for i = 1, #params.params do
    p_list[i] = params.params[i].id
  end
  return p_list
end


function _params.map(note, index)
  mapped[note] = index  
end

function _params.checkmap(inx)
  local mappable
  local type = params:t(inx)
  if type == 1 or type == 2 or type == 3 or type == 5 or type == 6 then
    mappable = true
  else
    mappable = false
  end
  return mappable
end


-- Function for looking up mapped params and scale input accordingly.
-- Borrowed and modified from jaseknighter's osc-mod (https://github.com/jaseknighter/osc-mod/)
function _params.lookup(note, val)
  local param = mapped[note]
  print(note)
  -- local param = params:lookup_param(param)

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


-- _midi

_midi = {}
-- midi functions

function _midi.generate_table(channels)
  -- generates an associative table of MSB and LSB pairs
  local table = {}
  for i = 1, #channels do
    table[channels[i][1]] = channels[i][2]
  end
  return table
end


function _midi.msghandler(d)
  -- determines MSB or LSB
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
			  local b_val = last_msb | d.val
			  current_val = b_val >> (14 - BIT_RESOLUTION)
			  _params.lookup(last_cc, current_val)
		  end
		end
	end
end

mod.menu.register(mod.this_name, n)
