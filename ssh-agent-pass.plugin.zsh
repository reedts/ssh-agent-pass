# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

# Copyright (c) 2022 Julian Bigge

# According to the Zsh Plugin Standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html

0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

# Then ${0:h} to get plugin's directory

if [[ ${zsh_loaded_plugins[-1]} != */ssh-agent-pass && -z ${fpath[(r)${0:h}]} ]] {
    fpath+=( "${0:h}" )
}

# Standard hash for plugins, to not pollute the namespace
typeset -gA Plugins
Plugins[SSH_AGENT_PASS_DIR]="${0:h}"

# -= Mostly taken from OMZ `ssh-agent` =-
#
# Get the filename to store/lookup the environment from
ssh_env_cache="$HOME/.ssh/environment-$SHORT_HOST"
hostname=`hostname`

function _start_agent() {
  # Check if ssh-agent is already running
  if [[ -f "$ssh_env_cache" ]]; then
    . "$ssh_env_cache" > /dev/null

    # Test if $SSH_AUTH_SOCK is visible
    zmodload zsh/net/socket
    if [[ -S "$SSH_AUTH_SOCK" ]] && zsocket "$SSH_AUTH_SOCK" 2>/dev/null; then
      return 0
    fi
  fi

  # Set a maximum lifetime for identities added to ssh-agent
  local lifetime
  zstyle -s :plugin:zinit:ssh-agent-pass lifetime lifetime

  # start ssh-agent and setup environment
  zstyle -t :plugin:zinit:ssh-agent-pass quiet || echo >&2 "Starting ssh-agent ..."
  ssh-agent -s ${lifetime:+-t} ${lifetime} | sed '/^echo/d' >! "$ssh_env_cache"
  chmod 600 "$ssh_env_cache"
  . "$ssh_env_cache" > /dev/null
}

function _add_identities() {
  local id file line sig lines
  local -a identities loaded_sigs loaded_ids not_loaded
  zstyle -a :plugin:zinit:ssh-agent-pass identities identities

  # check for .ssh folder presence
  if [[ ! -d "$HOME/.ssh" ]]; then
    return
  fi

  # if set add all identities in .ssh (prefixed with 'id_')
  if zstyle -t :plugin:zinit:ssh-agent-pass add-all; then
    identities+=($(ls -1 "$HOME/.ssh/id_"* | grep -v .pub))
  else
    # add default keys if no identities were set up via zstyle
    # this is to mimic the call to ssh-add with no identities
    if [[ ${#identities} -eq 0 ]]; then
      # key list found on `ssh-add` man page's DESCRIPTION section
      for id in id_rsa id_dsa id_ecdsa id_ed25519 identity; do
        # check if file exists
        [[ -f "$HOME/.ssh/$id" ]] && identities+=($id)
      done
    fi
  fi

  # get list of loaded identities' signatures and filenames
  if lines=$(ssh-add -l); then
    for line in ${(f)lines}; do
      loaded_sigs+=${${(z)line}[2]}
      loaded_ids+=${${(z)line}[3]}
    done
  fi

  # add identities if not already loaded
  for id in $identities; do
    # if id is an absolute path, make file equal to id
    [[ "$id" = /* ]] && file="$id" || file="$HOME/.ssh/$id"
    # check for filename match, otherwise try for signature match
    if [[ ${loaded_ids[(I)$file]} -le 0 ]]; then
      sig="$(ssh-keygen -lf "$file" | awk '{print $2}')"
      [[ ${loaded_sigs[(I)$sig]} -le 0 ]] && not_loaded+=("$file")
    fi
  done

  # abort if no identities need to be loaded
  if [[ ${#not_loaded} -eq 0 ]]; then
    return
  fi

  # pass extra arguments to ssh-add
  local args
  zstyle -a :plugin:zinit:ssh-agent-pass ssh-add-args args

  # if ssh-agent quiet mode, pass -q to ssh-add
  zstyle -t :plugin:zinit:ssh-agent-pass quiet && args=(-q $args)

  # try to open the identities with pass
  local pass_cmd
  # check if pass_cmd is overwritten, otherwise set to default ('pass')
  zstyle -s :plugin:zinit:ssh-agent-pass pass pass_cmd
  [[ -z "$pass_cmd" ]] && pass_cmd=pass

  if [[ -z "${commands[$pass_cmd]}" ]]; then
      echo >&2 "ssh-agent-pass: '$pass_cmd' has not been found."
  else
      # check if custom directory for password dir is configured, use default
      # value otherwise
      local pass_store_dir=${PASSWORD_STORE_DIR:-$HOME/.password-store}

      for id in $not_loaded; do
          local file_path="$pass_store_dir/ssh/$hostname/${id##*/}.gpg"
          if [[ -e "$file_path" ]]; then
              # use 'exec_cat' as SSH_ASKPASS command to be able to directly
              # pipe input from pass to the 'ssh-add' command
              SSH_ASKPASS_REQUIRE='force' \
              SSH_ASKPASS="${Plugins[SSH_AGENT_PASS_DIR]}/exec_cat" \
                ssh-add "${args[@]}" "$id" <<< `$pass_cmd ssh/$hostname/${id##*/}`
              [[ $? -eq 0 ]] && not_loaded=("${(@)not_loaded:#$id}")
          else
              echo >&2 "could not find password $file_path."
          fi
      done
  fi

  # use user specified helper to ask for password (ksshaskpass, etc)
  local helper
  zstyle -s :plugin:zinit:ssh-agent-pass helper helper

  if [[ -n "$helper" ]]; then
    if [[ -z "${commands[$helper]}" ]]; then
      echo >&2 "ssh-agent: the helper '$helper' has not been found."
    else
      SSH_ASKPASS="$helper" ssh-add "${args[@]}" ${^noj_loaded} < /dev/null
      return $?
        fi
  fi

  if [[ ${#not_loaded} -ne 0 ]]; then
    ssh-add "${args[@]}" ${^not_loaded}
  fi
}

# Add a nifty symlink for screen/tmux if agent forwarding is enabled
if zstyle -t :plugin:zinit:ssh-agent-pass agent-forwarding \
   && [[ -n "$SSH_AUTH_SOCK" && ! -L "$SSH_AUTH_SOCK" ]]; then
  ln -sf "$SSH_AUTH_SOCK" /tmp/ssh-agent-$USERNAME-screen
  agent_forwarding=true
else
  _start_agent
fi

# Don't add identities if lazy-loading is enabled
if ! zstyle -t :plugin:zinit:ssh-agent-pass lazy; then
  _add_identities
fi

unset agent_forwarding ssh_env_cache
unfunction _start_agent _add_identities

# Use alternate vim marks [[[ and ]]] as the original ones can
# confuse nested substitutions, e.g.: ${${${VAR}}}

# vim:ft=zsh:tw=80:sw=4:sts=4:et:foldmarker=[[[,]]]
