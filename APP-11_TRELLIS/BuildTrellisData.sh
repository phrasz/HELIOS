#!/usr/bin/env bash
#
# BuildTrellisData.sh
#
# Reads SE2_BlockTiers.json (output of BlockTiersToJSON.sh) and produces the
# nested tree JSON that TRELLIS's DATA block expects:
#
#   { "tree": { "name": "SE2 Blocks", "children": [ <tier nodes> ] },
#     "minSize": <smallest block size>, "maxSize": <largest block size> }
#
# Hierarchy built per tier: Tier -> Machine -> Base Name -> Size variant leaf.
# Base name / size are parsed out of each item string, e.g.
#   "Antenna (1.5m)"  ->  base "Antenna", size 1.5, leaf name "Antenna (1.5m)"
#
# This script ONLY produces the JSON. It does not touch trellis.html --
# that's a separate patch step (finds the TRELLIS:DATA:START/END markers
# and replaces the span between them with this script's output).

INPUT="${1:-SE2_BlockTiers.json}"
OUTPUT="${2:-SE2_TreeData.json}"

jq '
def parseItem($item):
  if ($item | test("^(.*) \\(([0-9.]+)m\\)$")) then
    ($item | capture("^(?<base>.*) \\((?<size>[0-9.]+)m\\)$")) as $c
    | {orig: $item, base: $c.base, size: ($c.size | tonumber)}
  else
    {orig: $item, base: $item, size: null}
  end;

(.blockTiers
  | to_entries
  | map(
      .key as $tierKey
      | (.value.producedBy // []) as $machines
      | (if ($machines | length) == 0 then "Unassigned" else ($machines | join(" + ")) end) as $machineName
      | (if ($machines | length) == 0 then $tierKey else "\($tierKey) \u00b7 \($machineName)" end) as $tierLabel
      | ((.value.items // []) | map(parseItem(.))) as $parsed
      | ($parsed
          | group_by(.base)
          | map({
              name: .[0].base,
              children: (sort_by(.size) | map({name: .orig, size: .size, leaf: true}))
            })
        ) as $baseGroups
      | {
          name: $tierLabel,
          tier: $tierKey,
          children: [{name: $machineName, children: $baseGroups}]
        }
    )
) as $tierNodes
| ([.blockTiers[].items[]?] | map(parseItem(.).size) | map(select(. != null))) as $allSizes
| {
    tree: {name: "SE2 Blocks", children: $tierNodes},
    minSize: ($allSizes | min),
    maxSize: ($allSizes | max)
  }
' "$INPUT" > "$OUTPUT"

echo "Wrote tree data ($(jq '[.tree.children[].children[].children[].children[]] | length' "$OUTPUT") leaves across $(jq '.tree.children | length' "$OUTPUT") tiers) to $OUTPUT"
