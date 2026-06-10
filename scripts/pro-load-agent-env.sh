#!/usr/bin/env bash
# pro-load-agent-env.sh — source from ~/.bashrc to expose AI provider keys.
#
# Reads ~/.authinfo (or ~/.authinfo.gpg if gpg is available) and exports
# the following variables when present, so opencode/pi/gptel can pick
# them up via their env-var-aware config fields:
#
#   machine api.aitunnel.ru login token ...     → AITUNNEL_KEY
#                                                + AITUNNEL_API_KEY
#   machine openrouter.ai    login token ...     → OPENROUTER_KEY
#                                                + OPENROUTER_API_KEY
#   machine api.openai.com   login openai ...    → OPENAI_API_KEY
#   machine api.mistral.ai   login token ...     → MISTRAL_API_KEY
#
# Files are read in order; the first one that exists and is readable wins.
# gpg-encrypted authinfo is decrypted once into a temp file owned 0600 and
# removed after parsing.
#
# Safe to source repeatedly: idempotent and silent on missing files.

# Be quiet on errors; never abort the user's shell.
# shellcheck disable=SC1090

# Don't re-run if already done in this shell.
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && return 0 2>/dev/null || true
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && exit 0

# Pick the first readable authinfo source.
_authinfo_path=""
if [ -r "$HOME/.authinfo" ]; then
  _authinfo_path="$HOME/.authinfo"
elif [ -r "$HOME/.authinfo.gpg" ] && command -v gpg >/dev/null 2>&1; then
  _authinfo_path="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$_authinfo_path'" EXIT
  if ! gpg --quiet --batch --decrypt "$HOME/.authinfo.gpg" > "$_authinfo_path" 2>/dev/null; then
    _authinfo_path=""
  fi
fi

[ -n "$_authinfo_path" ] || { export PRO_AGENT_ENV_LOADED=1; return 0 2>/dev/null || exit 0; }

# Map of (host:user) → space-separated list of env var names to set.
declare -A _pro_agent_targets=(
  ["api.aitunnel.ru:token"]="AITUNNEL_KEY AITUNNEL_API_KEY"
  ["openrouter.ai:token"]="OPENROUTER_KEY OPENROUTER_API_KEY"
  ["api.openai.com:openai"]="OPENAI_API_KEY"
  ["api.mistral.ai:token"]="MISTRAL_API_KEY MISTRAL_API_KEY"
)

# Parse authinfo: each non-comment, non-blank line is a sequence of
# key value pairs (machine HOST login USER password PASS ...).
while IFS= read -r line; do
  case "$line" in
    \#* | '') continue ;;
  esac

  # Pull out machine/login/password tokens without eval.
  host=""; user=""; pass=""
  tok=""
  for word in $line; do
    case "$tok$word" in
      machine)  tok="machine"  ; continue ;;
      login)    tok="login"    ; continue ;;
      password) tok="password" ; continue ;;
    esac
    case "$tok" in
      machine)  host="$word"  ; tok="" ;;
      login)    user="$word"  ; tok="" ;;
      password) pass="$word"  ; tok="" ;;
      *) tok="" ;;
    esac
  done
  [ -n "$host" ] && [ -n "$user" ] && [ -n "$pass" ] || continue

  key="${host}:${user}"
  if [ -n "${_pro_agent_targets[$key]:-}" ]; then
    already_set=0
    for v in ${_pro_agent_targets[$key]}; do
      # If the first env var in the list is already set, assume the rest are too.
      if [ "$v" = "${_pro_agent_targets[$key]%% *}" ] && [ -n "${!v:-}" ]; then
        already_set=1
        break
      fi
    done
    [ "$already_set" = 1 ] && continue
    for v in ${_pro_agent_targets[$key]}; do
      export "$v=$pass"
    done
  fi
done < "$_authinfo_path"

# Cleanup temp gpg output, if any.
if [ "${_authinfo_path}" != "$HOME/.authinfo" ] && [ -f "$_authinfo_path" ]; then
  rm -f "$_authinfo_path" || true
fi

unset _authinfo_path _pro_agent_targets host user pass tok key already_set v
export PRO_AGENT_ENV_LOADED=1
