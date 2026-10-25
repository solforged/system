bindkey -v

autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

for keymap in viins vicmd; do
  bindkey -M "$keymap" '^[[C' vi-forward-char
  bindkey -M "$keymap" '^[OC' vi-forward-char
  bindkey -M "$keymap" '^[[D' vi-backward-char
  bindkey -M "$keymap" '^[OD' vi-backward-char

  if (( $+widgets[atuin-up-search-$keymap] )); then
    bindkey -M "$keymap" '^[[A' "atuin-up-search-$keymap"
    bindkey -M "$keymap" '^[OA' "atuin-up-search-$keymap"
  else
    bindkey -M "$keymap" '^[[A' up-line-or-beginning-search
    bindkey -M "$keymap" '^[OA' up-line-or-beginning-search
  fi
  bindkey -M "$keymap" '^[[B' down-line-or-beginning-search
  bindkey -M "$keymap" '^[OB' down-line-or-beginning-search

  bindkey -M "$keymap" '^[[H' beginning-of-line
  bindkey -M "$keymap" '^[OH' beginning-of-line
  bindkey -M "$keymap" '^[[F' end-of-line
  bindkey -M "$keymap" '^[OF' end-of-line
  bindkey -M "$keymap" '^E' end-of-line
  bindkey -M "$keymap" '^F' vi-forward-char
  bindkey -M "$keymap" '^?' backward-delete-char
  bindkey -M "$keymap" '^H' backward-delete-char
  bindkey -M "$keymap" '^[[3~' delete-char

  bindkey -M "$keymap" '^[b' vi-backward-word
  bindkey -M "$keymap" '^[[1;3D' vi-backward-word
  bindkey -M "$keymap" '^[f' vi-forward-word-end
  bindkey -M "$keymap" '^[[1;3C' vi-forward-word-end
done

if (( $+widgets[atuin-search-viins] )); then
  bindkey -M viins '^R' atuin-search-viins
else
  bindkey -M viins '^R' history-incremental-search-backward
fi

if (( $+widgets[atuin-search-vicmd] )); then
  bindkey -M vicmd '^R' atuin-search-vicmd
else
  bindkey -M vicmd '^R' history-incremental-search-backward
fi

bindkey -M vicmd '/' vi-history-search-backward

(( $+widgets[autosuggest-accept] )) && bindkey '^ ' autosuggest-accept
