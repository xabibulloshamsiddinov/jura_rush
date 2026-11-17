# Manual QA checklist

Automated first: all three commands in README "Test it" must exit 0, and the Godot output panel
must show no errors while playing.

## Boot and menu
- [ ] Splash shows the title, the bar fills, the menu appears without a hitch
- [ ] Menu: coin / key counters, best score, multiplier and streak are correct
- [ ] 3D caveman stands between the top and bottom UI bands and wears the equipped skin; he turns
      to the camera, glances at it and plays idle actions
- [ ] The T-Rex idles behind him, upper middle, its head below the logo and clear of the side
      icon columns; it roars every few seconds (sound and animation together)
- [ ] Menu checked in English, Uzbek and Russian (no clipped or overlapping text)
- [ ] Shop, Runners, Missions, Settings open and Back / Esc / Android back returns

## Run
- [ ] PLAY: the T-Rex roars behind the GET READY curtain, then turns and strides off to the left;
      the camera swings round the runner's right side into the run view in about a second and
      never passes through or right next to the T-Rex; the T-Rex is never seen from the run view
- [ ] 3-2-1-GO with beeps; the caveman crouches during the count, world starts moving after GO
- [ ] First run only: tutorial asks for left, right, up, down in order; Skip works; it never returns
- [ ] Swipe left / right / up / down each fire once, at the moment the threshold is crossed
- [ ] Two quick swipes without lifting the finger both register
- [ ] Diagonal drags do nothing
- [ ] Keyboard and gamepad controls work
- [ ] Jump clears low barriers and gaps; roll passes high barriers; swipe down in the air slams
- [ ] Tail-first herd: the ramp is the Brachiosaurus tail; the caveman's feet stay on the tail and
      the backs (no floating, no sinking); eggs on the backs collect; running off the end lands
- [ ] Head-first herd: a wall of sauropods facing the runner; passing herds never fill the screen
      (they dither out near the camera) and never vanish while their tails are still visible
- [ ] Side-swiping a herd = stumble + bump back; a second stumble within 2.5 s = caught
- [ ] Head-on herd or menhir wall = crash; falling in a ravine = crash
- [ ] After a stumble the T-Rex head and shoulders loom at the bottom right without hiding the
      runner, and it drops back after the window (also while the runner is up on a herd)
- [ ] Crash: the T-Rex lunges in from behind-right; the death camera (behind-left) never dives
      through it and the runner stays visible through the slow motion and the revive popup
- [ ] Triceratops stampede: paws, snorts and shakes its head (telegraph, bellow), then gallops in
      its lane early
- [ ] The caveman is lit like the world: warm in Volcano Ridge, darker inside caves and under
      shade, still the clearest thing on screen; his blob shadow follows him (no second shadow)
- [ ] Lane changes, jumps, landings and rolls blend smoothly (no pose pops); dirt kicks at footfalls
- [ ] Ptero Ride: a pterosaur swoops in, carries him over the herds in daylight, lets go cleanly
- [ ] Near miss shows "+50 NEAR!", plays a whoosh and punches the FOV
- [ ] Each power-up: HUD ring counts down, blinks near the end, effect matches its description
- [ ] Mystery box gives coins, a key or a power-up
- [ ] Biome changes every 500 m with a banner (Fern Valley, Red Canyon, Misty Swamp, Volcano
      Ridge); sun colour, sky and decor change smoothly; nothing pops on screen
- [ ] Motion is smooth at 60 FPS and on a 90 / 120 Hz phone (no judder of the runner, the T-Rex or
      the treadmill); pause and hit-stop freeze gameplay motion (creature idle sway may continue)
- [ ] No chunk seams, gaps or pop-in at the horizon (F3 shows chunk lines)

## Pause, revive, results
- [ ] Pause freezes all gameplay motion, muffles music; Resume counts down 3 s first
- [ ] Restart and Quit to menu work from pause
- [ ] Revive popup: ring empties in 5 s then goes to results; key cost rises 1, 2, 3
- [ ] Revive clears the road ahead and gives blinking protection
- [ ] Results: score and coins count up; new best shows confetti; missions list animates
- [ ] Double coins (simulated ad) adds the run's coins once

## Shop, missions, settings
- [ ] Buying deducts eggs, equips the item, and the runner updates immediately
- [ ] Runners tab: every row's thumbnail is a little caveman showing that skin's fur, hair, beard
      and accessory; accessory names read Bone top-knot, Raptor skull, Feather band, Stone club,
      Tooth necklace; Blaze shows only its build; the 3D preview shows each of the six skins lit
- [ ] Unaffordable items are disabled; upgrades stop at MAX
- [ ] Mission progress and achievements match what was done; completing 3 raises the multiplier
- [ ] Volume sliders act live; vibration toggle respected
- [ ] Quality Low / Medium / High visibly change glow and sharpness
- [ ] Screen shake 0 removes shake; Reduce effects softens flashes and particles
- [ ] Colour-blind palette turns lane chevrons yellow with a dark outline, and the lethal standing-stone paint and gap edge stones into yellow / black hazard stripes
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
