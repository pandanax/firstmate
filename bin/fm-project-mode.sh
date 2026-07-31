#!/usr/bin/env bash
# Resolve a project's delivery mode, yolo flag, and merge authority from the data/projects.md registry.
# Prints three words to stdout: "<mode> <yolo> <merge>" where mode is one of
# no-mistakes|direct-PR|local-only, yolo is on|off, and merge is auto|manual.
#
# Registry line format (data/projects.md):
#   - <name> - <desc> (added <date>)                               -> no-mistakes off manual  (legacy default)
#   - <name> [<mode>] - <desc> (added <date>)                       -> <mode> off manual
#   - <name> [<mode> merge:<auto|manual>] - <desc> (added <date>)   -> <mode> off <auto|manual>
#   - <name> [<mode> +yolo merge:<auto|manual>] - <desc> (...)      -> <mode> on <auto|manual>
#
# mode = how a finished change reaches main:
#   no-mistakes  full pipeline -> PR -> configured merge authority (default)
#   direct-PR    push + PR via gh-axi, no pipeline -> configured merge authority
#   local-only   local branch, no remote/PR -> captain approve -> guarded local merge
# yolo (orthogonal) = when on, firstmate may make routine approval decisions itself.
#   AGENTS.md section 7 is the single owner of authority exceptions, including
#   ask-user contract expansion and stronger captain boundaries.
# merge (orthogonal) = manual waits for the captain; auto enables the forge's
#   native auto-merge after required checks. auto is valid only for PR modes;
#   local-only fails closed to manual because it has no forge merge queue.
# A Pandamate single-project launch may set PANDAMATE_PROJECT_SLUG and
# PANDAMATE_MERGE_MODE. The latter overrides only merge, and only when the
# requested project name exactly equals the slug. An invalid matching override
# fails closed to manual; a nonmatching slug cannot affect another project.
#
# An unknown/missing project or unknown mode falls back to "no-mistakes off manual" and warns
# to stderr, so a typo never silently drops the gate.
# Usage: fm-project-mode.sh <project-name>
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
REG="$DATA/projects.md"
NAME=${1:?usage: fm-project-mode.sh <project-name>}

if [ ! -f "$REG" ]; then
  echo "warn: no registry at $REG; defaulting $NAME to no-mistakes off manual" >&2
  parsed="no-mistakes off manual"
else
  # awk emits "<mode> <yolo> <merge>" (one line) or nothing if the project is absent.
  parsed=$(awk -v n="$NAME" '
    $1=="-" && $2==n {
      mode="no-mistakes"; yolo="off"; merge="manual";
      if ($3 ~ /^\[/) {
        s="";
        for (i=3; i<=NF; i++) { s = s (s==""?"":" ") $i; if ($i ~ /\]$/) break }
        gsub(/^\[|\]$/, "", s);           # strip the surrounding brackets
        k = split(s, a, " ");
        for (j=1; j<=k; j++) {
          if (a[j]=="+yolo") yolo="on";
          else if (a[j] ~ /^merge:/) merge=substr(a[j], 7);
          else if (a[j] != "" && mode=="no-mistakes") mode=a[j];
        }
      }
      print mode, yolo, merge; exit
    }
  ' "$REG")
  if [ -z "$parsed" ]; then
    echo "warn: project \"$NAME\" not in registry; defaulting to no-mistakes off manual" >&2
    parsed="no-mistakes off manual"
  fi
fi

read -r mode yolo merge <<EOF
$parsed
EOF
case "$mode" in
  no-mistakes|direct-PR|local-only) ;;
  *) echo "warn: unknown mode \"$mode\" for $NAME; defaulting to no-mistakes off manual" >&2; mode=no-mistakes; yolo=off; merge=manual ;;
esac
case "$yolo" in on|off) ;; *) yolo=off ;; esac
case "$merge" in
  auto|manual) ;;
  *) echo "warn: unknown merge authority \"$merge\" for $NAME; defaulting to manual" >&2; merge=manual ;;
esac
if [ "${PANDAMATE_PROJECT_SLUG:-}" = "$NAME" ] && [ "${PANDAMATE_MERGE_MODE+x}" = x ]; then
  case "$PANDAMATE_MERGE_MODE" in
    auto|manual) merge=$PANDAMATE_MERGE_MODE ;;
    *) echo "warn: invalid Pandamate merge authority \"$PANDAMATE_MERGE_MODE\" for $NAME; defaulting to manual" >&2; merge=manual ;;
  esac
fi
if [ "$mode" = local-only ] && [ "$merge" = auto ]; then
  echo "warn: merge:auto is unavailable for local-only project $NAME; defaulting to manual" >&2
  merge=manual
fi
echo "$mode $yolo $merge"
