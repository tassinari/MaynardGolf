# CourseImagery (generated)

Every other file in this folder is written by `tools/cut-course-map.py` from the course master (a large
aerial that isn't in the repository): `hole1…9.heic`, `transition-1-2…9-1.heic` and `CourseImagery.json`.
Don't edit them by hand; re-run the script (16-hole-map HM-CD-02):

```sh
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/cut-course-map.py /path/to/course-master.png
```

**What ships:** all of it, added to the app target file by file (not as a folder, and not through the
asset catalog, which re-encodes images several times larger): the nine hole crops (`hole1…9.heic`,
1434 × 2868, upright: tee at the bottom, green at the top), the nine transition crops (half the master's
resolution) and `CourseImagery.json`, which places every crop on the master. `BundleCourseImageryLoader`
reads them and Hole play's map draws them through the hole cameras (16-hole-map).
