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
# * ssh-drop: remove a key from the current ssh-agent.
#
# * ssh-release: disconnect or kill ssh-agent(s).
#
# * ssh-ensure-agent: find an existing ssh-agent, or start a new one. May be
#   invoked explicitly, but more usually used by the above functions.
#
# * ssh-init-version: print the current version of ssh-init.sh. May be invoked
#   explicitly, but usually used to provide output for -V option to the other
#   functions.
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
# Commonly-available options:
#
# * -h
#     Long help.
#
# * -q
#     Quiet: suppress non-error screen output.
#
# * -c <cachefile>
#     Specify a particular cache file to use.
#
# * -V
#     Version number for ssh-init.sh (common to all functions).
#
# * -v
#     Verbose (negates -q or ${ssh_init_quiet})
#
# Commonly used environment variables:
#
# * SSH_INIT_PUBKEYFILE
#    Default value for <pubkeyfile>.
#
# * SSH_INIT_KEYFILE
#     Default value for <keyfile>.
#
# * SSH_INIT_CACHEFILE
#     Default value for <cachefile>.
#
# Common shell variables:
#
# * ssh_init_quiet
#   If this exists and is non-empty, default to quiet operation. Use -v
#   to restore normal operation for particular functions.
########################################################################

# Print version information.
function ssh-init-version() {
  local version="1.01.00"
  local date="2020-01-24"
  local author="Chris Green, FNAL"
  local msg="ssh-init.sh version ${version}, ${date} - ${author}"
  if [[ -n "${FUNCNAME[1]}" ]]; then
    echo "${FUNCNAME[1]} (${msg})."
  else
    echo "${msg}."
  fi
}

# Find or start an ssh-agent .
function ssh-ensure-agent() {
  local quiet reconnect_only OPT OPTIND
  # Only honor ssh_init_quiet if we're a top-level call.
  [[ "${FUNCNAME[1]}" == ssh-* ]] || quiet=${ssh_init_quiet:+1}
  while getopts :hrqVv OPT; do
    case $OPT in
      q)
        (( quiet = 1 ))
        ;;
      r)
        (( reconnect_only = 1 ))
        ;;
      V)
        ssh-init-version
        return 2
        ;;
      v)
        (( quiet = 0 ))
        ;;
      *)
        echo "usage: ${FUNCNAME[0]} [-q|-v] [-r] [--] [<cachefile>]"
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
  -V
    Version number for ssh-init.sh (common to all functions).
  -v
    Verbose (negates -q or ${ssh_init_quiet})

ARGUMENTS
  [<cachefile>]
    Specify the cache file where we keep track of the current agent.
    Default \$SSH_INIT_CACHEFILE; fall back to ~/.ssh_cache

ENVIRONMENT
  SSH_INIT_CACHEFILE
    Default value for <cachefile>.
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
  local force OPT OPTIND OPTARG
  local quiet=${ssh_init_quiet:+1}
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:fhqVv OPT; do
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
      V)
        ssh-init-version
        return 2
        ;;
      v)
        (( quiet = 0 ))
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
  -V
    Version number for ssh-init.sh (common to all functions).
  -v
    Verbose (negates -q or ${ssh_init_quiet})

ARGUMENTS
  [<keyfile>]
    The file from which to load keys.
    Default \$SSH_INIT_KEYFILE; fall back to ssh-add default.

ENVIRONMENT
  SSH_INIT_KEYFILE
    Default value for <keyfile>.
  SSH_INIT_CACHEFILE
    Default value for <cachefile>.
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

# Drop the specified key from the current agent.
function ssh-drop() {
  local OPT OPTIND OPTARG
  local quiet=${ssh_init_quiet:+1}
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:hqVv OPT; do
    case $OPT in
      c)
        cachefile="$OPTARG"
        ;;
      q)
        (( quiet = 1 ))
        ;;
      V)
        ssh-init-version
        return 2
        ;;
      v)
        (( quiet = 0 ))
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
  -V
    Version number for ssh-init.sh (common to all functions).
  -v
    Verbose (negates -q or ${ssh_init_quiet})

ARGUMENTS
  [<pubkeyfile>]
    The public key file from which to drop keys.
    Default \$SSH_INIT_PUBKEYFILE; fall back to deducing from
    \$SSH_INIT_KEYFILE, then ssh-add default credentials.

ENVIRONMENT
  SSH_INIT_PUBKEYFILE
    Default value for <pubkeyfile>.
  SSH_INIT_KEYFILE
    Fallback to deduce default value for <pubkeyfile>.
  SSH_INIT_CACHEFILE
    Default value for <cachefile>.
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  (( $# )) || set -- ${SSH_INIT_PUBKEYFILE:-${SSH_INIT_KEYFILE%.dat}}
  if ssh-ensure-agent -q -r "${cachefile}"; then
    output=$(ssh-add -d "${@}" 2>&1)
    local status=$?
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

# Disconnect or kill ssh-agent(s).
function ssh-release() {
  local killall want_kill OPT OPTIND OPTARG
  local quiet=${ssh_init_quiet:+1}
  local cachefile=${SSH_INIT_CACHEFILE:-~/.ssh_cache}
  while getopts :c:kKhqVv OPT; do
    case $OPT in
      c)
        cachefile="$OPTARG"
        ;;
      k)
        (( want_kill = 1 ))
        ;;
      K)
        (( want_kill = 1 )) # Clean up records in this shell if appropriate.
        (( killall = 1 ))
        ;;
      q)
        (( quiet = 1 ))
        ;;
      V)
        ssh-init-version
        return 2
        ;;
      v)
        (( quiet = 0 ))
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
    Ignored without -[kK].
  -K
    Kill *all* ssh-agents owned by you (assumes -k). Use with caution!
  -k
    Kill the ssh-agent known to the shell or cached in <cachefile>. Appropriate
    accounting will be done in the environment and/or <cachefile>.
  -h
    This help.
  -q
    Quiet: errors only.
  -V
    Version number for ssh-init.sh (common to all functions).
  -v
    Verbose (negates -q or ${ssh_init_quiet})

ENVIRONMENT
  SSH_INIT_CACHEFILE
    Default value for <cachefile>.
EOF
        return 1
    esac
  done
  shift $(( OPTIND - 1 ))
  local killed_agent
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
      (( killed_agent = ${SSH_AGENT_PID} ))
      eval `cat "${cachefile}"` >/dev/null 2>&1
      rm -f "${cachefile}"
    elif (( ${quiet:-0} == 0 )); then
      echo "INFO: no running ssh-agent known to this shell or cached in ${cachefile}."
    fi
  elif [[ -n "$SSH_AGENT_PID" ]]; then
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: disconnected ssh-agent PID $SSH_AGENT_PID from shell."
    fi
    unset SSH_AGENT_PID SSH_AUTH_SOCK
  elif (( ${quiet:-0} == 0 )); then
    echo "INFO: no connected ssh-agent in this shell."
  fi
  if (( ${killall:-0} )); then
    if [[ ! -n "${EUID}" ]]; then
      echo "ERROR: unable to ascertain effective UID from current shell: fail-safe."
      exit 1
    fi
    local euname
    if [[ "${OSTYPE}" == darwin* ]]; then
      euname=$(dscl . -list /Users UniqueID | awk '{ if ($2 == '$EUID') print $1 }')
    else
      euname=$(getent passwd ${EUID} | cut -d: -f 1)
    fi
    if ! [[ -n "${euname}" ]]; then
      echo "ERROR: unable to ascertain username for EUID ${EUID}" 1>&2
      exit 1
    fi
    local vkill
    if (( ${quiet:-0} == 0 )); then
      echo "INFO: killing all ${killed_agent:+remaining }ssh-agents owned by UID ${EUID} (${euname})."
      vkill=" -v"
    fi
    killall${vkill} -u ${euname} ssh-agent
  fi
}
