#-------------------------------------------------------------------------------
# Config Options
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox

  #---------------------------------------------------------------------------
  # Activar/desactivar los iconos de tipo
  #
  # true  = activados
  # false = desactivados
  #
  # Puedes cambiarlo durante el juego con:
  #
  # $TypeIconsEnabled = true
  # $TypeIconsEnabled = false
  #---------------------------------------------------------------------------
  TYPE_ICONS_ENABLED = true

  #---------------------------------------------------------------------------
  # Desplazamiento horizontal (en píxeles) de los iconos del RIVAL.
  # Positivo = hacia la derecha, negativo = hacia la izquierda.
  #
  # OPPONENT_SIDE_OFFSET_X        -> batallas dobles y triples
  # OPPONENT_SIDE_OFFSET_X_SINGLE -> batallas 1v1
  #---------------------------------------------------------------------------
  OPPONENT_SIDE_OFFSET_X        = 3
  OPPONENT_SIDE_OFFSET_X_SINGLE = 3

end

#-------------------------------------------------------------------------------
# Estado de los iconos
#-------------------------------------------------------------------------------

$TypeIconsEnabled = Battle::Scene::PokemonDataBox::TYPE_ICONS_ENABLED

#-------------------------------------------------------------------------------
# Main Script
#-------------------------------------------------------------------------------

class Battle::Scene::PokemonDataBox

  alias __types__initializeOtherGraphics initializeOtherGraphics unless method_defined?(:__types__initializeOtherGraphics)
  def initializeOtherGraphics(*args)

    if @battler.opposes?(0)
      @types_bitmap = AnimatedBitmap.new("Graphics/UI/Battle/icon_types_opponent")
    else
      @types_bitmap = AnimatedBitmap.new("Graphics/UI/Battle/icon_types")
    end

    @types_sprite = Sprite.new(viewport)

    #---------------------------------------------------------------------------
    # Los iconos siempre van en el lateral del databox (1v1, dobles y triples)
    #---------------------------------------------------------------------------

    side_size = @battler.battle.pbSideSize(@battler.index)
    height    = @databoxBitmap.height

    if @battler.opposes?(0)
      offset = (side_size > 1) ? OPPONENT_SIDE_OFFSET_X : OPPONENT_SIDE_OFFSET_X_SINGLE
      # Rival: pegado al lateral derecho + desplazamiento extra
      @types_x = @databoxBitmap.width - @types_bitmap.width + offset
    else
      @types_x = 0
    end

    @types_y = 4

    # El ancho nunca debe ser menor que el del icono (evita recortes)
    sprite_width = [@databoxBitmap.width - @types_x, @types_bitmap.width].max

    @types_sprite.bitmap = Bitmap.new(sprite_width, height)

    @sprites["types_sprite"] = @types_sprite

    __types__initializeOtherGraphics(*args)
  end

  #-----------------------------------------------------------------------------

  alias __types__dispose dispose unless method_defined?(:__types__dispose)
  def dispose(*args)
    __types__dispose(*args)
    @types_bitmap.dispose
  end

  #-----------------------------------------------------------------------------

  alias __types__set_x x= unless method_defined?(:__types__set_x)
  def x=(value)
    __types__set_x(value)
    @types_sprite.x = value + @types_x
  end

  #-----------------------------------------------------------------------------

  alias __types__set_y y= unless method_defined?(:__types__set_y)
  def y=(value)
    __types__set_y(value)
    @types_sprite.y = value + @types_y
  end

  #-----------------------------------------------------------------------------

  alias __types__set_z z= unless method_defined?(:__types__set_z)
  def z=(value)
    __types__set_z(value)
    @types_sprite.z = value - 1
  end

  #-----------------------------------------------------------------------------

  alias __databox__refresh refresh unless method_defined?(:__databox__refresh)
  def refresh

    self.bitmap.clear

    return if !@battler.pokemon

    __databox__refresh

    # No dibujar los iconos si están desactivados
    return unless $TypeIconsEnabled

    draw_type_icons
  end

  #-----------------------------------------------------------------------------

  def draw_type_icons

    @types_sprite.bitmap.clear

    width  = @types_bitmap.width
    height = @types_bitmap.height / GameData::Type.count

    types = @battler.pbTypes.clone

    #---------------------------------------------------------------------------
    # Illusion
    #---------------------------------------------------------------------------

    if @battler.effects[PBEffects::Illusion]

      illusion_types = @battler.effects[PBEffects::Illusion].types
      base_types = @battler.pokemon.types

      base_types.each { |type| types.delete(type) }

      illusion_types.reverse.each do |type|
        types.insert(0, type)
      end
    end

    #---------------------------------------------------------------------------
    # Dibujar tipos (siempre en vertical, al lado del databox)
    #---------------------------------------------------------------------------

    types.each_with_index do |type, i|

      type_number = GameData::Type.get(type).icon_position

      type_rect = Rect.new(
        0,
        type_number * height,
        width,
        height
      )

      @types_sprite.bitmap.blt(
        0,
        height * i,
        @types_bitmap.bitmap,
        type_rect
      )
    end
  end
end

#-------------------------------------------------------------------------------
# Refresh cuando cambian los tipos
#-------------------------------------------------------------------------------

class Battle::Battler

  alias __types__pbChangeTypes pbChangeTypes unless method_defined?(:__types__pbChangeTypes)
  def pbChangeTypes(*args)

    ret = __types__pbChangeTypes(*args)

    @battle.scene.sprites["dataBox_#{self.index}"]&.refresh

    return ret
  end

  #---------------------------------------------------------------------------

  alias __types__pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:__types__pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(*args)

    ret = __types__pbEffectsOnMakingHit(*args)

    @battle.scene.sprites["dataBox_#{args[1]&.index || 0}"]&.refresh
    @battle.scene.sprites["dataBox_#{args[2]&.index || 0}"]&.refresh

    return ret
  end
end