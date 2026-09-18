#===============================================================================
# Showdown Export  -  Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Exporta el equipo del jugador (y opcionalmente el PC) a un .txt con el
# formato de importación de Pokémon Showdown.
#===============================================================================
module ShowdownExport
  #-----------------------------------------------------------------------------
  # CONFIGURACIÓN
  #-----------------------------------------------------------------------------
  EXPORT_FOLDER     = "Showdown"
  INCLUDE_GENDER    = true
  INCLUDE_HAPPINESS = false
  WRITE_DETAIL_FILE = true
  SHOW_MESSAGE      = true

  #-----------------------------------------------------------------------------
  # Tablas de conversión
  #-----------------------------------------------------------------------------
  STATS = [
    [:HP,              "HP"],
    [:ATTACK,          "Atk"],
    [:DEFENSE,         "Def"],
    [:SPECIAL_ATTACK,  "SpA"],
    [:SPECIAL_DEFENSE, "SpD"],
    [:SPEED,           "Spe"]
  ].freeze

  NAME_FIXES = {
    "Nidoran♀" => "Nidoran-F",
    "Nidoran♂" => "Nidoran-M"
  }.freeze

  FORM_SUFFIX_OVERRIDES = {
    "Alolan Form"     => "Alola",
    "Galarian Form"   => "Galar",
    "Hisuian Form"    => "Hisui",
    "Paldean Form"    => "Paldea",
    "Combat Breed"    => "Paldea-Combat",
    "Blaze Breed"     => "Paldea-Blaze",
    "Aqua Breed"      => "Paldea-Aqua",
    "Female"          => "F",
    "Ice Rider"       => "Ice",
    "Shadow Rider"    => "Shadow"
  }.freeze

  HIDDEN_POWER_TYPES = %w[Fighting Flying Poison Ground Rock Bug Ghost Steel
                          Fire Water Grass Electric Psychic Ice Dragon Dark].freeze

  #-----------------------------------------------------------------------------
  # Utilidades de texto
  #-----------------------------------------------------------------------------
  def self.plain(text)
    return text.to_s.tr("áéíóúÁÉÍÓÚñÑüÜ", "aeiouAEIOUnNuU")
  end

  def self.clean_nickname(text)
    return text.to_s.gsub(/[()@\r\n\t]/, "").strip
  end

  def self.clean_filename(text)
    name = text.to_s.strip
    name = "Jugador" if name.empty?
    name = name.gsub(/[\\\/:*?"<>|]/, "_")
    name = name.gsub(/\s+/, "_")
    return name
  end

  # Convierte Symbol/ID de Essentials a formato Title Case de Showdown en inglés
  def self.id_to_english(sym)
    return "" if !sym
    return sym.to_s.split('_').map(&:capitalize).join(' ')
  end

  def self.nickname(pkmn)
    return "" if !pkmn.nicknamed?
    nick = clean_nickname(pkmn.name)
    return "" if nick.empty?
    return "" if nick.casecmp(pkmn.speciesName.to_s).zero?
    return "" if nick.casecmp(id_to_english(pkmn.species)).zero?
    return nick
  end

  #-----------------------------------------------------------------------------
  # Especie y formas
  #-----------------------------------------------------------------------------
  def self.form_suffix(form_name)
    form_name = form_name.to_s.strip
    return nil if form_name.empty?
    return FORM_SUFFIX_OVERRIDES[form_name] if FORM_SUFFIX_OVERRIDES.key?(form_name)
    if form_name =~ /\bMega\b/i
      letter = form_name[/\b([XY])\b/, 1]
      return letter ? "Mega-#{letter}" : "Mega"
    end
    cleaned = form_name.gsub(
      /\b(Forme?|Mode|Style|Cloak|Size|Breed|Pattern|Rotom|Kyurem|Necrozma|Normal|Standard|Face)\b/i, " "
    )
    cleaned = plain(cleaned.split(/\s+/).reject(&:empty?).join("-"))
    return cleaned.empty? ? nil : cleaned
  end

  def self.species_name(pkmn)
    data = pkmn.species_data
    # Extrae el nombre directamente desde el ID del simbolo en ingles
    eng_name = id_to_english(data.id)
    base = NAME_FIXES[eng_name] || plain(eng_name)
    return base if pkmn.form == 0
    
    # Extrae la forma en inglés si existe
    raw_form = data.pbs_data["FormName"] rescue nil
    suffix = form_suffix(raw_form || data.form_name)
    return suffix ? "#{base}-#{suffix}" : base
  end

  #-----------------------------------------------------------------------------
  # IVs, EVs, Hidden Power, Teratipo
  #-----------------------------------------------------------------------------
  def self.max_iv
    return defined?(Pokemon::IV_STAT_LIMIT) ? Pokemon::IV_STAT_LIMIT : 31
  end

  def self.iv_value(pkmn, stat_id)
    if pkmn.respond_to?(:ivMaxed) && pkmn.ivMaxed && pkmn.ivMaxed[stat_id]
      return max_iv
    end
    return pkmn.iv[stat_id].to_i
  end

  def self.hidden_power_type(pkmn)
    order = [:HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
    sum = 0
    order.each_with_index { |stat, i| sum += (iv_value(pkmn, stat) & 1) << i }
    return HIDDEN_POWER_TYPES[sum * 15 / 63]
  end

  def self.tera_type(pkmn)
    return nil if !pkmn.respond_to?(:tera_type)
    type = pkmn.tera_type
    return nil if !type
    return id_to_english(type)
  end

  def self.ev_line(pkmn)
    parts = []
    STATS.each do |id, abbr|
      value = pkmn.ev[id].to_i
      parts.push("#{value} #{abbr}") if value > 0
    end
    return parts.empty? ? nil : "EVs: " + parts.join(" / ")
  end

  def self.iv_line(pkmn)
    parts = []
    STATS.each do |id, abbr|
      value = iv_value(pkmn, id)
      parts.push("#{value} #{abbr}") if value != max_iv
    end
    return parts.empty? ? nil : "IVs: " + parts.join(" / ")
  end

  def self.move_names(pkmn)
    names = []
    pkmn.moves.each do |move|
      next if !move || !move.id
      name = plain(id_to_english(move.id))
      if move.id == :HIDDENPOWER
        type = hidden_power_type(pkmn)
        name += " #{type}" if type
      end
      names.push(name)
    end
    return names
  end

  #-----------------------------------------------------------------------------
  # Formato Pokémon Showdown
  #-----------------------------------------------------------------------------
  def self.header_line(pkmn)
    species = species_name(pkmn)
    nick    = nickname(pkmn)
    line    = nick.empty? ? species : "#{nick} (#{species})"
    if INCLUDE_GENDER
      line += " (M)" if pkmn.male?
      line += " (F)" if pkmn.female?
    end
    if pkmn.item
      line += " @ #{plain(id_to_english(pkmn.item_id))}"
    end
    return line
  end

  def self.pokemon_to_showdown(pkmn)
    lines = [header_line(pkmn)]
    if pkmn.ability
      lines.push("Ability: #{plain(id_to_english(pkmn.ability_id))}")
    end
    lines.push("Level: #{pkmn.level}") if pkmn.level != 100
    lines.push("Shiny: Yes") if pkmn.shiny?
    lines.push("Happiness: #{pkmn.happiness}") if INCLUDE_HAPPINESS
    tera = tera_type(pkmn)
    lines.push("Tera Type: #{tera}") if tera
    evs = ev_line(pkmn)
    lines.push(evs) if evs
    if pkmn.nature
      lines.push("#{id_to_english(pkmn.nature_id)} Nature")
    end
    ivs = iv_line(pkmn)
    lines.push(ivs) if ivs
    move_names(pkmn).each { |name| lines.push("- #{name}") }
    return lines.join("\n")
  end

  #-----------------------------------------------------------------------------
  # Informe detallado
  #-----------------------------------------------------------------------------
  def self.pokemon_to_detail(pkmn)
    species = species_name(pkmn)
    nick    = nickname(pkmn)
    title   = nick.empty? ? species : "#{nick} (#{species})"
    gender  = pkmn.male? ? "Macho" : (pkmn.female? ? "Hembra" : "Sin género")
    stats = {
      :HP => pkmn.totalhp, :ATTACK => pkmn.attack, :DEFENSE => pkmn.defense,
      :SPECIAL_ATTACK => pkmn.spatk, :SPECIAL_DEFENSE => pkmn.spdef, :SPEED => pkmn.speed
    }
    stat_text = STATS.map { |id, abbr| "#{abbr} #{stats[id]}" }.join(" / ")
    iv_text   = STATS.map { |id, abbr| "#{iv_value(pkmn, id)} #{abbr}" }.join(" / ")
    ev_text   = STATS.map { |id, abbr| "#{pkmn.ev[id].to_i} #{abbr}" }.join(" / ")
    ball = pkmn.respond_to?(:poke_ball) ? GameData::Item.try_get(pkmn.poke_ball) : nil
    lines = []
    lines.push("#{title} - Nv. #{pkmn.level}#{pkmn.shiny? ? ' [Shiny]' : ''}")
    lines.push("  Género:      #{gender}")
    lines.push("  Naturaleza:  #{pkmn.nature ? id_to_english(pkmn.nature_id) : '-'}")
    lines.push("  Habilidad:   #{pkmn.ability ? plain(id_to_english(pkmn.ability_id)) : '-'}")
    lines.push("  Objeto:      #{pkmn.item ? plain(id_to_english(pkmn.item_id)) : '-'}")
    tera = tera_type(pkmn)
    lines.push("  Teratipo:    #{tera}") if tera
    lines.push("  Stats:       #{stat_text}")
    lines.push("  IVs:         #{iv_text}")
    lines.push("  EVs:         #{ev_text}")
    lines.push("  Felicidad:   #{pkmn.happiness}")
    lines.push("  Ball:        #{ball ? plain(id_to_english(ball.id)) : '-'}") if ball
    lines.push("  Entrenador:  #{pkmn.owner.name}") if pkmn.owner
    lines.push("  Movimientos: #{move_names(pkmn).join(', ')}")
    return lines.join("\n")
  end

  #-----------------------------------------------------------------------------
  # Recogida de Pokémon
  #-----------------------------------------------------------------------------
  def self.party_pokemon
    return $player.party.reject { |pkmn| pkmn.nil? || pkmn.egg? }
  end

  def self.storage_pokemon
    list = []
    $PokemonStorage.maxBoxes.times do |b|
      box = $PokemonStorage[b]
      box.length.times do |i|
        pkmn = box[i]
        next if pkmn.nil? || pkmn.egg?
        list.push(pkmn)
      end
    end
    return list
  end

  #-----------------------------------------------------------------------------
  # Escritura de archivos
  #-----------------------------------------------------------------------------
  def self.write_files(prefix, list, stamp)
    Dir.mkdir(EXPORT_FOLDER) if !Dir.exist?(EXPORT_FOLDER)
    base = "#{EXPORT_FOLDER}/#{prefix}_#{stamp}"
    showdown_text = list.map { |pkmn| pokemon_to_showdown(pkmn) }.join("\n\n") + "\n"
    File.open("#{base}.txt", "w:UTF-8") { |f| f.write(showdown_text) }
    if WRITE_DETAIL_FILE
      detail_text = list.map { |pkmn| pokemon_to_detail(pkmn) }.join("\n\n") + "\n"
      File.open("#{base}_detalle.txt", "w:UTF-8") { |f| f.write(detail_text) }
    end
    return "#{base}.txt"
  end

  #-----------------------------------------------------------------------------
  # Punto de entrada
  #-----------------------------------------------------------------------------
  def self.export(include_pc = false)
    party = party_pokemon
    pc    = include_pc ? storage_pokemon : []
    if party.empty? && pc.empty?
      pbMessage(_INTL("No hay Pokémon para exportar."))
      return false
    end
    player = clean_filename($player.name)
    stamp  = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
    write_files("#{player}_Equipo", party, stamp) if !party.empty?
    write_files("#{player}_PC", pc, stamp) if !pc.empty?
    if SHOW_MESSAGE
      pbMessage(_INTL("¡Equipo exportado! {1} Pokémon guardados en la carpeta \"{2}\".",
                      party.length + pc.length, EXPORT_FOLDER))
    end
    return true
  rescue => e
    pbMessage(_INTL("Error al exportar el equipo: {1}", e.message))
    return false
  end
end

#===============================================================================
# Atajo para usar desde eventos (comando "Script")
#===============================================================================
def pbExportShowdown(include_pc = false)
  return ShowdownExport.export(include_pc)
end