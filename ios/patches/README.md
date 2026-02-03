# iOS Plugin Patches

This directory contains patches for iOS plugins to fix compatibility issues.

## Flutter WebRTC EXC_BAD_ACCESS Fix

**Problem**: The app crashes with `Thread 1: EXC_BAD_ACCESS (code=1, address=0x10)` when users log out or receive notifications due to a null pointer dereference in the `postEvent` function of FlutterWebRTCPlugin.

**Solution**: Ultra-robust null safety checks with triple protection:
1. Checks if sink is nil before dispatching
2. Captures sink in a strong local variable to prevent premature deallocation
3. Double-checks sink validity inside the dispatch block
4. Wraps sink calls in @try-@catch for additional error handling
5. Automatically handles both ios/Classes and common/darwin file structures

### Files:
- `flutter_webrtc/FlutterWebRTCPlugin.m.patch` - Original patch file (reference only)
- `apply_flutter_webrtc_patch.sh` - **Idempotent patch script** (safe to run multiple times)

### Key Features:
✅ **Idempotent** - Safe to run multiple times without causing issues
✅ **Version-aware** - Works with flutter_webrtc 0.12.x and 0.14.x
✅ **Auto-detection** - Detects if patch is already applied
✅ **Self-healing** - Fixes syntax errors like missing newlines
✅ **Backup creation** - Automatically creates .original backup files
✅ **Structure-aware** - Handles common/darwin → ios/Classes syncing

### Manual Application:
```bash
# Apply just the WebRTC patch (recommended)
cd ios/patches
bash apply_flutter_webrtc_patch.sh

# Apply all patches
bash apply_patches.sh
```

### Automatic Application:
Run after every `flutter pub get`:
```bash
flutter pub get && bash ios/patches/apply_flutter_webrtc_patch.sh
```

### When to Run:
- ✅ After `flutter pub get` or `flutter pub upgrade`
- ✅ After `flutter clean` or `flutter pub cache clean`
- ✅ Before building for iOS
- ✅ If you see "Undefined symbol: FlutterWebRTCPlugin" error

### Troubleshooting:

**Build fails with "Undefined symbol: FlutterWebRTCPlugin"**
```bash
bash ios/patches/apply_flutter_webrtc_patch.sh
cd ios && pod install
```

**Patch doesn't apply**
1. Ensure Python 3 is installed: `python3 --version`
2. Clean and reinstall:
```bash
flutter pub cache clean  # Answer 'y'
flutter pub get
bash ios/patches/apply_flutter_webrtc_patch.sh
```

## Permission Handler Patch

**Problem**: iOS 18 compatibility issues with contact permissions.

**Solution**: Updated ContactPermissionStrategy.m for iOS 18 support.

---

## Notes:
- Patches are applied to the local pub cache, so they persist until you clear the cache
- Re-run patches after `flutter clean` or pub cache updates
- These patches don't modify your source code, only the cached plugin files