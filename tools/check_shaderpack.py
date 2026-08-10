#!/usr/bin/env python3
"""Small dependency-free structural check for the Chill Shaders release tree."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
ENTRY_POINTS = [
    "shadow.vsh", "shadow.fsh", "gbuffers_terrain.vsh", "gbuffers_terrain.fsh",
    "gbuffers_water.vsh", "gbuffers_water.fsh", "gbuffers_entities.vsh",
    "gbuffers_entities.fsh", "gbuffers_hand.vsh", "gbuffers_hand.fsh",
    "gbuffers_weather.vsh", "gbuffers_weather.fsh", "composite.vsh", "composite.fsh",
    "final.vsh", "final.fsh",
]
DIMENSION_ENTRY_POINTS = [
    "world-1/gbuffers_terrain.vsh", "world-1/gbuffers_terrain.fsh",
    "world-1/gbuffers_skybasic.vsh", "world-1/gbuffers_skybasic.fsh",
    "world1/gbuffers_terrain.vsh", "world1/gbuffers_terrain.fsh",
    "world1/gbuffers_skybasic.vsh", "world1/gbuffers_skybasic.fsh",
]
OPTIONS = {
    "SHADOW_RESOLUTION", "SHADOW_DISTANCE", "SHADOW_FILTER", "EXPOSURE",
    "FOG_DENSITY", "WATER_REFLECTION_STRENGTH", "FOLIAGE_WAVING",
    "BLOOM_INTENSITY", "WATER_QUALITY", "ATMOSPHERE_QUALITY", "POST_PROCESSING",
    "BLOOM", "FOLIAGE_WIND", "WATER_REFLECTIONS",
}

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if not (SHADERS / "shaders.properties").is_file():
        fail("shaders/shaders.properties is missing")
    entry_files = list(SHADERS.rglob("*.vsh")) + list(SHADERS.rglob("*.fsh"))
    for path in entry_files:
        rel = path.relative_to(SHADERS).as_posix()
        content = path.read_text(encoding="utf-8")
        if not content.startswith("#version "):
            fail(f"{rel} must start with a GLSL #version directive")
    for rel in ENTRY_POINTS + DIMENSION_ENTRY_POINTS:
        if not (SHADERS / rel).is_file():
            fail(f"required entry point {rel} is missing")

    visited: set[Path] = set()
    def check_includes(path: Path) -> None:
        if path in visited:
            return
        visited.add(path)
        content = path.read_text(encoding="utf-8")
        for include in re.findall(r'#include\s+"([^"]+)"', content):
            target = SHADERS / include.lstrip("/")
            if not target.is_file():
                fail(f"{path.relative_to(SHADERS)} includes missing file {include}")
            check_includes(target)
    for path in entry_files:
        check_includes(path)
        for args in re.findall(r"const\s+vec4\s+\w+ClearColor\s*=\s*vec4\(([^)]*)\)", path.read_text(encoding="utf-8")):
            if len([value for value in args.split(",") if value.strip()]) != 4:
                fail(f"{path.relative_to(SHADERS)} has a ClearColor vec4 without four components")
    settings = (SHADERS / "lib" / "settings.glsl").read_text(encoding="utf-8")
    defined = set(re.findall(r"^#define\s+([A-Z0-9_]+)", settings, re.M))
    missing = OPTIONS - defined
    if missing:
        fail("settings macros missing: " + ", ".join(sorted(missing)))
    properties = (SHADERS / "shaders.properties").read_text(encoding="utf-8")
    for profile in ("Potato", "Chill", "High"):
        match = re.search(rf"^profile\.{profile}=(.+)$", properties, re.M)
        if not match:
            fail(f"profile.{profile} is missing")
        if "SHADOW_RESOLUTION=" not in match.group(1):
            fail(f"profile.{profile} does not configure shadow resolution")
        for option in ("SHADOW_DISTANCE=", "SHADOW_FILTER=", "WATER_QUALITY=", "ATMOSPHERE_QUALITY=", "POST_PROCESSING="):
            if option not in match.group(1):
                fail(f"profile.{profile} does not configure {option[:-1]}")
    profile_lines = [re.search(rf"^profile\.{profile}=(.+)$", properties, re.M).group(1) for profile in ("Potato", "Chill", "High")]
    if len(set(profile_lines)) != 3:
        fail("Potato, Chill and High profiles must have distinct settings")
    for page in ("LIGHTING", "SHADOWS", "WATER", "ATMOSPHERE", "POST_PROCESSING", "PERFORMANCE"):
        if f"screen.{page}=" not in properties:
            fail(f"settings screen {page} is missing")
    if "clouds=fancy" not in properties:
        fail("fancy clouds must be enabled for the shaded 3D cloud pass")
    print("Shader pack structural checks passed.")

if __name__ == "__main__":
    main()
