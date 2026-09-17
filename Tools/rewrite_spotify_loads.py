#!/usr/bin/env python3
import sys
from pathlib import Path
import lief

if len(sys.argv) != 2:
    raise SystemExit("usage: rewrite_spotify_loads.py <Spotify executable>")

path = Path(sys.argv[1])
binary = lief.parse(str(path))
if binary is None:
    raise SystemExit(f"could not parse Mach-O: {path}")

remove_names = {
    "@rpath/EeveeSpotify.dylib",
    "@rpath/Orion.framework/Orion",
    "@rpath/CydiaSubstrate.framework/CydiaSubstrate",
    "@rpath/SwiftProtobuf.framework/SwiftProtobuf",
    "@rpath/PanelHost.dylib",
}

removed = []
for command in list(binary.libraries):
    if command.name in remove_names:
        removed.append(command.name)
        binary.remove(command)

binary.add_library("@rpath/PanelHost.dylib")
binary.write(str(path))

verified = lief.parse(str(path))
if verified is None:
    raise SystemExit("rewritten Mach-O could not be parsed")
final_names = [command.name for command in verified.libraries]
if final_names.count("@rpath/PanelHost.dylib") != 1:
    raise SystemExit("PanelHost load count is not exactly one")
for forbidden in remove_names - {"@rpath/PanelHost.dylib"}:
    if forbidden in final_names:
        raise SystemExit(f"forbidden dependency remains: {forbidden}")

print("removed=" + ",".join(removed))
print("added=@rpath/PanelHost.dylib")
