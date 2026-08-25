#!/bin/sh

# Renders the Aerium logo over an existing icon PNG, keeping its dimensions.
# Usage: icons.sh <path-to-png>
svg=$(dirname "$0")/aerium.svg
w=$(identify -format %w "$1")

# The field the logo sits on. White, so the colour icon reads the way the
# themed one does: a small mark centred on a plain light tile, like the stock
# Phone, Messages and Camera icons next to it.
#
# White here is not the white-corner bug coming back. That bug was a logo
# scaled to fill the whole tile, drawn on transparency, so all that showed of
# the background was four mismatched corners - an artifact. This is one flat
# field behind a mark that no longer reaches the edges, which is a deliberate
# and uniform look. What matters is that the field is painted at all: a legacy
# icon left transparent gets dropped onto whatever plate the launcher supplies,
# which is not a choice we control.
bg='#FFFFFF'

# The logo is a circle that fills its whole 512 viewBox, so these percentages
# are the circle's diameter as a share of the icon's width.
#
# 36 matches the 0.36 scale in layered_app_icon_foreground.xml. That drawable
# is a 108dp canvas of which the launcher only shows the middle 72dp, so 36%
# of 108dp is 38.9dp - a little over half of what you actually see.
#
# themed_app_icon.xml stays at 0.40 and is not rendered here. The two differ on
# purpose: a flat tint lets the low-alpha edges of the monochrome fade into the
# background, while the colour logo is opaque to its edge, so equal geometry
# read as unequal size. See the comment in themed_app_icon.xml.
#
# A legacy icon has no 108dp canvas: the whole PNG is what the launcher masks.
# So the same on-screen size is 38.9/72 of the file, i.e. 54% rather than 36%.
adaptive_pct=36
legacy_pct=54

# Draws the logo at $2 percent of the icon width, centred on background $3.
# Pass 'none' for a transparent background.
render_over() {
    fg=$((w * $2 / 100))
    rsvg-convert -w $fg -h $fg "$svg" -o "$1.fg.png"
    convert -size ${w}x${w} xc:"$3" "$1.fg.png" -gravity center -composite "$1"
    rm -f "$1.fg.png"
}

case $(basename "$1") in
  layered_app_icon_background*)
    # Adaptive icon background layer: one flat field, full bleed. This is
    # what fills the launcher's mask, whatever shape that mask happens to be,
    # so the tile is this colour edge to edge and the foreground layer only
    # has to carry the logo.
    convert -size ${w}x${w} xc:"$bg" "$1" ;;
  layered_app_icon_foreground*)
    # Adaptive icon foreground layer: the logo on transparency, because the
    # background layer above is what supplies the colour behind it.
    render_over "$1" $adaptive_pct none ;;
  *)
    # Everything else - layered_app_icon.png and app_icon.png - is a legacy,
    # non-adaptive icon: one square bitmap, no separate background layer.
    #
    # These used to be drawn on transparency, which is what left four empty
    # corners around a circular logo and let the launcher fill them with a
    # plate of its own choosing. They now get the same painted field as the
    # adaptive background layer, so the two kinds of icon match and the tile
    # is ours rather than the launcher's.
    render_over "$1" $legacy_pct "$bg" ;;
esac
echo "aerium icon: $1 (${w}px)"
