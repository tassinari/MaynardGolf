# CourseImagery (generated)

Every other file in this folder is written by `tools/cut-course-map.py` from the course master (a large
aerial that isn't in the repository): `hole1…9.heic`, `transition-1-2…9-1.heic`, `overview.heic` and
`CourseImagery.json`.
Don't edit them by hand; re-run the script (16-hole-map HM-CD-02):

```sh
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/cut-course-map.py /path/to/course-master.png
```

To refresh only `overview.heic` (and its entry in `CourseImagery.json`), add `--overview-only`.

**Framing the cameras** (`tools/course-cameras.json`): `tools/frame-hole-cameras.py` moves each hole's camera, and
zooms it out only when it must, so the hole's tee boxes, approach shots and pin clear Hole play's controls on
every supported iPhone (including the Out of order button's bottom-leading corner, HP-OO-08, #192) and the view stays on
the master (16-hole-map HM-CAM-02, #186). Run it after the course
data's points or the master change, then re-cut:

```sh
.venv/bin/python tools/frame-hole-cameras.py --dry-run   # shows each hole's shift and zoom
.venv/bin/python tools/frame-hole-cameras.py             # rewrites tools/course-cameras.json
.venv/bin/python tools/cut-course-map.py /path/to/fullmapFull.png
```

It stops with "can't fit its points" when a hole's points are too close to the master's edge to frame; extend the
master there first.

**What ships:** all of it, added to the app target file by file (not as a folder, and not through the
asset catalog, which re-encodes images several times larger): the nine hole crops (`hole1…9.heic`,
1434 × 2868, upright: tee at the bottom, green at the top), the nine transition crops (half the master's
resolution), `overview.heic` (the whole master, north up, at a sixth of its resolution, for the Course map
overview) and `CourseImagery.json`, which places every piece on the master. `BundleCourseImageryLoader`
reads them and Hole play's map draws them through the hole cameras (16-hole-map).
