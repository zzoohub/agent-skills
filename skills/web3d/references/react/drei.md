# Drei under WebGPURenderer

drei was built for `WebGLRenderer`: run the grep rule (SKILL.md, Decide) on every helper used under `WebGPURenderer`. At drei 10.7.9 the scene utilities (`Bounds`, `Center`, `Float`, `Instances`, `Html`, `useGLTF`) pass.

Common hits (not exhaustive):

| Helpers | Instead |
|---|---|
| Materials: `MeshTransmissionMaterial`, `MeshReflectorMaterial`, `MeshDistortMaterial`, `MeshWobbleMaterial`, `shaderMaterial` | Node materials: `MeshPhysicalNodeMaterial` with `transmission`; TSL `reflector()`; a `positionNode` displacement (`../shaders.md`) |
| Shadows: `ContactShadows`, `AccumulativeShadows`, `SoftShadows`, and so `Stage` | Bake the shadow into a texture once, or a plane with `ShadowNodeMaterial` under a real shadow-casting light |
| `Line`, `Edges`, `Segments` | `Line2` or `LineSegments2` from `three/addons/lines/webgpu/`, with `Line2NodeMaterial` |
| `Sky` | `SkyMesh` from `three/addons/objects/SkyMesh.js` |
| `Sparkles`, `Stars`, `Cloud`, `Grid`, `Outlines`, `Image` | TSL rebuilds (sprites: `../shaders.md` § Compute) |
| `Text` (troika) | Stay on `WebGLRenderer`, or a `CanvasTexture` label on a plane, or `<Html>` outside XR |
| `@react-three/uikit` | Stay on `WebGLRenderer` |

A clean grep is necessary, not sufficient: look at every helper on both backends.

- `<Environment preset>` downloads its HDRI from a third-party CDN at runtime. In production, self-host the file and pass it with `files` (availability, COEP). Its `ground` prop fails the grep.
- `occlude` belongs to `<Html>`, not to `<Text>` (a mesh is depth-tested already).
- `<Text>` loads its font asynchronously, so wrap it in `<Suspense>`; non-Latin scripts need a `font` URL whose file contains the glyphs.
