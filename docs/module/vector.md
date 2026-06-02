# Vector API Documentation

## Overview

Provides a 3D vector type for working with Minecraft world coordinates (e.g., from GPS).

## Constructor

### `vector.new(x, y, z)` → Vector
Creates a new Vector with the specified coordinates.

## Vector Methods

### Arithmetic
**`Vector:add(o)`** / `v1 + v2` → Vector

**`Vector:sub(o)`** / `v1 - v2` → Vector

**`Vector:mul(factor)`** / `v * 3` → Vector

**`Vector:div(factor)`** / `v / 3` → Vector

**`Vector:unm()`** / `-v` → Vector (negation)

### Products
**`Vector:dot(o)`** → number

**`Vector:cross(o)`** → Vector

### Properties
**`Vector:length()`** → number

**`Vector:normalize()`** → Vector (unit vector)

### Utility
**`Vector:round([tolerance])`** → Vector — Rounds each dimension; tolerance defaults to 1

**`Vector:tostring()`** → string

**`Vector:equals(other)`** → boolean
