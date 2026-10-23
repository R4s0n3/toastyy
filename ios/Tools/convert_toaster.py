#!/usr/bin/env python3
"""Convert the reference GLB to native USDZ, preserving mesh names and dimensions.

Run with Python + usd-core (see README). No Blender, remote services, or runtime
glTF loader are required. The checked-in USDZ is ready for Xcode.
"""
import hashlib
import json
from pathlib import Path
import struct
import tempfile

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils, Vt

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "toaster.glb"
OUTPUT = ROOT / "ios/Toastyy/Resources/Toaster.usdz"


def convert():
    blob = SOURCE.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", blob)
    assert (magic, version, length) == (b"glTF", 2, len(blob))
    json_length, kind = struct.unpack_from("<II", blob, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(blob[20:20 + json_length])
    offset = 20 + json_length
    binary_length, kind = struct.unpack_from("<II", blob, offset)
    assert kind == 0x004E4942
    binary = blob[offset + 8:offset + 8 + binary_length]

    def accessor(index):
        item = gltf["accessors"][index]
        view = gltf["bufferViews"][item["bufferView"]]
        assert "sparse" not in item and not item.get("normalized")
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[item["type"]]
        code = {5123: "H", 5125: "I", 5126: "f"}[item["componentType"]]
        fmt = "<" + code * count
        stride = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
        return [struct.unpack_from(fmt, binary, start + i * stride) for i in range(item["count"])]

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        stage = Usd.Stage.CreateNew(str(Path(temp) / "Toaster.usdc"))
        UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
        UsdGeom.SetStageMetersPerUnit(stage, 1)
        root = UsdGeom.Xform.Define(stage, "/Toaster")
        stage.SetDefaultPrim(root.GetPrim())
        materials = []
        for i, original in enumerate(gltf["materials"]):
            pbr = original["pbrMetallicRoughness"]
            material = UsdShade.Material.Define(stage, f"/Toaster/Materials/Material_{i}")
            shader = UsdShade.Shader.Define(stage, f"{material.GetPath()}/Shader")
            shader.CreateIdAttr("UsdPreviewSurface")
            shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(*pbr["baseColorFactor"][:3]))
            shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(max(0.42, pbr["roughnessFactor"]))
            shader.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(min(0.72, pbr["metallicFactor"]))
            material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
            materials.append(material)

        def write_mesh(name, positions, normals, uvs, triangles, material):
            used = sorted(set(triangles))
            remap = {old: new for new, old in enumerate(used)}
            center = [(min(positions[i][a] for i in used) + max(positions[i][a] for i in used)) / 2 for a in range(3)]
            pivot = UsdGeom.Xform.Define(stage, f"/Toaster/{name}")
            pivot.AddTranslateOp().Set(Gf.Vec3d(*center))
            mesh = UsdGeom.Mesh.Define(stage, f"{pivot.GetPath()}/Geometry")
            mesh.CreatePointsAttr(Vt.Vec3fArray([Gf.Vec3f(*(positions[i][a] - center[a] for a in range(3))) for i in used]))
            mesh.CreateFaceVertexCountsAttr([3] * (len(triangles) // 3))
            mesh.CreateFaceVertexIndicesAttr([remap[i] for i in triangles])
            mesh.CreateNormalsAttr(Vt.Vec3fArray([Gf.Vec3f(*normals[i]) for i in used]))
            mesh.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
            mesh.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
            # USD texture coordinates use a bottom-left origin.
            uv = UsdGeom.PrimvarsAPI(mesh).CreatePrimvar("st", Sdf.ValueTypeNames.TexCoord2fArray, UsdGeom.Tokens.vertex)
            uv.Set(Vt.Vec2fArray([Gf.Vec2f(uvs[i][0], 1 - uvs[i][1]) for i in used]))
            UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(material)

        triangles_written = 0
        for node in gltf["nodes"]:
            # Fail explicitly if an updated asset introduces transforms this converter doesn't handle.
            assert not any(k in node for k in ("matrix", "translation", "rotation", "scale"))
            if "mesh" not in node:
                continue
            mesh = gltf["meshes"][node["mesh"]]
            assert len(mesh["primitives"]) == 1
            primitive = mesh["primitives"][0]
            assert primitive.get("mode", 4) == 4
            attributes = primitive["attributes"]
            positions = accessor(attributes["POSITION"])
            normals = accessor(attributes["NORMAL"])
            uvs = accessor(attributes["TEXCOORD_0"])
            indices = [i[0] for i in accessor(primitive["indices"])]
            assert len(indices) % 3 == 0
            triangles_written += len(indices) // 3
            groups = {node["name"]: indices}
            if node["name"] == "button_002_mesh":
                # Match the web client's z > -0.02 carriage split, retaining the four cabinet buttons.
                groups = {"button_002_mesh": [], "lever_insert_mesh": []}
                for start in range(0, len(indices), 3):
                    triangle = indices[start:start + 3]
                    moving = [positions[i][2] > -0.02 for i in triangle]
                    assert all(moving) or not any(moving), "Triangle crosses the carriage split"
                    groups["lever_insert_mesh" if all(moving) else "button_002_mesh"].extend(triangle)
            for name, group in groups.items():
                write_mesh(name, positions, normals, uvs, group, materials[primitive["material"]])

        stage.GetRootLayer().Save()
        assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(stage.GetRootLayer().identifier), str(OUTPUT))
    reopened = Usd.Stage.Open(str(OUTPUT))
    assert reopened.GetDefaultPrim().GetName() == "Toaster"
    actual = sum(len(UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()) for p in reopened.Traverse() if p.IsA(UsdGeom.Mesh))
    assert actual == triangles_written
    provenance = {
        "source": "toaster.glb", "webCommit": "fd5b6a332b9eb4cb22b0d4480835119a35bb7294",
        "sourceSHA256": hashlib.sha256(blob).hexdigest(),
        "triangles": actual, "metersPerUnit": 1, "upAxis": "Y",
        "conversion": "Original geometry and normals; centered pivots; split moving lever insert; USD Preview Surface materials.",
    }
    (OUTPUT.parent / "Toaster.provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(f"Converted {actual:,} triangles to {OUTPUT}")


if __name__ == "__main__":
    convert()
