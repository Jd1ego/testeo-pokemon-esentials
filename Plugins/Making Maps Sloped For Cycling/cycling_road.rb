################################################################################
#Updated By: ORION
################################################################################
# You can add more map ID to the Array and it will be considered a cycling map
CYCLING_ROAD_MAP_IDS = [166]

def onCyclingRoad?  
  for id in CYCLING_ROAD_MAP_IDS
	return true if $game_map.map_id == id
  end
  return false
end


class Game_Player < Game_Character

	alias update_command_new_cycling update_command_new
	def update_command_new
		dir = Input.dir4
		# force down if on CYCLINGROAD
	if onCyclingRoad?
		dir=4 if dir==0 && !Input.press?(Input::B) #[X] holds position
	end    
	unless pbMapInterpreterRunning? || $game_temp.message_window_showing ||
           $game_temp.in_mini_update || $game_temp.in_menu
      # Move player in the direction the directional button is being pressed
      if @moved_last_frame ||
         (dir > 0 && dir == @lastdir && Graphics.frame_count - @lastdirframe > Graphics.frame_rate / 20)
        case dir
        when 2 then move_down
        when 4 then move_left
        when 6 then move_right
        when 8 then move_up
        end
      elsif dir != @lastdir
        case dir
        when 2 then turn_down
        when 4 then turn_left
        when 6 then turn_right
        when 8 then turn_up
        end
      end
    end
    # Record last direction input
    @lastdirframe = Graphics.frame_count if dir != @lastdir
    @lastdir      = dir
  end
end