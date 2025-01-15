# json-schema-validator

A JSON Schema validator implementation written in Zig, following the [Two-Argument Validation](https://json-schema.org/implementers/interfaces#two-argument-validation) interface specification.

## Overview

This project aims to provide a robust JSON Schema validation solution implemented in Zig for the Zig ecosystem. It currently supports various JSON Schema draft-07 validation features and is actively being developed to support more.

## Dependencies

- Zig compiler
- C++ Standard Library (for regex support)

## Implementation Details

The validator currently uses C++ regex implementation for pattern matching, requiring linkage against the C++ standard library.

## Features Implementation Status

- [ ] draft-07 tests
  - [x] additionalItems.json
  - [x] additionalProperties.json
  - [ ] allOf.json
  - [ ] anyOf.json
  - [ ] boolean_schema.json
  - [x] const.json
  - [ ] contains.json
  - [ ] default.json
  - [ ] definitions.jsoe
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

## Contributing

Contributions are welcome! Feel free to submit pull requests, especially for implementing pending features.
