# matlab2glb
 Simplistic converter for triangular meshes and tractography data from MATLAB to glb (glTF binary) format. 
 
 Supply individual objects (mesh objects or tracts). Each object to have the following fields:

- indices: face array (MATLAB convention, indices from 1 onwards)
- POSITION: vertex coordinates
- any other attributes [as specified](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#meshes-overview)

Rows refer to individual elements (e.g., POSITION is an Nx3 array where columns are X,Y,Z and rows are vertices).
Spatial data will get automatically converted to glTF coordinate system.

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

Some support of [materials](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#materials) is present. Type gltf_materials to see options - these are manually added/edited in materials.csv:

```
>> gltf_material

ans =

  8×9 table

    N           name            R       G       B      A      metallicFactor    roughnessFactor    alphaMode 
    _    __________________    ____    ____    ___    ____    ______________    _______________    __________

    1    {'GlassPinkBrain'}       1     0.5    0.5    0.15           0                  1          {'BLEND' }
    2    {'GlassBlueBrain'}     0.3     0.5      1     0.1           0                  1          {'BLEND' }
    3    {'PinkBrain'     }    0.75     0.5    0.5       1         0.5               0.75          {'OPAQUE'}
    4    {'Chrome'        }       1       1      1       1           1                  0          {'OPAQUE'}
    5    {'Gold'          }       1    0.75      0       1           1                0.2          {'OPAQUE'}
    6    {'Ruby'          }     0.6       0      0    0.75         0.5                  0          {'BLEND' }
    7    {'GreenMetal'    }       0       1      0       1           1                0.2          {'OPAQUE'}
    8    {'BlueMetal'     }       0       0      1       1           1                0.2          {'OPAQUE'}
```

Select material by providing its index or name:

```
brain.el.materials = gltf_materials(1);
% OR
brain.el.materials = gltf_materials('GlassPinkBrain');
```

Add additional objects either separated by coma or within a cell array:

```
tract.POSITION = tck.data; % streamlines objects will store individual data types in cell arrays where each cell refers a streamline
tract.COLOR_0 = convert_colourmap(tsf.data, 'cool', [0 1]);
write_glb('brain_and_tract.glb', brain, tract);
% OR
obj{1} = brain;
obj{2} = tract;
write_glb('brain_and_tract.glb', obj);
```
