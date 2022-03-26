function out = gltf_material(mname)
    
    matfile = [fileparts(which(mfilename)) filesep 'materials.csv'];
    assert(logical(exist(matfile, 'file')), 'materials.csv not found')
    materials = readtable(matfile, 'ReadVariableNames', 1);
    ind = 1:size(materials, 1);
    materials.N = ind';
    materials = [materials(:, end) materials(:, 1:end-1)];
    
    if nargin 
        if isnumeric(mname)
            midx = mname;
            assert(size(materials, 1) >= midx && midx == floor(midx) && midx > 0, 'index does not match')
        else
            midx = strcmp(materials.name, mname);
            assert(~isempty(midx), 'material does not exist')
        end
        
        out.pbrMetallicRoughness.baseColorFactor = [materials.R(midx) materials.G(midx) materials.B(midx) materials.A(midx)];
        out.pbrMetallicRoughness.metallicFactor = materials.metallicFactor(midx);
        out.pbrMetallicRoughness.roughnessFactor = materials.roughnessFactor(midx);
        out.alphaMode = materials.alphaMode{midx};
    else        
        out = materials;        
    end

end