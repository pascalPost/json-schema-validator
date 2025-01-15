# json-schema-validator

Exploration on how to write a json-schema validator in Zig.

The interface is for now a [Two-Argument Validation](https://json-schema.org/implementers/interfaces#two-argument-validation).

Regex uses cpp regex implementation, i.e., we have to link against std cpp for now.

- [] draft-07 tests
  - [] additionalItems.json
  - [] additionalProperties.json
  - [] allOf.json
  - [] anyOf.json
  - [] boolean_schema.json
  - [] const.json
  - [] contains.json
  - [] default.json
  - [] definitions.json
  - [] dependencies.json
  - [] enum.json
  - [] exclusiveMaximum.json
  - [] exclusiveMinimum.json
  - [] format.json
  - [] if-then-else.json
  - [] infinite-loop-detection.json
  - [] items.json
  - [] maxItems.json
  - [] maxLength.json
  - [] maxProperties.json
  - [] maximum.json
  - [] minItems.json
  - [] minLength.json
  - [] minProperties.json
  - [] minimum.json
  - [] multipleOf.json
  - [] not.json
  - [] oneOf.json
  - [] pattern.json
  - [] patternProperties.json
  - [] properties.json
  - [] propertyNames.json
  - [] ref.json
  - [] refRemote.json
  - [] required.json
  - [] type.json
  - [] uniqueItems.json
