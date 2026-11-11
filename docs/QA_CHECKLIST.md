# Manual QA checklist

Automated first: all three commands in README "Test it" must exit 0, and the Godot output panel
must show no errors while playing.

## Boot and menu
- [ ] Splash shows the title, the bar fills, the menu appears without a hitch
- [ ] Menu: coin / key counters, best score, multiplier and streak are correct
- [ ] 3D runner is visible behind the menu and wears the equipped skin and trail
- [ ] Shop, Runners, Missions, Settings open and Back / Esc / Android back returns

## Run
- [ ] 3-2-1-GO with beeps; world starts moving after GO
- [ ] First run only: tutorial asks for left, right, up, down in order; Skip works; it never returns
- [ ] Swipe left / right / up / down each fire once, at the moment the threshold is crossed
- [ ] Two quick swipes without lifting the finger both register
- [ ] Diagonal drags do nothing
- [ ] Keyboard and gamepad controls work
- [ ] Jump clears low barriers and gaps; roll passes high barriers; swipe down in the air slams
- [ ] Ramp leads onto a train roof; coins on the roof collect; running off the end lands safely
- [ ] Side-swiping a train = stumble + bump back; a second stumble within 2.5 s = caught
- [ ] Head-on train or full barrier = crash; falling in a gap = crash
- [ ] Chaser appears after a stumble and drops back after the window
- [ ] Moving train: horn, blinking headlight, arrives early in its lane
- [ ] Near miss shows "+50 NEAR!", plays a whoosh and punches the FOV
- [ ] Each power-up: HUD ring counts down, blinks near the end, effect matches its description
- [ ] Mystery box gives coins, a key or a power-up
- [ ] Biome changes around 1500 m with a banner; nothing pops on screen
- [ ] No chunk seams, gaps or pop-in at the horizon (F3 shows chunk lines)

## Pause, revive, results
- [ ] Pause freezes everything, muffles music; Resume counts down 3 s first
- [ ] Restart and Quit to menu work from pause
- [ ] Revive popup: ring empties in 5 s then goes to results; key cost rises 1, 2, 3
- [ ] Revive clears the road ahead and gives blinking protection
- [ ] Results: score and coins count up; new best shows confetti; missions list animates
- [ ] Double coins (simulated ad) adds the run's coins once

## Shop, missions, settings
- [ ] Buying deducts coins, equips the item, and the runner updates immediately
- [ ] Unaffordable items are disabled; upgrades stop at MAX
- [ ] Mission progress and achievements match what was done; completing 3 raises the multiplier
- [ ] Volume sliders act live; vibration toggle respected
- [ ] Quality Low / Medium / High visibly change glow and sharpness
- [ ] Screen shake 0 removes shake; Reduce effects softens flashes and particles
- [ ] Colour-blind palette switches accents to blue + yellow
- [ ] Large text enlarges all screens without clipping
- [ ] Language switch updates every screen (English, Uzbek, Russian)
- [ ] Reset progress needs two taps and keeps settings

## Interruptions and devices
- [ ] Incoming call / home button / lock screen during a run pauses it; progress is saved
- [ ] Killing the app mid-run loses only that run
- [ ] Airplane mode: everything works offline
- [ ] Aspect ratios 16:9, 19.5:9, 20:9 and 4:3: no clipped or overlapping UI
- [ ] Notch / punch-hole devices: HUD stays inside the safe area
- [ ] Low-end phone on Low quality holds 60 FPS for a 5-minute run (F3 overlay)
- [ ] Memory and node count stay flat over 10 minutes (F3 overlay)
