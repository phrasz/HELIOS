#!/usr/bin/env bash

INPUT="${1:-SE2_Data-Dictionary.json}"
OUTPUT="${2:-SE2_Data-Dictionary_updated.json}"

jq '
def zeroMap($items):
  reduce ($items[]) as $i ({}; .[$i] = 0);

.referenceData.rawMaterials.items as $raw
| .referenceData.refineryProducts.items as $refined
| .referenceData.simpleComponents.items as $simple
| .referenceData.complexComponents.items as $complex
| .referenceData.highTechComponents.items as $high
| .blocks.items |= map(
    if (
      ((keys - ["subcategories"]) | sort)
      == ["largestDimensionM","name"]
    ) then
      . + {
        materialsRaw:       zeroMap($raw),
        refineryProducts:   zeroMap($refined),
        componentsSimple:   zeroMap($simple),
        componentsComplex:  zeroMap($complex),
        componentsHighTech: zeroMap($high)
      }
    else
      .
    end
  )
' "$INPUT" > "$OUTPUT"


