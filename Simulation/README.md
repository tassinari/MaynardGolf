# Simulated GPS positions

GPX files that put the GPS on Maynard Golf Club, for trying Show my location and the shot lines' yardages without
going to the course (07-hole-play HP-CTL-03, 14-shot-lines, #245).

## Using them in Xcode

1. Run the app from Xcode, on a simulator or on an iPhone plugged in.
2. In the debug bar under the editor, click the **location arrow** (Simulate Location) and pick a file:
   - **Course**: the course's own coordinate.
   - **Hole N Tee**: hole N's white tee.
   - **Hole N Green**: the centre of hole N's green.
   - **Hole N Walk**: walks from the white tee, through the hole's approach shots, to the green at about
     1.4 m/s, so the yardages count down as you go.
3. In Hole play, tap Show my location. The first time, allow location (While Using, with Precise on).

Pick **Don't Simulate Location** in the same menu to go back to the real GPS. To start every run at one of these
spots, choose it under **Product › Scheme › Edit Scheme… › Run › Options › Default Location**. That's a personal
choice, so it isn't set in the shared scheme.

On the simulator, the Simulator app's **Features › Location › Custom Location…** takes any other coordinate.

## Regenerating

The files are generated from `MaynardGolf/MaynardGC.json` by `tools/make-gpx.py`. Don't edit them by hand:

```bash
python3 tools/make-gpx.py           # rewrite this folder (Tee and Walk start from the white tee)
python3 tools/make-gpx.py --check   # fails if a file is missing, stale or extra (run by scripts/build.sh selftest)
```

They're in the Xcode project's **Simulation** group but in no target, so they're never built into the app. If a hole
is added or removed, add or remove its files in that group too (in Xcode: add them with no target checked). The
self-tests fail while a file here isn't in `project.pbxproj`.
