#===============================================================================
# * Roaming Icon - by FL (Convertido a Plugin Plug&Play para v21.1)
#===============================================================================

if !PluginManager.installed?("Roaming Icon")
  PluginManager.register({                                                 
    :name    => "Roaming Icon",                                        
    :version => "1.1.4",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=438704",             
    :credits => "FL"
  })
end

class PokemonRegionMap_Scene
  
  # 1. EL ALIAS: Inyecta el código automáticamente sin modificar UI_RegionMap
  alias pbStartScene_roaming_icons pbStartScene
  def pbStartScene(*args)
    pbStartScene_roaming_icons(*args)
    draw_roaming_position(2) # <--- Forzamos directamente la Región 2
  end

  # 2. LA LÓGICA ORIGINAL DE FL (Adaptada)
  def draw_roaming_position(mapindex)
    icon_index = 0
    for roam_pos in $PokemonGlobal.roamPosition
      active = $game_switches[Settings::ROAMING_SPECIES[roam_pos[0]][2]] && (
        $PokemonGlobal.roamPokemon.size <= roam_pos[0] || 
        $PokemonGlobal.roamPokemon[roam_pos[0]]!=true
      )
      next if !active
      roam_town_map_pos = GameData::MapMetadata.try_get(roam_pos[1])&.town_map_position
      next if mapindex!=roam_town_map_pos&.[](0)
      
      x = roam_town_map_pos[1]
      y = roam_town_map_pos[2]
      @sprites["roaming#{icon_index}"] = IconSprite.new(0,0,@viewport)
      @sprites["roaming#{icon_index}"].setBitmap(
        get_roaming_icon(Settings::ROAMING_SPECIES[roam_pos[0]][0])
      )
      
      @sprites["roaming#{icon_index}"].x = -SQUARE_WIDTH/2+(x*SQUARE_WIDTH)+(
        Graphics.width-@sprites["map"].bitmap.width
      )/2
      @sprites["roaming#{icon_index}"].y = -SQUARE_HEIGHT/2+(y*SQUARE_HEIGHT)+(
        Graphics.height-@sprites["map"].bitmap.height
      )/2
      icon_index+=1
    end
  end
  
  def get_roaming_icon(species)
    species_data = GameData::Species.try_get(species)
    return nil if !species_data
    path = "Graphics/Pokemon/Map icons/"
    if species_data.form > 0
      ret = pbResolveBitmap(sprintf("%s%s_%d",path, species_data.species, species_data.form))
      return ret if ret
    end
    ret = pbResolveBitmap(sprintf("%s%s", path, species_data.species))
    return ret if ret
    return pbResolveBitmap(path+"000")
  end

  # Compatibilidad de variables de cuadrícula
  SQUARE_WIDTH = SQUAREWIDTH if !defined?(SQUARE_WIDTH)
  SQUARE_HEIGHT = SQUAREHEIGHT if !defined?(SQUARE_HEIGHT)
end