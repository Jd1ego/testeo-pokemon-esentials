#===============================================================================
# Ability Description Fit v1.1  (Pokémon Essentials v21.1)
#
# Arregla que la descripción de la habilidad se corte en la página "SKILLS"
# del resumen del Pokémon.
#
# - Si el texto cabe en 2 líneas, no se toca nada (queda igual que siempre).
# - Si NO cabe, se muestra con la fuente normal del juego y se desplaza solo
#   hacia arriba, línea por línea, con una pausa en cada posición para poder
#   leerlo. Al llegar al final espera un momento y vuelve a empezar.
#
# No modifica ningún archivo original del juego: solo "envuelve" 4 métodos.
#===============================================================================
class PokemonSummary_Scene
  # ---- Configuración (puedes cambiar estos valores) --------------------------
  ABILITY_FIT_X        = 224   # Posición y ancho de la descripción (los mismos
  ABILITY_FIT_Y        = 322   # que usa el juego original). Si tu gráfico de
  ABILITY_FIT_WIDTH    = 282   # fondo es distinto, ajústalos aquí.
  ABILITY_FIT_LINES    = 2     # Líneas visibles a la vez
  ABILITY_FIT_HOLD     = 1.5   # Segundos de pausa en cada posición
  ABILITY_FIT_SPEED    = 2     # Píxeles por frame al desplazar (1, 2, 4, 8 o 16)
  ABILITY_FIT_LINE_H   = 32    # Alto de línea que usa Essentials (no cambiar)
  ABILITY_FIT_BASE     = Color.new(64, 64, 64)
  ABILITY_FIT_SHADOW   = Color.new(176, 176, 176)
  # ----------------------------------------------------------------------------

  # Cada vez que se dibuja una página, se elimina el scroll anterior.
  alias __abilityfit_drawPage drawPage
  def drawPage(page)
    abilityfit_dispose
    __abilityfit_drawPage(page)
  end

  # Tras dibujar la página de habilidades, comprobamos si la descripción cabe.
  alias __abilityfit_drawPageThree drawPageThree
  def drawPageThree
    __abilityfit_drawPageThree
    ability = @pokemon.ability
    abilityfit_setup(ability.description) if ability
  end

  # Cada frame: mueve el texto si corresponde.
  alias __abilityfit_pbUpdate pbUpdate
  def pbUpdate
    __abilityfit_pbUpdate
    abilityfit_tick
  end

  # Al cerrar la escena, libera también el bitmap del texto.
  alias __abilityfit_pbEndScene pbEndScene
  def pbEndScene
    bmp = @sprites && @sprites["abilitydesc"] && @sprites["abilitydesc"].bitmap
    __abilityfit_pbEndScene
    bmp.dispose if bmp && !bmp.disposed?
  end

  #-----------------------------------------------------------------------------

  def abilityfit_setup(text)
    overlay = @sprites["overlay"].bitmap
    pbSetSystemFont(overlay)
    chunks = getLineBrokenChunks(overlay, text, ABILITY_FIT_WIDTH, nil, true)
    total = abilityfit_line_count(chunks)
    return if total <= ABILITY_FIT_LINES   # Cabe: el dibujo original está bien
    # Borra la descripción original (solo esa zona, nada más)
    overlay.clear_rect(ABILITY_FIT_X - 4, ABILITY_FIT_Y,
                       Graphics.width - ABILITY_FIT_X + 4,
                       Graphics.height - ABILITY_FIT_Y)
    # Dibuja el texto COMPLETO en un bitmap aparte...
    bmp = Bitmap.new(ABILITY_FIT_WIDTH + 4, (total * ABILITY_FIT_LINE_H) + 4)
    pbSetSystemFont(bmp)
    renderLineBrokenChunksWithShadow(bmp, 0, 0, chunks, 0, ABILITY_FIT_BASE, ABILITY_FIT_SHADOW)
    # ...y lo muestra a través de una "ventana" de 2 líneas que se va moviendo.
    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.x = ABILITY_FIT_X
    sprite.y = ABILITY_FIT_Y
    sprite.src_rect = Rect.new(0, 0, bmp.width, ABILITY_FIT_LINES * ABILITY_FIT_LINE_H)
    @sprites["abilitydesc"] = sprite
    @abilityfit_y      = 0
    @abilityfit_max_y  = (total - ABILITY_FIT_LINES) * ABILITY_FIT_LINE_H
    @abilityfit_wait   = abilityfit_hold_frames
    @abilityfit_hidden = false
  end

  def abilityfit_tick
    return if !@sprites
    sprite = @sprites["abilitydesc"]
    return if !sprite || sprite.disposed?
    # Ocultar el texto si hay un cuadro de mensaje o el menú de marcas encima
    hidden = (@sprites["messagebox"] && @sprites["messagebox"].visible) ||
             (@sprites["markingbg"] && @sprites["markingbg"].visible) ? true : false
    if hidden != @abilityfit_hidden
      @abilityfit_hidden = hidden
      sprite.visible = !hidden
    end
    # Pausa
    if @abilityfit_wait > 0
      @abilityfit_wait -= 1
      return
    end
    # Movimiento
    if @abilityfit_y >= @abilityfit_max_y
      @abilityfit_y = 0   # Llegó al final: vuelve al principio
    else
      boundary = ((@abilityfit_y / ABILITY_FIT_LINE_H) + 1) * ABILITY_FIT_LINE_H
      @abilityfit_y = [@abilityfit_y + [ABILITY_FIT_SPEED, 1].max, boundary, @abilityfit_max_y].min
    end
    sprite.src_rect.y = @abilityfit_y
    # Pausa cada vez que se alinea con una línea (para poder leer)
    @abilityfit_wait = abilityfit_hold_frames if (@abilityfit_y % ABILITY_FIT_LINE_H) == 0
  end

  def abilityfit_dispose
    return if !@sprites
    sprite = @sprites["abilitydesc"]
    if sprite && !sprite.disposed?
      sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.dispose
    end
    @sprites.delete("abilitydesc")
  end

  def abilityfit_hold_frames
    return (Graphics.frame_rate * ABILITY_FIT_HOLD).round
  end

  def abilityfit_line_count(chunks)
    return 0 if chunks.empty?
    return (chunks.map { |c| c[2] }.max / ABILITY_FIT_LINE_H) + 1
  end
end