# CourseImagery (generated)

Every other file in this folder is written by `tools/cut-course-map.py` from the course master (a large
aerial that isn't in the repository): `hole1…9.heic`, `transition-1-2…9-1.heic` and `CourseImagery.json`.
Don't edit them by hand; re-run the script (16-hole-map HM-CD-02):

```sh
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/cut-course-map.py /path/to/course-master.png
```

**What ships today:** only the nine hole crops (`hole1…9.heic`, about 1.4 MB each, 1434 × 2868, upright:
tee at the bottom, green at the top). Hole play shows them as still pictures through `BundleHoleImages`
(HP-MAP-01). They're added to the app target one by one, not as a folder or through the asset catalog,
which re-encodes images several times larger.

**Not shipped yet:** the transition crops and `CourseImagery.json`, which places every crop on the master
for the camera-based map (#114, phase 5). They're kept here so the folder always matches the script's
output; add them to the target with the map.
