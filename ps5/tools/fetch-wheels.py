#!/usr/bin/env python3
"""Fetches the texture tools' Python packages for this Python, without pip.

    fetch-wheels.py DIR

Downloads Pillow and etcpak (and archspec, which etcpak imports) as wheels from PyPI, the ones built for this
Python and this machine, checks each against PyPI's SHA-256, and unpacks them
into DIR/<python version>, which it prints: put that on PYTHONPATH. A fresh
Ubuntu (or WSL) has neither pip nor venv, and a Mac's Command Line Tools have
Python 3.9, which newer Pillows no longer support. Run again, it does nothing.

SPDX-License-Identifier: MIT
"""

import hashlib, json, os, platform, re, sys, urllib.request, zipfile

# (name, version): Pillow 12 needs Python 3.10, so 3.9 gets the last that supports it
PACKAGES = [("archspec", "0.2.6"), ("etcpak", "0.9.15"), ("pillow", "12.3.0" if sys.version_info >= (3, 10) else "11.3.0")]


def compatible(filename):
    """A wheel this Python can import here: its CPython tag (or abi3 from an
    older one) and its platform; or pure Python."""
    if filename.endswith("-py3-none-any.whl"):
        return True
    m = re.match(r"[^-]+-[^-]+-(cp(\d)(\d+))-(cp\d+m?|abi3)-(.+)\.whl$", filename)
    if not m:
        return False
    major, minor, abi, plats = int(m.group(2)), int(m.group(3)), m.group(4), m.group(5).split(".")
    here = sys.version_info
    if abi == "abi3":
        if (major, minor) > (here.major, here.minor):
            return False
    elif (major, minor) != (here.major, here.minor):
        return False
    machine = platform.machine().lower()
    for plat in plats:
        if sys.platform == "darwin":
            want = "arm64" if machine == "arm64" else "x86_64"
            if plat.startswith("macosx_") and (plat.endswith("_" + want) or plat.endswith("_universal2")):
                return True
        elif sys.platform.startswith("linux"):
            want = {"arm64": "aarch64"}.get(machine, machine)
            g = re.match(r"manylinux_(\d+)_(\d+)_(.+)$", plat) or re.match(r"manylinux(2014)_(.+)$", plat)
            if not g:
                continue
            if g.re.pattern.startswith("manylinux(2014)"):
                need, arch = (2, 17), g.group(2)
            else:
                need, arch = (int(g.group(1)), int(g.group(2))), g.group(3)
            libc = os.confstr("CS_GNU_LIBC_VERSION").split()[-1].split(".") if hasattr(os, "confstr") else ["0", "0"]
            if arch == want and (int(libc[0]), int(libc[1])) >= need:
                return True
    return False


def main():
    root = os.path.join(sys.argv[1], "python%d.%d" % sys.version_info[:2])
    done = os.path.join(root, ".done-" + "-".join(n + v for n, v in PACKAGES))
    if not os.path.exists(done):
        os.makedirs(root, exist_ok=True)
        for name, version in PACKAGES:
            with urllib.request.urlopen(f"https://pypi.org/pypi/{name}/{version}/json") as r:
                files = json.load(r)["urls"]
            wheel = next((f for f in files if compatible(f["filename"])), None)
            if not wheel:
                sys.exit(f"fetch-wheels.py: no {name} {version} for Python {platform.python_version()} on "
                         f"{sys.platform} {platform.machine()}")
            print(f"==> fetching {wheel['filename']}", file=sys.stderr)
            with urllib.request.urlopen(wheel["url"]) as r:
                data = r.read()
            if hashlib.sha256(data).hexdigest() != wheel["digests"]["sha256"]:
                sys.exit(f"fetch-wheels.py: {wheel['filename']} did not download correctly; try again")
            path = os.path.join(root, wheel["filename"])
            with open(path, "wb") as f:
                f.write(data)
            with zipfile.ZipFile(path) as z:
                for member in z.infolist():
                    z.extract(member, root)
                    # a zip keeps the executable bit in its Unix attributes; extract() drops it
                    mode = member.external_attr >> 16
                    if mode:
                        os.chmod(os.path.join(root, member.filename), mode)
            os.remove(path)
        open(done, "w").close()
    print(root)


if __name__ == "__main__":
    main()
