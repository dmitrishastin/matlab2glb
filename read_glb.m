function str = read_glb(fname)

    % focused on the meshed objects

    %% read

    fid = fopen(fname, 'r');
    str.binary = fread(fid);
    fclose(fid);
    
    %% read chunks
    
    to_uint16 = @(x) typecast(uint8(x), 'uint16');
    to_uint32 = @(x) typecast(uint8(x), 'uint32');
    to_single = @(x) typecast(uint8(x), 'single');    
    
    str.header.magic = char(str.binary(1:4)');
    str.header.version = to_uint32(str.binary(5:8));
    str.header.total_length = to_uint32(str.binary(9:12));
       
    c = 1;
    s = 13;
    
    while s < str.header.total_length

        chunks{c}.length = to_uint32(str.binary(s:s + 3));
        chunks{c}.type = to_uint32(str.binary(s + 4:s + 7));
        chunks{c}.data = str.binary(s + 8:s+chunks{c}.length + 7);
        s = s + chunks{c}.length + 8;
        c = c + 1;
        
    end
    
    %% parse chunks
    
    d = [];
    
    for c = 1:numel(chunks)        
        switch chunks{c}.type
            case 1313821514 % json
                str.json = jsondecode(char(chunks{c}.data'));
                to_cell = {'meshes' 'bufferViews'};
                for i = 1:numel(to_cell)
                    if isstruct(str.json.(to_cell{i}))
                        for j = 1:numel(str.json.(to_cell{i}))
                            new_str{j} = str.json.(to_cell{i})(j);
                        end
                        str.json.(to_cell{i}) = new_str;
                    end
                end
                d = [d c];
            case 5130562 % bin
                data = chunks{c}.data;
                d = [d c];
        end
    end
    
    chunks(d) = [];
    
    if ~isempty(chunks)
        str.other_chunks = chunks;
    end
    
    str = rmfield(str, 'binary');
    
    %% parse data    
    
    meshes = {};
           
    for i = 1:numel(str.json.meshes)
        
        if isfield(str.json.meshes{i}, 'name')
            meshes{i}.name = str.json.meshes{i}.name; 
        end
        
        if ~isfield(str.json.meshes{i}, 'primitives')
            str.json.meshes{i}.primitives{1} = str.json.meshes{i};
        elseif isstruct(str.json.meshes{i}.primitives)
            new_str = str.json.meshes{i}.primitives;
            str.json.meshes{i} = rmfield(str.json.meshes{i}, 'primitives');
            str.json.meshes{i}.primitives{1} = new_str;
        end 
        
        primitives = {};
        
        % go through each primitive
        for p = 1:numel(str.json.meshes{i}.primitives{1})

            p_raw = str.json.meshes{i}.primitives{p};
            
            % check if data external - not parsing for now
            if str.json.bufferViews{str.json.accessors(p_raw.indices + 1).bufferView + 1}.buffer
                continue
            end

            % data types
            fn = fieldnames(p_raw.attributes);
            fn(strcmp(fn, 'POSITION')) = [];

            % parse each type    
            for j = 1:numel(fn) + 2        

                % choose the correct accessor and note down data name
                switch j 
                    case 1
                        a = p_raw.indices; % faces
                        tag = 'F';
                    case 2
                        a = p_raw.attributes.POSITION; % vertices
                        tag = 'V';
                    otherwise
                        a = p_raw.attributes.(fn{j - 2}); 
                        tag = fn{j - 2};
                end
                a = a + 1;

                % get the pointers
                bw  = str.json.accessors(a).bufferView + 1;          % bufferView
                bwo = str.json.bufferViews{bw}.byteOffset;           % bufferView offset
                aco = str.json.accessors(a).byteOffset;              % accessors offset
                acc = str.json.accessors(a).count;                   % accessors count
                off = bwo + aco + 1;                                 % accessors offset + bufferView offset    
                
                % work out number of components per element
                switch str.json.accessors(a).type                    % accessors type
                    case 'SCALAR'
                        cpe = 1;
                    case 'VEC3'
                        cpe = 3;
                    case 'VEC2'
                        cpe = 2;
                    otherwise
                        error('add other options')
                end
                
                % work out number of bytes per component
                ctp = str.json.accessors(a).componentType;           % accessors component type
                nbt = 2 ^ (floor((mod(ctp, 5120) - 1) / 2));                      
                
                % work out the stride
                if isfield(str.json.bufferViews{bw}, 'byteStride')                  
                    bws = str.json.bufferViews{bw}.byteStride;       % bufferView stride
                else
                    bws = cpe * nbt;
                end
                
                % extract relevant bytes
                type_data = data(off:end);
                type_data = reshape(type_data(1:end-mod(length(type_data),bws)), bws, []);
                type_data = type_data(1:cpe * nbt, 1:acc);
                type_data = type_data(:);                

                % parse as appropriate
                switch str.json.accessors(a).componentType
                    case 5121
                        parsed_data = type_data;
                    case 5123
                        parsed_data = to_uint16(type_data);
                    case 5125
                        parsed_data = to_uint32(type_data);
                    case 5126
                        parsed_data = to_single(type_data);
                    otherwise
                        error('add other options')
                end            

                if j == 1
                    parsed_data = parsed_data + 1; % add 1 to indices - matlab compatibility
                    parsed_data = reshape(parsed_data', 3, [])';                
                else
                    parsed_data = reshape(parsed_data', cpe, [])';
                end
                
                parsed_data = double(parsed_data); % for matlab

                primitives{p}.(tag) = parsed_data;

            end          
        end 
        
        if numel(primitives) > 1
            meshes{i}.primitives = primitives;
        else
            fn = fieldnames(primitives{1});
            for f = 1:numel(fn)
                meshes{i}.(fn{f}) = primitives{1}.(fn{f});
            end
        end
    end
    
    if numel(meshes) == 1
        meshes = meshes{1};
    end
    
    str.mesh = meshes;    
    
end