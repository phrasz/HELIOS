#!/usr/bin/env bash
#
# BlockTiersToJSON.sh
#
# Reads the markdown tier report produced by TierBlocks.sh and emits a new
# "blockTiers" JSON section, styled after the existing `production` pipeline
# columns (producedBy / items), but keyed by tier instead of component type.
#
# producedBy per tier lists only the machine newly introduced at that tier
# step, per the ruleset:
#   T-0 -> Backpack   T-1 -> Smelter   T-2 -> Refinery   T-3 -> Assembler
#   T-4 -> Refinery   T-5 -> Fabricator   T-6 -> Refinery
#   Unclassified -> [] (no data yet, needs manual entry)
#
# This script only reads the markdown report -- it does not touch the
# original data dictionary JSON. Tier-heading text after "T-N" is ignored
# (e.g. "## T-0 (102 blocks)" and "## T-0: Backpack Only (173 blocks)" both
# parse the same way), so it tolerates report format changes.

INPUT="${1:-SE2_Block_Tiers_Hybrid.md}"
OUTPUT="${2:-SE2_BlockTiers.json}"

TIERS=(T-0 T-1 T-2 T-3 T-4 T-5 T-6 Unclassified)

declare -A NEW_MACHINE=(
  [T-0]="Backpack"
  [T-1]="Smelter"
  [T-2]="Refinery"
  [T-3]="Assembler"
  [T-4]="Refinery"
  [T-5]="Fabricator"
  [T-6]="Refinery"
  [Unclassified]=""
)

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Split the markdown into one file of block names per tier section.
awk -v tmpdir="$TMPDIR" '
  /^## T-[0-6]/ {
    match($0, /T-[0-6]/)
    tier = substr($0, RSTART, RLENGTH)
    next
  }
  /^## Unclassified/ {
    tier = "Unclassified"
    next
  }
  /^## / { tier = "" ; next }              # any other heading (e.g. Summary) turns parsing off
  tier != "" && /^\|/ {
    n = split($0, cols, "|")
    name = cols[2]
    gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (name == "" || name == "Block" || name ~ /^-+$/) next
    print name >> (tmpdir "/" tier ".txt")
  }
' "$INPUT"

# Assemble the final JSON with jq, one tier object at a time.
{
  echo '{'
  echo '  "blockTiers": {'
  first_tier=1
  for tier in "${TIERS[@]}"; do
    file="$TMPDIR/$tier.txt"
    [[ $first_tier -eq 1 ]] || echo ','
    first_tier=0

    machine="${NEW_MACHINE[$tier]}"
    if [[ -n "$machine" ]]; then
      produced_by_json="[\"$machine\"]"
    else
      produced_by_json="[]"
    fi

    if [[ -f "$file" ]]; then
      items_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "$file")"
    else
      items_json="[]"
    fi

    printf '    "%s": {\n      "producedBy": %s,\n      "items": %s\n    }' \
      "$tier" "$produced_by_json" "$items_json"
  done
  echo
  echo '  }'
  echo '}'
} | jq '.' > "$OUTPUT"

echo "Wrote blockTiers section ($(jq '.blockTiers | [.[].items] | flatten | length' "$OUTPUT") blocks across $(jq '.blockTiers | length' "$OUTPUT") tiers) to $OUTPUT"