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