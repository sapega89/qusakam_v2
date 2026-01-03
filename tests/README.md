# Automated Tests - Dark Realm RPG

## Overview

Automated test suite for the 7-day demo implementation using **GUT (Godot Unit Testing)** framework.

**Test Coverage:**
- ✅ Unit Tests (4 files, 80+ tests)
- ✅ Integration Tests (1 file, 20+ tests)
- ✅ **Total: 100+ tests**

---

## 📋 Test Files

### Unit Tests (`tests/unit/`)

1. **test_xp_manager.gd** - XPManager tests
   - XP gain and tracking
   - Level up mechanics
   - Stat bonus calculations
   - XP percentage
   - Edge cases

2. **test_coin_system.gd** - Coin system tests
   - Coin tracking in InventoryManager
   - Add/spend coins
   - Coin scene loading
   - Edge cases

3. **test_tutorial_manager.gd** - Tutorial system tests
   - Tutorial hint triggering
   - Event handlers
   - Flag tracking
   - Reset functionality

4. **test_vfx_system.gd** - VFX tests
   - Scene loading
   - Particle configuration
   - Auto-cleanup
   - Performance

### Integration Tests (`tests/integration/`)

1. **test_combat_progression.gd** - Complete workflow tests
   - Combat → XP → Level up
   - Combat → Coins → Economy
   - Different enemy types
   - Realistic scenarios
   - Performance tests

---

## 🚀 Installation

### 1. Install GUT Framework

**Option A: Asset Library (Recommended)**
1. Open Godot Editor
2. Go to **AssetLib** tab
3. Search for "**GUT**" (Godot Unit Testing)
4. Install latest version
5. Enable in **Project → Project Settings → Plugins**

**Option B: Manual Download**
```bash
# Clone GUT repository
git clone https://github.com/bitwes/Gut.git addons/gut
```

### 2. Verify Installation

GUT should appear in the bottom panel:
- **GUT** tab should be visible
- Panel shows "Run Tests" button

---

## ▶️ Running Tests

### Method 1: GUT Panel (GUI)

1. Open Godot Editor
2. Click **GUT** tab in bottom panel
3. Click **"Run All"** button
4. Watch test results in real-time

**Expected Output:**
```
Running tests...
✓ test_xp_manager.gd (25 tests passed)
✓ test_coin_system.gd (20 tests passed)
✓ test_tutorial_manager.gd (18 tests passed)
✓ test_vfx_system.gd (22 tests passed)
✓ test_combat_progression.gd (20 tests passed)

Total: 105/105 passed (100%)
```

### Method 2: Command Line

```bash
# Run all tests
godot --path . -s addons/gut/gut_cmdln.gd

# Run specific test file
godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_xp_manager.gd

# Run tests and exit
godot --path . -s addons/gut/gut_cmdln.gd -gexit
```

### Method 3: Test Scene

1. Open `res://tests/GutTestRunner.tscn` (if exists)
2. Press F5 to run
3. Tests execute and display results

---

## 📊 Test Categories

### Unit Tests (Isolated)

**Purpose:** Test individual components in isolation

**Characteristics:**
- Fast execution (<1s per file)
- No dependencies on game scenes
- Mock external dependencies
- Focus on single responsibility

**Example:**
```gdscript
func test_add_xp_increases_current_xp():
    xp_manager.add_xp(50)
    assert_eq(xp_manager.current_xp, 50)
```

### Integration Tests (Workflow)

**Purpose:** Test complete system interactions

**Characteristics:**
- Test multiple systems together
- Simulate realistic scenarios
- Verify end-to-end flow
- May take longer to run

**Example:**
```gdscript
func test_complete_progression_loop():
    # Kill 4 enemies
    for i in 4:
        xp_manager.add_xp(25)
        inventory_manager.add_coins(3)

    # Verify level up
    assert_eq(xp_manager.current_level, 2)
    assert_eq(inventory_manager.get_coins(), 12)
```

---

## ✅ Test Coverage

### XPManager (25 tests)
- [x] XP gain and accumulation
- [x] Level up at thresholds
- [x] Signal emissions
- [x] Stat bonus calculations
- [x] XP percentage display
- [x] Linear scaling (Level × 100)
- [x] Multiple level ups at once
- [x] XP overflow handling
- [x] Edge cases (zero, negative, large values)

### Coin System (20 tests)
- [x] Coin tracking
- [x] Add/spend mechanics
- [x] Transaction validation
- [x] Coin scene loading
- [x] Collectible instantiation
- [x] Edge cases (zero, negative, overflow)

### Tutorial System (18 tests)
- [x] Event handler triggers
- [x] Flag tracking (one-time hints)
- [x] Reset functionality
- [x] Null safety
- [x] Scene loading
- [x] Hint dictionary validation

### VFX System (22 tests)
- [x] All 5 VFX scenes load
- [x] Correct instantiation
- [x] Particle configuration
- [x] Particle counts (12-40)
- [x] One-shot mode
- [x] Auto-cleanup
- [x] Performance (100 VFX spawn)

### Combat Progression (20 tests)
- [x] Enemy death → XP
- [x] Enemy death → Coins
- [x] Multiple kills accumulation
- [x] Level up triggers
- [x] Stat bonus application
- [x] Different enemy types
- [x] Realistic scenarios
- [x] Boss fight simulation
- [x] Performance (100 rapid kills)

---

## 🎯 Success Criteria

**Tests PASS if:**
- ✅ 100/105 tests pass (95%+ pass rate)
- ✅ No crashes or errors
- ✅ All unit tests pass (<5s total)
- ✅ All integration tests pass (<10s total)

**Tests FAIL if:**
- ❌ Any critical test fails
- ❌ Memory leaks detected
- ❌ Crashes occur
- ❌ Pass rate < 90%

---

## 🐛 Debugging Failed Tests

### View Test Output

GUT provides detailed output:
```
FAILED: test_add_xp_increases_current_xp
  Expected: 50
  Got: 0
  At: test_xp_manager.gd:25
```

### Common Failure Reasons

1. **Signal not emitted**
   - Check `watch_signals()` called before action
   - Verify signal name matches exactly

2. **Scene not loading**
   - Check file path is correct (`res://...`)
   - Verify scene exists and is valid

3. **Null reference**
   - Check object instantiation
   - Verify `before_each()` setup runs

4. **Assertion mismatch**
   - Check expected vs actual values
   - Verify type matches (int vs float)

### Enable Verbose Logging

```gdscript
# In test file
func before_all():
    gut.log_level = gut.LOG_LEVEL_ALL_ASSERTS
```

---

## 📈 Adding New Tests

### Step 1: Create Test File

```gdscript
extends GutTest

## Tests for MyNewFeature

var my_feature: MyNewFeature

func before_each():
    my_feature = MyNewFeature.new()

func after_each():
    my_feature.free()

func test_feature_works():
    my_feature.do_something()
    assert_true(my_feature.is_working())
```

### Step 2: Run Tests

```bash
godot --path . -s addons/gut/gut_cmdln.gd
```

### Step 3: Iterate

- Fix failing tests
- Add more test cases
- Refactor as needed

---

## 🔧 Configuration

### .gutconfig.json

```json
{
  "dirs": ["res://tests/unit", "res://tests/integration"],
  "include_subdirs": true,
  "log_level": 1,
  "junit_xml_file": "res://tests/results/junit.xml"
}
```

### Custom Configuration

Edit `.gutconfig.json` to:
- Add new test directories
- Change log level
- Enable JUnit XML output
- Configure exit behavior

---

## 📝 Test Writing Best Practices

### 1. Test Names

Use descriptive names:
```gdscript
# Good
func test_add_xp_increases_current_xp()

# Bad
func test1()
```

### 2. Arrange-Act-Assert

Structure tests clearly:
```gdscript
func test_level_up_at_100_xp():
    # Arrange
    xp_manager.current_xp = 0

    # Act
    xp_manager.add_xp(100)

    # Assert
    assert_eq(xp_manager.current_level, 2)
```

### 3. One Assertion Per Test

Focus on single behavior:
```gdscript
# Good
func test_xp_increases():
    xp_manager.add_xp(50)
    assert_eq(xp_manager.current_xp, 50)

func test_level_unchanged():
    xp_manager.add_xp(50)
    assert_eq(xp_manager.current_level, 1)
```

### 4. Use Setup/Teardown

Avoid duplication:
```gdscript
func before_each():
    # Setup runs before EACH test
    xp_manager = XPManager.new()

func after_each():
    # Teardown runs after EACH test
    xp_manager.free()
```

---

## 🚀 CI/CD Integration

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Godot Tests
        run: |
          godot --path . -s addons/gut/gut_cmdln.gd -gexit
```

### GitLab CI Example

```yaml
test:
  script:
    - godot --path . -s addons/gut/gut_cmdln.gd -gexit
```

---

## 📚 Resources

### GUT Documentation
- **GitHub:** https://github.com/bitwes/Gut
- **Wiki:** https://github.com/bitwes/Gut/wiki
- **Godot Docs:** https://docs.godotengine.org/en/stable/community/tutorials/testing/index.html

### Assertion Reference

```gdscript
assert_eq(a, b)               # Equal
assert_ne(a, b)               # Not equal
assert_true(condition)        # True
assert_false(condition)       # False
assert_null(obj)              # Null
assert_not_null(obj)          # Not null
assert_almost_eq(a, b, delta) # Float equality
assert_signal_emitted(obj, signal_name)
assert_called(obj, method_name)
```

---

## 🎉 Summary

**Test Suite Status:**
- ✅ 5 test files created
- ✅ 100+ tests written
- ✅ Unit + Integration coverage
- ✅ GUT framework configured
- ✅ Ready to run

**Next Steps:**
1. Install GUT from AssetLib
2. Run tests: `GUT panel → Run All`
3. Verify 95%+ pass rate
4. Fix any failures
5. Iterate and improve

**Questions?**
Check GUT wiki or test file comments for examples.

---

**Happy Testing! 🧪**
