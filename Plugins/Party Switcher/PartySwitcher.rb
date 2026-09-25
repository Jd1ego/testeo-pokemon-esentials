#===============================================================================
# Party Switcher for Pokémon Essentials v21.1
# Basado en el Party Switcher de v19 (código de Pokémon Reborn).
#
# Cuando el equipo está lleno y el jugador obtiene un Pokémon (captura, regalo,
# NPC...), se le pregunta si quiere enviar a alguien del equipo al PC para que
# el nuevo Pokémon ocupe su lugar.
#===============================================================================
module PartySwitcher
  # Si es true, al elegir el Pokémon se puede abrir su pantalla de Resumen.
  SUMMARY_MENU = true

  # Muestra la pantalla de equipo y devuelve el índice elegido (-1 si se cancela).
  def self.choose_party_index(incoming)
    chosen = -1
    pbFadeOutIn(99999) {
      scene  = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $player.party)
      screen.pbStartScene(_INTL("Escoge un Pokémon."), false)
      loop do
        index = (SUMMARY_MENU) ? screen.pbChoosePokemonSummary : screen.pbChoosePokemon
        break if index < 0
        # No permitir dejar el equipo solo con huevos al recibir un huevo
        if incoming.egg? && !$player.party[index].egg? &&
           $player.party.count { |p| !p.egg? } <= 1
          pbMessage(_INTL("Ese es tu ultimo Pokémon!"))
          next
        end
        chosen = index
        break
      end
      screen.pbEndScene
    }
    return chosen
  end

  # Envía al PC el Pokémon de la posición +index+ y coloca +incoming+ en su lugar.
  # Devuelve el índice de la caja donde quedó, o -1 si no hubo espacio.
  def self.swap_into_party(index, incoming)
    outgoing = $player.party[index]
    box = $PokemonStorage.pbStoreCaught(outgoing)
    return -1 if box < 0
    outgoing.heal
    incoming.record_first_moves
    $player.party[index] = incoming
    return box
  end

  # Evita que el sistema de evolución post-combate confunda al Pokémon nuevo
  # con el que estaba en esa posición al empezar el combate.
  def self.sync_battle_data(index, incoming)
    return if !$game_temp
    {
      :party_levels_before_battle => incoming.level,
      :party_critical_hits_dealt  => 0,
      :party_direct_damage_taken  => 0
    }.each do |attr, value|
      next if !$game_temp.respond_to?(attr)
      list = $game_temp.send(attr)
      list[index] = value if list.is_a?(Array)
    end
  end
end

#===============================================================================
# Pantalla de equipo: elegir un Pokémon pudiendo ver su Resumen
#===============================================================================
class PokemonPartyScreen
  def pbChoosePokemonSummary
    ret = -1
    loop do
      @scene.pbSetHelpText(_INTL("Escoge un Pokémon."))
      pkmnid = @scene.pbChoosePokemon
      break if pkmnid < 0   # Cancelado
      pkmn = @party[pkmnid]
      commands = [_INTL("Escoger"), _INTL("Summary"), _INTL("Cancel")]
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands) if pkmn
      if command == 0
        ret = pkmnid
        break
      elsif command == 1
        @scene.pbSummary(pkmnid) {
          @scene.pbSetHelpText(_INTL("Escoge un Pokémon."))
        }
      end
    end
    return ret
  end
end

#===============================================================================
# Fuera de combate (regalos, NPCs, eventos, pbAddPokemon, etc.)
#===============================================================================
alias __partyswitcher_pbStorePokemon pbStorePokemon
def pbStorePokemon(pkmn)
  # Si hay hueco en el equipo o las cajas están llenas, comportamiento normal
  return __partyswitcher_pbStorePokemon(pkmn) if !$player.party_full? || pbBoxesFull?
  while pbConfirmMessageSerious(_INTL("Tu equipo está lleno. ¿Quieres enviar uno de tus pokémon al PC y hacer espacio para {1}?", pkmn.name))
    index = PartySwitcher.choose_party_index(pkmn)
    next if index < 0   # Cancelado: se vuelve a preguntar (así puede decir que no)
    outgoing = $player.party[index]
    box = PartySwitcher.swap_into_party(index, pkmn)
    if box < 0
      pbMessage(_INTL("No hay espacio para Pokémons!"))
      break
    end
    pbMessage(_INTL("{1} fue enviado a la caja \"{2}\".", outgoing.name, $PokemonStorage[box].name))
    return
  end
  # El jugador dijo que no: el nuevo Pokémon va al PC como siempre
  __partyswitcher_pbStorePokemon(pkmn)
end

#===============================================================================
# Durante un combate (capturas)
#===============================================================================
module Battle::CatchAndStoreMixin
  alias __partyswitcher_pbStorePokemon pbStorePokemon
  def pbStorePokemon(pkmn)
    return __partyswitcher_pbStorePokemon(pkmn) if !$player.party_full? || pbBoxesFull?
    while pbDisplayConfirm(_INTL("Tu equipo está lleno. ¿Quieres enviar uno de tus pokémon al PC y hacer espacio para {1}?", pkmn.name))
      index = PartySwitcher.choose_party_index(pkmn)
      next if index < 0
      # Apodo (igual que el original, que aquí no se ejecuta)
      if !pkmn.shadowPokemon?
        if (!$PokemonSystem.respond_to?(:givenicknames) || $PokemonSystem.givenicknames == 0) &&
           pbDisplayConfirm(_INTL("Would you like to give a nickname to {1}?", pkmn.name))
          nickname = @scene.pbNameEntry(_INTL("{1}'s nickname?", pkmn.speciesName), pkmn)
          pkmn.name = nickname
        end
      end
      outgoing = $player.party[index]
      box = PartySwitcher.swap_into_party(index, pkmn)
      if box < 0
        pbDisplayPaused(_INTL("No hay espacio para Pokémons!"))
        break
      end
      @initialItems[0][index] = pkmn.item_id if @initialItems && @initialItems[0]
      PartySwitcher.sync_battle_data(index, pkmn)
      pbDisplayPaused(_INTL("{1} fue enviado a la caja \"{2}\".", outgoing.name, $PokemonStorage[box].name))
      return
    end
    __partyswitcher_pbStorePokemon(pkmn)
  end
end
