# Release checklist

## Before the build
- [ ] `version.cfg` updated; `tools/apply_version.gd` run (version code increased)
- [ ] CHANGELOG.md updated
- [ ] Tests, track soak and bot soak exit 0
- [ ] Manual QA checklist completed on at least one low-end and one current phone
- [ ] No errors or warnings in the Godot output panel during a full session
- [ ] `GameConfig.GAME_TITLE` and `application/config/name` are final
- [ ] Package name changed from `com.example.neonrails` in both export presets
- [ ] Icon and splash regenerated or replaced (`assets/textures/`)

## Android export settings (Project > Export)
- [ ] Min SDK 24, target SDK = latest required by Google Play
- [ ] Architectures: arm64-v8a only (add armeabi-v7a only if old devices must be supported)
- [ ] Permissions: VIBRATE only (INTERNET only if an ads SDK is added)
- [ ] Immersive mode on, orientation portrait
- [ ] Release keystore set (Editor Settings or the preset), keystore backed up, never committed
- [ ] Export with debug OFF: APK for sideload testing, AAB for the store

## After the build
- [ ] Install the release APK on a clean device; first-run tutorial appears
- [ ] Debug overlay and cheat keys are absent
- [ ] Save survives an app update (install old build, play, install new build)
- [ ] Store listing: screenshots, description, content rating, privacy policy (no data collected)

## iOS notes
- [ ] Export on macOS with Xcode; bundle identifier and team id set
- [ ] Portrait only, "Requires full screen" on
- [ ] Icons supplied in the required sizes (start from `assets/textures/icon.png`)
- [ ] Test on a notched device for safe-area layout
