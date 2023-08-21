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
