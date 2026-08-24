#!/bin/sh

# Renders the Aerium logo over an existing icon PNG, keeping its dimensions.
# Usage: icons.sh <path-to-png>
svg=$(dirname "$0")/aerium.svg
w=$(identify -format %w "$1")

# Darkest navy in aerium.svg (the outer arm of the swirl). Kept in one place
# so the icon can never go back to being framed in a colour the logo does not
# contain.
bg='#111C42'

# The logo is a circle that fills its whole 512 viewBox, so these percentages
# are the circle's diameter as a share of the icon's width.
#
# 40 matches the 0.40 scale in layered_app_icon_foreground.xml and
# themed_app_icon.xml. Those drawables are a 108dp canvas of which the
# launcher only shows the middle 72dp, so 40% of 108dp is 43.2dp - about 60%
# of what you actually see, which is where stock glyphs sit.
#
# A legacy icon has no such canvas: the whole PNG is what the launcher masks.
# So the same visual size is 60% of the file rather than 40%.
adaptive_pct=40
legacy_pct=60

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
    # Adaptive icon background layer: full bleed in the logo's darkest navy,
    # the same colour as the outer arm of the swirl.
    #
    # This used to be solid white, which is what put white corners on the
    # launcher icon. The background layer is what fills the launcher's mask,
    # the logo is a circle drawn at 40%, and every launcher mask is some
    # rounded square - so the four corners the circle cannot reach showed the
    # layer behind it. Painting them navy makes them continuous with the
    # swirl instead of framing it in white.
    convert -size ${w}x${w} xc:"$bg" "$1" ;;
  layered_app_icon_foreground*)
    # Adaptive icon foreground layer: the logo on transparency, because the
    # background layer above is what supplies the colour behind it.
    render_over "$1" $adaptive_pct none ;;
  *)
    # Everything else - layered_app_icon.png and app_icon.png - is a legacy,
    # non-adaptive icon: one square bitmap, no separate background layer.
    #
    # These used to be drawn on transparency too, which is the second source
    # of white corners and the one the background-layer fix above did not
    # reach. The logo is a circle, so a transparent square leaves four empty
    # corners, and a launcher given a legacy icon with transparency composites
    # it onto a white plate. Painting the same navy behind it means the
    # corners are part of the icon rather than whatever the launcher puts
    # under it.
    render_over "$1" $legacy_pct "$bg" ;;
esac
echo "aerium icon: $1 (${w}px)"
