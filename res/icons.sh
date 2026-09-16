#!/bin/sh

# Renders the Aerium logo over an existing icon PNG, keeping its dimensions.
# Usage: icons.sh <path-to-png>
svg=$(dirname "$0")/aerium.svg
tile=$(dirname "$0")/aerium_tile.svg
w=$(identify -format %w "$1")


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
#
adaptive_pct=48
legacy_pct=54

render_tile() {
    rsvg-convert -w $w -h $w "$tile" -o "$1"
}

render_on_tile() {
    fg=$((w * $2 / 100))
    rsvg-convert -w $w -h $w "$tile" -o "$1.bg.png"
    rsvg-convert -w $fg -h $fg "$svg" -o "$1.fg.png"
    convert "$1.bg.png" "$1.fg.png" -gravity center -composite "$1"
    rm -f "$1.bg.png" "$1.fg.png"
}

render_over() {
    fg=$((w * $2 / 100))
    rsvg-convert -w $fg -h $fg "$svg" -o "$1.fg.png"
    convert -size ${w}x${w} xc:"$3" "$1.fg.png" -gravity center -composite "$1"
    rm -f "$1.fg.png"
}

case $(basename "$1") in
  layered_app_icon_background*)
    render_tile "$1" ;;
  layered_app_icon_foreground*)
    render_over "$1" $adaptive_pct none ;;
  *)
    render_on_tile "$1" $legacy_pct ;;
esac
echo "aerium icon: $1 (${w}px)"
