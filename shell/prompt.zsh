# Adapt the packaged Jonathan theme without changing OS identity variables.
source "$ZDOTDIR/palette.zsh"
() {
  local -A defaults=("${(@kv)redflake_palette}")
  local key value
  if [[ -n $REDFLAKE_PALETTE ]]; then
    if [[ -f $REDFLAKE_PALETTE && -r $REDFLAKE_PALETTE ]]; then
      source "$REDFLAKE_PALETTE"
    else
      print -u2 -r -- "redflake-zsh: cannot read palette: $REDFLAKE_PALETTE"
    fi
  fi
  for key in ${(k)defaults}; do
    value=${redflake_palette[$key]}
    case $value in
      black|red|green|yellow|blue|magenta|cyan|white|default|\#[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]) ;;
      *)
        print -u2 -r -- "redflake-zsh: invalid palette color for $key: $value; using ${defaults[$key]}"
        redflake_palette[$key]=${defaults[$key]}
        ;;
    esac
    typeset -g "PR_${(U)key}=%B%F{${redflake_palette[$key]}}"
    typeset -g "PR_LIGHT_${(U)key}=%F{${redflake_palette[$key]}}"
  done
}

# Git indicators use the same palette, preserving the theme's symbols.
ZSH_THEME_GIT_PROMPT_PREFIX=" on %F{${redflake_palette[green]}}"
ZSH_THEME_GIT_PROMPT_ADDED="%F{${redflake_palette[green]}} %{%G✚%}"
ZSH_THEME_GIT_PROMPT_MODIFIED="%F{${redflake_palette[blue]}} %{%G✹%}"
ZSH_THEME_GIT_PROMPT_DELETED="%F{${redflake_palette[red]}} %{%G✖%}"
ZSH_THEME_GIT_PROMPT_RENAMED="%F{${redflake_palette[magenta]}} %{%G➜%}"
ZSH_THEME_GIT_PROMPT_UNMERGED="%F{${redflake_palette[yellow]}} %{%G═%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{${redflake_palette[cyan]}} %{%G✭%}"
return_code="%(?..%F{${redflake_palette[red]}}%? ↵ %{$reset_color%})"

# Keep the root indicator while displaying the chosen alias in every shell.
# Older Jonathan versions embed escaped line breaks inside the prompt string.
# Remove those continuations while preserving the prompt's intended newline.
PROMPT=${PROMPT//$'\\\n'/}
PROMPT=${PROMPT//'%(!.%SROOT%s.%n)'/'%(!.%SROOT%s .)Gebura'}
PROMPT=${PROMPT//'%m'/'Kali'}
PR_TITLEBAR=${PR_TITLEBAR//'%n'/'Gebura'}
PR_TITLEBAR=${PR_TITLEBAR//'%m'/'Kali'}
PR_STITLE=${PR_STITLE//zsh/'Gebura@Kali:%~'}
ZSH_THEME_TERM_TITLE_IDLE=${ZSH_THEME_TERM_TITLE_IDLE//'%n'/'Gebura'}
ZSH_THEME_TERM_TITLE_IDLE=${ZSH_THEME_TERM_TITLE_IDLE//'%m'/'Kali'}
# The pinned Oh My Zsh uses the short tab title for screen and tmux.
ZSH_THEME_TERM_TAB_TITLE_IDLE="Gebura@Kali:$ZSH_THEME_TERM_TAB_TITLE_IDLE"

# Jonathan sizes its border using the displayed identity. Override its hook so
# a different host username or hostname cannot shift the right-hand corner.
function theme_precmd {
  local TERMWIDTH=$(( COLUMNS - ${ZLE_RPROMPT_INDENT:-1} ))
  PR_FILLBAR=""
  PR_PWDLEN=""
  local promptsize=${#${(%):---(%(!.ROOT .)Gebura@Kali:%l)---()--}}
  local rubypromptsize=${#${(%)$(ruby_prompt_info)}}
  local pwdsize=${#${(%):-%~}}
  local venvpromptsize=${#$(virtualenv_prompt_info)}
  local condapromptsize=${#$(conda_prompt_info)}
  if (( promptsize + rubypromptsize + pwdsize + venvpromptsize + condapromptsize > TERMWIDTH )); then
    (( PR_PWDLEN = TERMWIDTH - promptsize ))
    (( PR_PWDLEN < 1 )) && PR_PWDLEN=1
  elif [[ "${langinfo[CODESET]}" = UTF-8 ]]; then
    PR_FILLBAR="\${(l:$(( TERMWIDTH - (promptsize + rubypromptsize + pwdsize + venvpromptsize + condapromptsize) ))::${PR_HBAR}:)}"
  else
    PR_FILLBAR="${PR_SHIFT_IN}\${(l:$(( TERMWIDTH - (promptsize + rubypromptsize + pwdsize + venvpromptsize + condapromptsize) ))::${altchar[q]:--}:)}${PR_SHIFT_OUT}"
  fi
  return 0
}
