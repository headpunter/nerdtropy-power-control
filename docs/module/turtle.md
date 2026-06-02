# Turtle API Documentation

## Overview

Turtles are robotic devices that can break/place blocks, attack mobs, and move through the world. They have a 16-slot inventory.

## Movement

**`forward()`** / **`back()`** / **`up()`** / **`down()`** → boolean, string|nil
- Move one block. Consumes fuel.

**`turnLeft()`** / **`turnRight()`** → boolean, string|nil
- Rotate 90 degrees. No fuel cost.

## Block Interaction

**`dig([side])`** / **`digUp([side])`** / **`digDown([side])`** → boolean, string|nil
- Break block. Optional `side`: "left" or "right" for tool selection.

**`place([text])`** / **`placeUp([text])`** / **`placeDown([text])`** → boolean, string|nil
- Place block/item. `text` sets sign contents.

**`detect()`** / **`detectUp()`** / **`detectDown()`** → boolean
- Check for solid block.

**`compare()`** / **`compareUp()`** / **`compareDown()`** → boolean
- Compare block to selected slot item.

**`inspect()`** / **`inspectUp()`** / **`inspectDown()`** → boolean, table|string
- Get block info: name, state, tags.

## Entity Interaction

**`attack([side])`** / **`attackUp([side])`** / **`attackDown([side])`** → boolean, string|nil

## Inventory Management

**`select(slot)`** — Change selected slot (1-16)

**`getSelectedSlot()`** → number

**`getItemCount([slot])`** → number

**`getItemSpace([slot])`** → number

**`compareTo(slot)`** → boolean

**`transferTo(slot [, count])`** → boolean

**`getItemDetail([slot [, detailed]])`** → table|nil

**`drop([count])`** / **`dropUp([count])`** / **`dropDown([count])`** → boolean, string|nil

**`suck([count])`** / **`suckUp([count])`** / **`suckDown([count])`** → boolean, string|nil

## Fuel

**`getFuelLevel()`** → number | "unlimited"

**`getFuelLimit()`** → number | "unlimited"
- Normal: 20,000; Advanced: 100,000

**`refuel([count])`** → boolean, string|nil
- Consumes fuel items from selected slot. Pass `0` to check if item is combustible.

## Equipment

**`equipLeft()`** / **`equipRight()`** → boolean, string|nil

**`getEquippedLeft()`** / **`getEquippedRight()`** → table|nil

## Crafting

**`craft([limit=64])`** → boolean, string|nil
- Craft based on inventory layout. Pass `0` to validate without crafting.
