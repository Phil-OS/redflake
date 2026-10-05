# Shared prompt, Git status, and syntax-highlighting colors.
# Use black, red, green, yellow, blue, magenta, cyan, white, default,
# or a quoted RGB hex value such as '#c0392b'. Hex needs a truecolor terminal.
# The Jonathan theme's grey is bold black; keep it as a separate editable role.
# Edit this file, then start a new nix develop session to rebuild the palette.
# For personal overrides, put assignments such as redflake_palette[cyan]=red
# in a zsh file and run REDFLAKE_PALETTE=/absolute/path/palette.zsh nix develop.
typeset -gA redflake_palette=(
  black   black
  red     red
  green   green
  yellow  yellow
  blue    blue
  magenta magenta
  cyan    cyan
  white   white
  grey    black
)
