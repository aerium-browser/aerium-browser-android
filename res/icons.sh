#!/bin/sh

# Renders the Aerium logo over an existing icon PNG, keeping its dimensions.
# Usage: icons.sh <path-to-png>
svg=$(dirname "$0")/aerium.svg
w=$(identify -format %w "$1")

# Darkest navy in aerium.svg (the outer arm of the swirl). Kept in one place
# so the icon can never go back to being framed in a colour the logo does not
# contain.
bg='#111C42'

case $(basename "$1") in
  layered_app_icon_background*)
    # Adaptive icon background layer: full bleed in the logo's darkest navy,
    # the same colour as the outer arm of the swirl.
    #
    # This used to be solid white, which is what put white corners on the
    # launcher icon. The background layer is what fills the launcher's mask,
    # the logo is a circle drawn at 66%, and every launcher mask is some
    # rounded square - so the four corners the circle cannot reach showed the
    # layer behind it. Painting them navy makes them continuous with the
    # swirl instead of framing it in white.
    convert -size ${w}x${w} xc:"$bg" "$1" ;;
  layered_app_icon*)
    # Adaptive icon foreground layer: the logo at 66%, on transparency.
    #
    # Also formerly white. A foreground layer is composited over the
    # background, so painting it opaque white hid the background entirely and
    # made the whole tile white no matter what the layer below said.
    fg=$((w * 66 / 100))
    rsvg-convert -w $fg -h $fg "$svg" -o "$1.fg.png"
    convert -size ${w}x${w} xc:none "$1.fg.png" -gravity center -composite "$1"
    rm -f "$1.fg.png" ;;
  *)
    # Plain app icon: full-size logo (circular artwork masks well)
    rsvg-convert -w "$w" -h "$w" "$svg" -o "$1" ;;
esac
echo "aerium icon: $1 (${w}px)"
