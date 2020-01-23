########################################################################
# ssh-init.sh: ssh key initialization facilitator functions.
#
# To avoid the proliferation of ssh-agent processes on a machine, these
# functions share cached agent information in order to easily connect a
# running ssh-agent to multiple shells.
#
# Available functions:
#
# * ssh-init: connect the current shell to an ssh-agent if necessary,
#   then add a key from file to the keyring.
#
# * ssh-drop: Remove a key from the current ssh-agent.
#
# * ssh-release: disconnect the current shell from an ssh-agent.
#
# * ssh-ensure-agent: find an existing ssh-agent, or start a new one.
#   Not generally called separately.
#
# Common concepts:
#
# * <keyfile> A file containing a private key. Defaults to
#   ${SSH_INIT_KEYFILE} if non-null, otherwise empty.
#
# * <pubkeyfile> A file containing a public key. Defaults to
#   ${SSH_INIT_PUBKEYFILE} if non-null, otherwise deduced from
#   ${SSH_INIT_KEYFILE} or empty.
#
# * <cachefile> A file in which to store shared information on a running
#   ssh-agent. Defaults to ${SSH_INIT_CACHEFILE} if non-null, otherwise
#   ~/.ssh_cache.
#
# Common options:
#
# * -h
#   Long help.
#
# * -q
#   Quiet: suppress non-error screen output.
#
# * -c <cachefile>
#   Specify a particular cache file to use,
#
# Common environment variables.


# Find or start an ssh-agent .
function ssh-ensure-agent() {
  local quiet reconnect_only OPT OPTIND
  while getopts :hrq OPT; do
    case $OPT in
      q)
        (( quiet = 1 ))
        ;;
      r)
        (( reconnect_only = 1 ))
        ;;
      *)
        echo "usage: ${FUNCNAME[0]} [-qr] [--] [<cachefile>]"
        echo "usage: ${FUNCNAME[0]} -h"
        [[ "$OPT" = "h" ]] || return 2
        cat <<EOF

Ensure that we are connected to an ssh-agent: find and reconnect to a
running agent; otherwise start a new one.

OPTIONS
  -h
    This help.
  -r
    Reconnect only: do not start an agent if one is not there to find.
  -q
    Quiet: errors only.
ARGUMENTS
  [<cachefile>]
    Specify the cache file where we keep track of the current agent.
    Default \$SSH_INIT_CACHEFILE; fall back to ~/.ssh_cache
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  local cachefile=${1:-${SSH_INIT_CACHEFILE:-~/.ssh_cache}}
  if [[ -n "$SSH_AGENT_PID" ]] && [[ -r "$SSH_AUTH_SOCK" ]] && \
       kill -0 "$SSH_AGENT_PID" >/dev/null 2>&1; then
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: ssh-agent PID $SSH_AGENT_PID already connected."
    fi
  elif [[ -r "$cachefile" ]] && \
         eval `cat "$cachefile"` >/dev/null && \
         [[ -n "$SSH_AGENT_PID" ]] && [[ -r "$SSH_AUTH_SOCK" ]] && \
         kill -0 "$SSH_AGENT_PID" >/dev/null 2>&1; then
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: found and reconnected to existing agent PID $SSH_AGENT_PID."
    fi
  else
    unset SSH_AGENT_PID SSH_AUTH_SOCK # Possibly stale.
    if [[ -n "$cachefile" ]]; then
      rm -f "$cachefile"
    else
      echo "ERROR: vacuous cachefile name." 1>&2
      return 1
    fi
    if (( ${reconnect_only:-0} == 0 )); then # Start a new agent.
      unset reconnect
      unset SSH_AGENT_PID;
      mkdir -p `dirname "$cachefile"`
      touch "$cachefile" && \
        chmod 600 "$cachefile" && \
        ssh-agent -s > "$cachefile" 2>/dev/null
      if (( $? )); then
        echo "ERROR: unable to start ssh-agent." 1>&2
        return 1
      fi
      eval `cat "$cachefile"` >/dev/null 2>&1;
      if (( ${quiet:-0} == 0 )); then
        echo "INFO: started ssh-agent PID ${SSH_AGENT_PID}"
      fi
    else
      if (( ${quiet:-0} == 0 )); then
        echo "ERROR: no ssh-agent to which to reconnect." 1>&2
      fi
      return 1
    fi
  fi
  return 0
}

function ssh-init() {
  local force quiet OPT OPTIND OPTARG
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:fhq OPT; do
    case $OPT in
      c)
        cachefile="$OPTARG"
        ;;
      f)
        (( force = 1 ))
        ;;
      q)
        (( quiet = 1 ))
        ;;
      *)
        echo "usage: ${FUNCNAME[0]} [-c <cachefile>] [-f] [-q] [--] [<keyfile>]"
        echo "usage: ${FUNCNAME[0]} -h"
        [[ "$OPT" = "h" ]] || return 2
        cat <<EOF

Find or start an ssh-agent and load the specified (or default) key.

OPTIONS
  -c <cachefile>
    Specify the cache file where we keep track of the current agent.
    Default \$SSH_INIT_CACHEFILE; fall back to ~/.ssh_cache
  -f
    Force the re-addition of a key even if we think we already have it.
  -h
    This help.
  -q
    Quiet: errors only.
ARGUMENTS
  [<keyfile>]
    The file from which to load keys.
    Default \$SSH_INIT_KEYFILE; fall back to ssh-add default.
ENVIRONMENT
  SSH_INIT_KEYFILE: default value for <keyfile>
  SSH_INIT_CACHEFILE: default value for <cachefile>
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  local keyfile=${1:-${SSH_INIT_KEYFILE}}
  if [[ -n "${keyfile}" ]] && \
       [[ -f "${keyfile}" ]] && \
       [[ -r "${keyfile}" ]]; then
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: using keyfile ${keyfile}."
    fi
  fi
  ssh-ensure-agent ${quiet:+-q }"$cachefile" || return $?
  local found_key fingerprint hashtype output status
  if [[ -n "$keyfile" ]]; then
    fingerprint=$(ssh-keygen -l -f "$keyfile")
    fingerprint=${fingerprint#* }
    fingerprint=${fingerprint%% *}
    hashtype=${fingerprint%:*}
    ssh-add -l ${hashtype:+-E $hashtype } 2>/dev/null | \
      grep -e '\b'"$fingerprint"'\b' \
           >/dev/null 2>&1 && (( found_key = 1 )) || :
  fi
  if (( ${found_key:-0} == 0 )) || (( ${force:-0} )); then
    output=$(ssh-add ${keyfile:+"$keyfile"} 2>&1)
    status=$?
    if (( ${status:-0} )); then
      echo "ERROR: $output" 1>&2
      return $status
    elif (( ${quiet:-0} == 0 )); then
      echo "INFO: $output"
    fi
  elif (( ${quiet:-0} == 0 )); then
    echo "INFO: key with fingerprint $fingerprint is already present."
  fi
}

function ssh-drop() {
  local quiet OPT OPTIND OPTARG
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:hq OPT; do
    case $OPT in
      c)
        cachefile="$OPTARG"
        ;;
      q)
        (( quiet = 1 ))
        ;;
      *)
        echo "usage: ${FUNCNAME[0]} [-c <cachefile>] [-q] [--] [<pubkeyfile>...]"
        echo "usage: ${FUNCNAME[0]} -h"
        [[ "$OPT" = "h" ]] || return 2
        cat <<EOF

Drop keys in <pubkeyfile>... from the running agent.

OPTIONS
  -c <cachefile>
    Specify the cache file where we keep track of the current agent.
    Default \$SSH_INIT_CACHEFILE; fall back to ~/.ssh_cache
  -h
    This help.
  -q
    Quiet: errors only.
ARGUMENTS
  [<pubkeyfile>]
    The public key file from which to drop keys.
    Default \$SSH_INIT_PUBKEYFILE; fall back to deducing from
    \$SSH_INIT_KEYFILE, then ssh-add default credentials.
ENVIRONMENT
  SSH_INIT_PUBKEYFILE: default value for <pubkeyfile>
  SSH_INIT_CACHEFILE: default value for <cachefile>
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  (( $# )) || set -- ${SSH_INIT_PUBKEYFILE:-${SSH_INIT_KEYFILE%.dat}}
  if ssh-ensure-agent -q -r "${cachefile}"; then
    output=$(ssh-add -d "${@}" 2>&1)
    status=$?
    if (( ${status:-0} )); then
      echo "ERROR: $output" 1>&2
      return $status
    elif (( ${quiet:-0} == 0 )); then
      echo "INFO: $output"
    fi
  elif (( ${quiet:-0} == 0 )); then
    echo "INFO: no running ssh-agent: nothing to drop."
  fi
}

function ssh-release() {
  local force quiet OPT OPTIND OPTARG
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:khq OPT; do
    case $OPT in
      c)
        cachefile="$OPTARG"
        ;;
      k)
        (( want_kill = 1 ))
        ;;
      q)
        (( quiet = 1 ))
        ;;
      *)
        echo "usage: ${FUNCNAME[0]} [-c <cachefile>] [-kq] [--]"
        echo "usage: ${FUNCNAME[0]} -h"
        [[ "$OPT" = "h" ]] || return 2
        cat <<EOF

Disconnect a running ssh-agent from the current shell or kill it entirely.

OPTIONS
  -c <cachefile>
    Specify the cache file where we keep track of the current agent.
    Default \$SSH_INIT_CACHEFILE; fall back to ~/.ssh_cache.
    Ignored without -k.
  -k
    Kill the running agent. If SSH_AGENT_PID is not set, find it using
    <cachefile>.
  -h
    This help.
  -q
    Quiet: errors only.
ENVIRONMENT
  SSH_INIT_CACHEFILE: default value for <cachefile>
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  if (( ${want_kill:-0} )); then
    ssh-ensure-agent -q -r "${cachefile}"
    if (( $? == 0 )); then
      ssh-agent -k 2>/dev/null >"${cachefile}"
      if (( $? )); then
        echo "ERROR: unable to kill ssh-agent PID $SSH_AGENT_PID." 1>&2
        return 1
      fi
      if (( ${quiet:-0} == 0 )); then
        echo "INFO: killed running ssh-agent PID $SSH_AGENT_PID."
      fi
      eval `cat "${cachefile}"` >/dev/null 2>&1
      rm -f "${cachefile}"
    elif (( ${quiet:-0} == 0 )); then
      echo "INFO: no running ssh-agent."
    fi
  elif [[ -n "$SSH_AGENT_PID" ]]; then
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: disconnected ssh-agent PID $SSH_AGENT_PID from shell."
    fi
    unset SSH_AGENT_PID SSH_AUTH_SOCK
  elif (( ${quiet:-0} == 0 )); then
    echo "INFO: no connected ssh-agent in this shell."
  fi
}
