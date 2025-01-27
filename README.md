# json-schema-validator

![Testing Status](https://github.com/pascalPost/json-schema-validator/actions/workflows/zig.yml/badge.svg)

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
  - [x] allOf.json
  - [x] anyOf.json
  - [x] boolean_schema.json
  - [x] const.json
  - [ ] contains.json
  - [ ] default.json
  - [ ] definitions.json
  - [ ] dependencies.json
  - [x] enum.json
  - [x] exclusiveMaximum.json
  - [x] exclusiveMinimum.json
  - [ ] format.json
  - [x] if-then-else.json
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
  - [x] not.json
  - [x] oneOf.json
  - [x] pattern.json
  - [x] patternProperties.json
  - [x] properties.json
  - [ ] propertyNames.json
  - [ ] ref.json
  - [ ] refRemote.json
  - [x] required.json
  - [x] type.json
  - [x] uniqueItems.json

## Contributing

Contributions are welcome! Feel free to submit pull requests, especially for implementing pending features.
