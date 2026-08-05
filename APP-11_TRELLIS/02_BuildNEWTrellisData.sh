#!/usr/bin/env bash
#
# BuildTrellisData_v4.sh
#
# Reads SE2_BlockTiers_v4.json and produces the nested tree JSON for TRELLIS.
# Hierarchy: Tier -> Machine Combination -> Base Name -> Size Variant.

INPUT="${1:-SE2_BlockTiers_v4.json}"
OUTPUT="${2:-SE2_TreeData_v4.json}"

jq '
def parseItem($item):
  if ($item.name | test("^(.*) \\(([0-9.]+)m\\)$")) then
    ($item.name | capture("^(?<base>.*) \\((?<size>[0-9.]+)m\\)$")) as $c
    | {
        orig: $item.name, 
        base: $c.base, 
        # Prefer the explicit size from dictionary, fallback to parsed name size
        size: ($item.size // ($c.size | tonumber)), 
        producedBy: $item.producedBy
      }
  else
    {orig: $item.name, base: $item.name, size: $item.size, producedBy: $item.producedBy}
  end;

(.blockTiers
  | to_entries
  | map(
      .key as $tierKey
      | (.value.items // []) as $items
      | ($items | map(parseItem(.))) as $parsed
      | (
          $parsed
          | group_by(.producedBy)
          | map(
              (.[0].producedBy | join(" + ")) as $machineName
              | {
                  name: $machineName,
                  children: (
                    . | group_by(.base)
                    | map({
                        name: .[0].base,
                        children: (sort_by(.size) | map({name: .orig, size: .size, leaf: true}))
                      })
                  )
                }
            )
        ) as $machineNodes
      | {
          name: (
            if $tierKey == "T-0" then "T-0 \u00b7 Backpack Only"
            elif $tierKey == "T-1" then "T-1 \u00b7 Smelter"
            elif $tierKey == "T-2" then "T-2 \u00b7 Assembler"
            elif $tierKey == "T-3" then "T-3 \u00b7 Assembler / Refinery"
            elif $tierKey == "T-4" then "T-4 \u00b7 Fabricator / Refinery"
            elif $tierKey == "Unclassified" then "Unclassified"
            else "\($tierKey)" end
          ),
          tier: $tierKey,
          children: $machineNodes
        }
    )
) as $tierNodes
| ([.blockTiers[].items[]?] 
    | map(.size // (if (.name | test("([0-9.]+)m")) then (.name | capture("(?<size>[0-9.]+)m").size | tonumber) else null end)) 
    | map(select(. != null))
  ) as $allSizes
| {
    tree: {name: "SE2 Blocks", children: $tierNodes},
    minSize: ($allSizes | min),
    maxSize: ($allSizes | max)
  }
' "$INPUT" > "$OUTPUT"

echo "Wrote Trellis Tree Data to $OUTPUT"
echo "Leaves: $(jq '[.tree.children[].children[].children[].children[]] | length' "$OUTPUT")"
