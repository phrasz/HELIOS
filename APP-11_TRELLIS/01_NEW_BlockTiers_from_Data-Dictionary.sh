#!/usr/bin/env bash
#
# BlockTiersV4.sh
# Applies V4 classification logic against SE2_Data-Dictionary.json
#

INPUT="${1:-../APP-09_SE2DS/SE2_Data-Dictionary.json}"
OUTPUT="${2:-SE2_BlockTiers_v4.json}"

jq '
def hasNonZero($m):
  ($m // {}) as $mm
  | ($mm | length) > 0
    and ($mm | to_entries | any(.value != 0 and .value != "0" and .value != null));

# Define our explicit tier mappings
{
  "none": "T-0",
  "Smelter": "T-1",
  "Assembler": "T-2",
  "Assembler+Smelter": "T-2",
  "Refinery+Smelter": "T-2",
  "Assembler+Fabricator": "T-3",
  "Assembler+Refinery": "T-3",
  "Assembler+Refinery+Smelter": "T-3",
  "Fabricator+Refinery": "T-4",
  "Assembler+Fabricator+Refinery": "T-4",
  "Assembler+Fabricator+Smelter": "T-4"
} as $tierMap |

.referenceData.allProductionOutputs.by_source.Backpack.outputs as $backpackSet
| (
    .blocks.items
    | map(
        . as $b
        | ($b.componentsSimple)   as $cs
        | ($b.refineryProducts)   as $rp
        | ($b.componentsComplex)  as $cc
        | ($b.componentsHighTech) as $ht
        
        | (hasNonZero($cs) and (( ($cs // {} | keys) - $backpackSet ) | length) > 0) as $needsSmelter
        | (hasNonZero($rp)) as $needsRefinery
        | (hasNonZero($cc)) as $needsAssembler
        | (hasNonZero($ht)) as $needsFabricator
        
        | [
            (if $needsSmelter   then "Smelter"    else empty end),
            (if $needsRefinery  then "Refinery"   else empty end),
            (if $needsAssembler then "Assembler"  else empty end),
            (if $needsFabricator then "Fabricator" else empty end)
          ] as $needs
          
        | (hasNonZero($cs) or hasNonZero($rp) or hasNonZero($cc) or hasNonZero($ht)) as $hasAnyData
        | (
            if ($hasAnyData | not) then
              {tier: "Unclassified", producedBy: []}
            else
              ($needs | sort | join("+")) as $comboKey
              | (if $comboKey == "" then "none" else $comboKey end) as $lookupKey
              | ($tierMap[$lookupKey] // "T-UNKNOWN") as $tierAssigned
              | {
                  tier: $tierAssigned, 
                  producedBy: (if ($needs | length) == 0 then ["Backpack"] else ($needs | sort) end)
                }
            end
          ) as $r
        | {
            name: $b.name, 
            tier: $r.tier, 
            producedBy: $r.producedBy,
            size: $b.largestDimensionM
          }
      )
  ) as $classified
| ($classified
    | group_by(.tier)
    | map({(.[0].tier): {items: map({name, producedBy, size})}})
    | add
  ) as $byTier
| {blockTiers: $byTier}
' "$INPUT" > "$OUTPUT"

echo "Wrote V4 Block Tiers to $OUTPUT"
echo "=== Tier Distribution ==="
jq -r '.blockTiers | to_entries[] | "  \(.key): \(.value.items | length) blocks"' "$OUTPUT"
