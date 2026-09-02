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
    if onCyclingRoad? && Input.dir4 == 0 && !Input.press?(Input::B)
      # Forzamos temporalmente el valor que devuelve Input.dir4
      # para simular que el jugador presiona una dirección,
      # SIN tocar ni reemplazar la lógica original del engine
      # (así el hielo, surf, etc. siguen funcionando en todos los mapas).
      original_dir4 = Input.method(:dir4)
      Input.define_singleton_method(:dir4) { 4 }
      begin
        update_command_new_cycling
      ensure
        Input.define_singleton_method(:dir4, &original_dir4)
      end
    else
      update_command_new_cycling
    end
  end
end