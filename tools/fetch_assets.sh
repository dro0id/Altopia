#!/usr/bin/env bash
# Télécharge les assets 3D libres de droits dans assets_src/ (ignoré par Git).
# Les modèles NASA sont compressés en Draco : Godot 4.3 ne les lit pas,
# on les décompresse avec gltf-transform (npx @gltf-transform/cli copy in.glb out.glb).
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)/assets_src"; mkdir -p "$D/nasa" "$D/textures" "$D/polyhaven"
N=https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model
curl -sSL -o "$D/nasa/lander.glb" "$N/apollo-lunar-module/Apollo%20Lunar%20Module.glb"
curl -sSL -o "$D/nasa/rover.glb"  "$N/mars-2020-perseverance-rover/Mars%202020%20Perseverance%20Rover.glb"
curl -sSL -o "$D/nasa/dawn.glb"   "$N/dawn/Dawn.glb"
curl -sSL -o "$D/nasa/suit.glb"   "$N/advanced-crew-escape-suit/Advanced%20Crew%20Escape%20Suit.glb"
curl -sSL -o "$D/nasa/bennu.glb"  "$N/1999-rq36-asteroid/1999%20RQ36%20asteroid.glb"
for t in 2k_earth_daymap 2k_earth_clouds 2k_mars 2k_moon 2k_jupiter 2k_saturn 2k_venus_surface 2k_sun; do
  curl -sSL -o "$D/textures/$t.jpg" "https://www.solarsystemscope.com/textures/download/$t.jpg"
done
echo "OK : $D"
