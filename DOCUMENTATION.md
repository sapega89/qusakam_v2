# MovingPlatform — Full Documentation

This document explains all configuration options, platform modes, signal behavior, and the activator/interactable system.

---

# Table of Contents
- [1. Setup Instructions](#1-setup-instructions)
  - [1.1 Basic Node Setup](#11-basic-node-setup)
  - [1.2 Configuration Resources](#12-configuration-resources)
  - [1.3 Activators (Required for Triggered, Toggle, One-Way)](#13-activators-required-for-triggered-toggle-one-way)
- [2. Configuration Reference](#2-configuration-reference)
  - [2.1 MovingPlatformConfig Properties](#21-movingplatformconfig-properties)
  - [2.2 TweenResource Properties](#22-tweenresource-properties)
- [3. Platform Behavior Types](#3-platform-behavior-types)
  - [LOOP](#loop)
  - [TRIGGERED](#triggered)
  - [TOGGLE](#toggle)
  - [ONE_WAY](#one_way)
- [4. Signals](#4-signals)
- [5. Methods Overview](#5-methods-overview)
- [6. Activator System](#6-activator-system)
  - [6.1 Interactable Base Class](#61-interactable-base-class)
  - [6.2 Included Button Scene](#62-included-button-scene)
  - [6.3 Creating Custom Activators](#63-creating-custom-activators)

---

# 1. Setup Instructions

## 1.1 Basic Node Setup
1. Attach the `MovingPlatform` script to an `AnimatableBody2D`.
2. Add a `Marker2D` child to define the destination point.
3. Assign the following in the Inspector:
   - `final_pos_marker`
   - `platform`
4. *(Optional)* Add a `Line2D` child and assign it to `platform_line` for path visualization.

---

## 1.2 Configuration Resources
1. Create a **MovingPlatformConfig** resource and assign it to `config`.
2. Create a **TweenResource** and assign it to `tween_resource`.
3. Configure:
   - Movement mode, delays, stop-frame → **MovingPlatformConfig**
   - Duration, easing, process mode → **TweenResource**

---

## 1.3 Activators (Required for Triggered, Toggle, One-Way)
1. Add an `Activator` node or reference an existing one.
2. The platform will automatically connect to its activation/deactivation signals.

---

# 2. Configuration Reference

## 2.1 MovingPlatformConfig Properties
- **type** — Platform movement type (LOOP, TRIGGERED, TOGGLE, ONE_WAY)
- **delay** — Delay before initial movement begins
- **stopframe** — Pause duration at endpoints (LOOP only)
- **subsequent_delay** — Delay before activating linked platforms
- **backwards_scale** — Reverse movement speed multiplier
- **move_on_ready** — LOOP: start automatically on `_ready()`
- **move_on_screen_entered** — Start when entering the camera view

---

## 2.2 TweenResource Properties
- **base_duration** — Base travel time
- **trans** — Tween transition type
- **ease** — Tween easing curve
- **process_mode** — Idle or physics tweening

---

# 3. Platform Behavior Types

## LOOP
- Moves continuously between start and end points  
- Can auto-start on ready or screen entry  
- Supports endpoint stopframe delays  

## TRIGGERED
- Moves forward when activated  
- Holds current position when deactivated  
- **Requires an Activator**  

## TOGGLE
- Moves forward when activated, backward when deactivated  
- Reverse speed uses `backwards_scale`  
- **Requires an Activator**  

## ONE_WAY
- Moves to final position once, then stops permanently  
- No reverse motion  
- **Requires an Activator**

---

# 4. Signals

- **stopped** — Emitted when the platform comes to a complete stop  
- **moving_forward** — Emitted at the start of forward motion  
- **moving_backward** — Emitted when returning to the start position  

---

# 5. Methods Overview

### `move()`
Starts movement depending on platform type.  
LOOP begins continuous cycling; triggered types move toward the target.

### `play_backwards()`
Moves the platform back toward its original position (uses `backwards_scale`).

### `_update_path_visualization()`
Updates the Line2D preview between the platform and target marker.

### `_setup_connections()`
Automatically connects to assigned activator signals based on platform type.

---

# 6. Activator System

## 6.1 Interactable Base Class
The platform inherits from an `Interactable` class providing:
- Exported `Activator` reference
- Automatic connection to `activated` / `deactivated` signals
- Internal `is_active` state
- Overridable `_activated()` and `_deactivated()` handlers

---

## 6.2 Included Button Scene
A prebuilt button activator is included:

- **Path:** `res://addons/your_plugin_name/Scenes/InteractableButton.tscn`
- Contains Area2D, CollisionShape2D, and basic visuals
- Automatically activates when bodies enter/exit the detection area

---

## 6.3 Creating Custom Activators
To implement a custom activator:
1. Inherit from the `Activator` base class.
2. Emit activation/deactivation signals based on your logic.
3. Assign the custom activator to the platform’s `activator` property.

The platform will handle all wiring automatically.

---

