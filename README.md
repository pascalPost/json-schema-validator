# json-schema-validator

Exploration on how to write a json-schema validator in Zig.

The interface is for now a [Two-Argument Validation](https://json-schema.org/implementers/interfaces#two-argument-validation).

Regex uses cpp regex implementation, i.e., we have to link against std cpp for now.

- [ ] draft-07 tests
  - [x] additionalItems.json
  - [x] additionalProperties.json
  - [ ] allOf.json
  - [ ] anyOf.json
  - [ ] boolean_schema.json
  - [x] const.json
  - [ ] contains.json
  - [ ] default.json
  - [ ] definitions.json
  - [ ] dependencies.json
  - [x] enum.json
  - [x] exclusiveMaximum.json
  - [x] exclusiveMinimum.json
  - [ ] format.json
  - [ ] if-then-else.json
  - [ ] infinite-loop-detection.json
  - [x] items.json
  - [x] maxItems.json
  - [x] maxLength.json
  - [x] maxProperties.json
  - [x] maximum.json
  - [x] minItems.json
  - [x] minLength.json
  - [x] minProperties.json
  - [x] minimum.json
  - [x] multipleOf.json
  - [ ] not.json
  - [ ] oneOf.json
  - [x] pattern.json
  - [x] patternProperties.json
  - [x] properties.json
  - [ ] propertyNames.json
  - [ ] ref.json
  - [ ] refRemote.json
  - [x] required.json
  - [x] type.json
  - [ ] uniqueItems.json
