#===============================================================================
# Módulo de Zona de Entrenamiento Dinámica
#===============================================================================
module TrainingZone
  # --- CONFIGURACIÓN ---
  SWITCH_ID         = 101 
  REGION_DEX        = 2   
  PARTY_SIZE_SINGLE = 4   
  PARTY_SIZE_DOUBLE = 2   
  LEVEL_GAP         = 20  

  class << self
    attr_accessor :current_party_size
    attr_accessor :family_levels_cache
  end

  # Construye el mapa de niveles mínimos hacia ADELANTE (desde el bebé)
  def self.build_family_levels(baby_species)
    levels = {}
    levels[baby_species] = 1
    queue = [baby_species]
    
    while queue.length > 0
      curr = queue.shift
      curr_lvl = levels[curr]
      
      curr_data = GameData::Species.get(curr)
      curr_data.evolutions.each do |evo|
        target = evo[0]
        method = evo[1]
        param  = evo[2]
        
        # Por defecto, suma LEVEL_GAP si evoluciona por piedra/intercambio
        next_lvl = curr_lvl + LEVEL_GAP
        # Si es por nivel oficial, usa ese nivel exacto
        if method.to_s.include?("Level") && param.is_a?(Integer) && param > curr_lvl
          next_lvl = param
        end
        
        # Guarda el nivel si es el más bajo encontrado para esta especie (útil en casos raros)
        if !levels[target] || next_lvl < levels[target]
          levels[target] = next_lvl
          queue.push(target)
        end
      end
    end
    return levels
  end

  # Obtiene y cachea los árboles evolutivos de todo el juego al cargar
  def self.get_all_family_levels
    return @family_levels_cache if @family_levels_cache
    
    @family_levels_cache = {}
    GameData::Species.each do |s|
      next if s.form != 0
      baby = s.get_baby_species
      next if @family_levels_cache.has_key?(baby) # Evita trabajo doble
      
      @family_levels_cache[baby] = build_family_levels(baby)
    end
    
    return @family_levels_cache
  end
end

#===============================================================================
# Llamadas Globales para Eventos (Mantenidas de Essentials v21.1)
#===============================================================================
def pbTrainingSingle(trainer_type, trainer_name, end_speech)
  TrainingZone.current_party_size = TrainingZone::PARTY_SIZE_SINGLE
  $game_switches[TrainingZone::SWITCH_ID] = true
  TrainerBattle.start(trainer_type, trainer_name)
end

def pbTrainingDouble(type1, name1, speech1, type2, name2, speech2)
  TrainingZone.current_party_size = TrainingZone::PARTY_SIZE_DOUBLE
  $game_switches[TrainingZone::SWITCH_ID] = true
  TrainerBattle.start(type1, name1, type2, name2)
end

#===============================================================================
# Generador Aleatorio de Equipos (Se activa al cargar un entrenador)
#===============================================================================
EventHandlers.add(:on_trainer_load, :training_zone_override, proc { |trainer|
  next if !$game_switches[TrainingZone::SWITCH_ID]

  # 1. Calcular el nivel máximo del equipo del jugador
  max_lvl = 1
  if $player && $player.party
    $player.party.each do |pkmn|
      next if pkmn.egg?
      max_lvl = pkmn.level if pkmn.level > max_lvl
    end
  end

  # 2. Obtener todos los árboles genealógicos
  all_families = TrainingZone.get_all_family_levels
  especies_maximas = []

  # 3. Filtrar la mejor etapa evolutiva legal para el nivel actual por cada familia
  all_families.each do |baby_id, family_map|
    miembros_legales = []
    
    family_map.each do |species_id, min_lvl|
      s_data = GameData::Species.get(species_id)
      next if s_data.form != 0
      next if s_data.has_flag?("Legendary") || s_data.has_flag?("Mythical") || s_data.has_flag?("UltraBeast")
      next if pbGetRegionalNumber(TrainingZone::REGION_DEX, species_id) == 0
      next if min_lvl > max_lvl
      
      miembros_legales.push({ id: species_id, lvl: min_lvl })
    end
    
    next if miembros_legales.empty?
    
    # De los legales de esta familia, ¿cuál es el nivel más alto alcanzado?
    highest_lvl = miembros_legales.map { |m| m[:lvl] }.max
    
    # Guardar todos los miembros que empaten en ese nivel máximo (ej. Eeveelutions)
    miembros_legales.each do |m|
      especies_maximas.push(m[:id]) if m[:lvl] == highest_lvl
    end
  end

  especies_maximas.push(:RATTATA) if especies_maximas.empty?

  # 4. Asignar el equipo
  trainer.party.clear
  party_size = TrainingZone.current_party_size || TrainingZone::PARTY_SIZE_SINGLE

  party_size.times do
    especie_elegida = especies_maximas.sample
    pkmn_generado = Pokemon.new(especie_elegida, max_lvl)
    trainer.party.push(pkmn_generado)
  end
})

#===============================================================================
# Seguro de apagado (Evita bugs si pierdes o termina la batalla)
#===============================================================================
EventHandlers.add(:on_end_battle, :turn_off_training_multiplier,
  proc { |_decision, _can_lose|
    $game_switches[TrainingZone::SWITCH_ID] = false if $game_switches
  }
)