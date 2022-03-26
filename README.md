# matlab2glb
 Simplistic converter for triangular meshes and tractography data from MATLAB to glb (glTF binary) format

Supply individual objects (mesh objects or tracts).

Each object to have following fields:

- indices: face array (MATLAB convention, indices from 1 onwards)
- POSITION: vertex coordinates
- any other attributes - [as specified](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#meshes-overview)

Rows mean individual entries (e.g., POSITION as Nx3 array where columns are X,Y,Z).
Spatial data will automatically be converted to glTF coordinate system.

```
brain.indices = F;
brain.POSITION = V;
brain.COLOR_0 = C;
```

[Accessor type](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#_accessor_type) and [component type](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#_accessor_componenttype) will be automatically deducted unless provided within 'el' field of the object under the same name as the data it is referring to:

```
brain.el.indices.ctype = 5121;
brain.el.indices.type = 'SCALAR';
brain.el.POSITION.ctype = 5126;
brain.el.POSITION.type = 'VEC3';
```

Some support of [materials](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#materials) is present. Type gltf_materials to see options - these are manually added/edited in materials.csv. Select option by providing its index or name:

```
brain.el.materials = gltf_materials(1);
% OR
brain.el.materials = gltf_materials('GlassBrain');
```

Add additional objects either separated by coma or within a cell array:

```
tract.POSITION = tck.data;
tract.COLOR_0 = convert_colourmap(tsf.data, 'cool', [0 1]);
write_glb('brain_and_tract.glb', brain, tract);
```
