#!/bin/sh

# Renders the Aerium logo over an existing icon PNG, keeping its dimensions.
# Usage: icons.sh <path-to-png>
svg=$(dirname "$0")/aerium.svg
w=$(identify -format %w "$1")

# The field behind the mark.
#
# This was #FFFFFF, on the reasoning that a small mark on a plain light tile
# reads like the stock Phone, Messages and Camera icons next to it. Reported
# against that build (android issue 13, on a 1080x2400 / 392dpi Redmi Note
# 11S): "make it bigger and no white border, the current one is very goofy".
# It is the right call for a glyph - a monochrome outline needs a field to sit
# on. aerium.svg is not a glyph. It is a full-colour disc that is already its
# own tile, so putting it on a second tile draws a border around it, and the
# smaller the disc the more of that border there is to see.
#
# Now the darkest navy of the mark itself (#111C42, the third swirl arm), so
# the field is never a different colour from the thing on it. On a circular
# mask the disc covers it completely and it is not visible at all; on a
# squircle or square mask it fills the corners the disc cannot reach, in a
# colour those corners already touch. Either way nothing white is left to
# read as a border.
bg='#111C42'

# The logo is a circle that fills its whole 512 viewBox, so these percentages
# are the circle's diameter as a share of the icon's width.
#
# An adaptive icon is a 108dp canvas of which the launcher shows the middle
# 72dp, so a disc drawn at 72/108 = 66.7% has exactly the diameter of the
# visible circle. That is the largest the mark can be without the mask cutting
# into it, and it is what "bigger" means here: the previous 36% put the disc at
# 38.9dp inside a 72dp tile, a little over half the width and just under a
# third of the area, with the rest of the tile white.
#
# 68 rather than 66.7 so the disc passes the mask boundary by a fraction of a
# dp instead of landing on it. Masks are antialiased and launchers do not all
# use the same one; a disc that stops exactly at the edge can leave a hairline
# of background, and a hairline is the artifact this is meant to remove.
# Overshooting costs nothing, because what it clips is the outer edge of a disc
# whose colour the background already matches.
#
# themed_app_icon.xml stays at 0.40 and is not rendered here. It must not
# follow this change: the system tints that layer one flat colour, so a mark
# filling the visible circle tints the whole tile and the icon becomes a
# featureless blob - which is exactly what it did at 0.66 before. A monochrome
# layer wants to be a small glyph on a field; that reasoning still holds for
# it, and only for it. See the comment in that file.
#
# layered_app_icon_foreground.xml also stays at 0.36 and is likewise not
# rendered here. Its <group> is stripped entirely when theme.sh derives the
# search-widget drawable from it, so that scale reaches nothing that ships and
# changing it would only break theme.sh's translateY anchor.
#
# A legacy icon has no 108dp canvas - the whole PNG is what the launcher masks
# - so the equivalent of "fills the visible circle" is the full width of the
# file.
adaptive_pct=68
legacy_pct=100

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
    # plate of its own choosing. They get the painted field instead, so the
    # corners are ours rather than the launcher's - and at 100% the disc
    # inscribes the square exactly, so a circular mask lands on the disc edge
    # and the field only shows in the corners of a square one.
    render_over "$1" $legacy_pct "$bg" ;;
esac
echo "aerium icon: $1 (${w}px)"
