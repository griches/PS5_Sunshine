#!/usr/bin/env python3
"""Super Mario Sunshine for the PlayStation 5 - an HD texture pack sized for the console.

    get-texture-pack.py [OUT]        OUT/textures/ (OUT defaults to ./out)

Downloads the Super Mario Sunshine UHD Texture Pack (qashto, razius) and the HD
texture extras (chasem-dev) from where their authors publish them, checks each
against the release this was tested with, and makes a copy with nothing larger
than 2048 pixels (shrink-texture-pack.py: the console's driver cannot hold the
4096 and 8192 pixel images). Copy OUT/textures to the console as
/data/homebrew/PPSA99312/mods/textures.

Neither pack is part of this project or stored by it; each belongs to its authors.
Needs Python with Pillow and etcpak, and 7-Zip (7z, 7zz or 7za) or bsdtar to
unpack. About 1 GB to download, 5 GB of disk while it works, 1.3 GB at the end.

SPDX-License-Identifier: MIT
"""
import hashlib, os, shutil, subprocess, sys, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
PACKS = [
    {"name": "Super Mario Sunshine UHD Texture Pack v2.1.1 (qashto, razius)",
     "page": "https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack",
     "url": "https://github.com/qashto/Super_Mario_Sunshine_UHD_Texture_Pack/releases/download/2.1.1/GMS.7z",
     "file": "GMS.7z", "md5": "274985dba9214b857b3e5605d2ee49b2", "inside": "GMS/Textures/GMS", "as": "GMS"},
    {"name": "Super Mario Sunshine HD texture extras v1.1.1 (chasem-dev)",
     "page": "https://github.com/chasem-dev/sms-hd-texture-extras",
     "url": "https://github.com/chasem-dev/sms-hd-texture-extras/releases/download/v1.1.1/sms-hd-texture-extras-1.1.1.zip",
     "file": "sms-hd-texture-extras-1.1.1.zip", "md5": "a658c43cce0751e585e991f8563e5f41", "inside": "", "as": "sms-hd-texture-extras"},
]


def say(text):
    print("==> " + text, flush=True)


def md5_of(path):
    digest = hashlib.md5()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(pack, folder):
    path = os.path.join(folder, pack["file"])
    if os.path.isfile(path) and md5_of(path) == pack["md5"]:
        return path
    say("downloading %s" % pack["name"])
    request = urllib.request.Request(pack["url"], headers={"User-Agent": "PS5_Sunshine texture pack installer"})
    with urllib.request.urlopen(request) as reply, open(path + ".part", "wb") as out:
        shutil.copyfileobj(reply, out, 1 << 20)
    os.replace(path + ".part", path)
    got = md5_of(path)
    if got != pack["md5"]:
        os.remove(path)
        sys.exit("get-texture-pack.py: %s is not the release this was tested with (MD5 %s, expected %s); see %s"
                 % (pack["file"], got, pack["md5"], pack["page"]))
    return path


def unpack(archive, folder):
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    if archive.endswith(".zip"):
        with zipfile.ZipFile(archive) as source:
            source.extractall(folder)
        return
    for tool in ("7z", "7zz", "7za"):
        if shutil.which(tool):
            subprocess.run([tool, "x", "-y", "-o" + folder, archive], check=True, stdout=subprocess.DEVNULL)
            return
    for tool in ("bsdtar", "tar"):  # libarchive reads 7z; GNU tar does not, and says so
        if shutil.which(tool) and subprocess.run([tool, "-xf", archive, "-C", folder], stderr=subprocess.DEVNULL).returncode == 0:
            return
    sys.exit("get-texture-pack.py: 7-Zip (7z, 7zz or 7za) or bsdtar is needed to unpack " + os.path.basename(archive))


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "out")
    downloads, original, result = (os.path.join(out, name) for name in (".texture-downloads", ".texture-original", "textures"))
    os.makedirs(downloads, exist_ok=True)
    shutil.rmtree(original, ignore_errors=True)
    for pack in PACKS:
        archive = fetch(pack, downloads)
        say("unpacking %s" % pack["file"])
        scratch = os.path.join(out, ".texture-unpack")
        unpack(archive, scratch)
        os.makedirs(original, exist_ok=True)
        shutil.move(os.path.join(scratch, pack["inside"]) if pack["inside"] else scratch, os.path.join(original, pack["as"]))
        shutil.rmtree(scratch, ignore_errors=True)
    # only the textures: the UHD pack also carries an archive of its sources
    for root, _, files in os.walk(original):
        for name in files:
            if not name.lower().endswith((".dds", ".png")):
                os.remove(os.path.join(root, name))
    say("making the console's copy (nothing larger than 2048 pixels)")
    shutil.rmtree(result, ignore_errors=True)
    subprocess.run([sys.executable, os.path.join(HERE, "shrink-texture-pack.py"), original, result, "2048"], check=True)
    shutil.rmtree(original, ignore_errors=True)
    say(result)
    print("    copy it to the console as /data/homebrew/PPSA99312/mods/textures (FTP)")
    print("    the packs belong to their authors: this copy is for your own use")


if __name__ == "__main__":
    main()
