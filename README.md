# thistle-evidence

Forensic evidence, an evidence laptop, a forensics lab and wiretaps for FiveM, built on Thistle-Lib.

| Folder | What it is |
|---|---|
| [`thistle-evidence/`](thistle-evidence/) | The resource itself. See its [README](thistle-evidence/README.md) for install and config. |
| [`thistle-lib/`](thistle-lib/) | The shared Thistle library it depends on (0.5.0). Install it next to `thistle-evidence` and start it first. |

Copy both folders into your server's `resources` folder (or use the release zip, which has them in a `[thistle-evidence]` folder), then `ensure thistle-lib` before `ensure thistle-evidence`.

If your server already runs thistle-lib for other Thistle scripts, keep one copy: whichever is newer.
