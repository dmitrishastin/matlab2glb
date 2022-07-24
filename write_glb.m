function write_glb(fname, varargin)
    
    %% prep
    if nargin == 1
        error('supply objects to write')
    end
    
    objects = {};    
    for i = 1:numel(varargin)        
        add_obj = varargin{i};        
        if iscell(add_obj)
            objects(end + 1:end + numel(add_obj)) = add_obj;
        else
            objects{end + 1} = add_obj;
        end        
    end    
    
    nobj = numel(objects);
    if numel(objects) == 1
        o.scenes{1}.nodes = {0};
    else
        o.scenes{1}.nodes = (0:nobj - 1);
    end

    %% json structure

    o.scene = 0;        
    
    % start the buffer chunk 
    bin_chunk = []; 
    
    % counter
    n_mats = 0; % materials
    
    % parse every object
    for i = 1:nobj
        
        o.nodes{i}.mesh = i - 1;
        
        % fields
        fn = fieldnames(objects{i});
        
        % naming and coordinate system
        for j = 1:numel(fn)
            
            % change V to POSITION, F to indices            
            if strcmp(fn{j}, 'V')
                fn{j} = 'POSITION';
                objects{i}.POSITION = objects{i}.V;
                objects{i} = rmfield(objects{i}, 'V');
                if isfield(objects{i}, 'prop') && isfield(objects{i}.prop, 'V')
                    objects{i}.prop.POSITION = objects{i}.prop.V;
                end
            elseif strcmp(fn{j}, 'F')
                fn{j} = 'indices';
                objects{i}.indices = objects{i}.F;
                objects{i} = rmfield(objects{i}, 'F');
                if isfield(objects{i}, 'prop') && isfield(objects{i}.prop, 'F')
                    objects{i}.prop.indices = objects{i}.prop.F;
                end
            end
            
            % re-orient coordinate data
            if any(strcmp({'POSITION', 'NORMAL', 'TANGENT'}, fn{j})) 
                objects{i}.(fn{j}) = gltf_orientation(objects{i}.(fn{j}));
            end
        end
        
        % sort out the properties field
        if any(strcmp(fn, 'prop'))
            prop = objects{i}.prop;
            objects{i} = rmfield(objects{i}, 'prop');
            fn(cellfun(@(x)strcmp(x, 'prop'), fn)) = [];
        else
            prop = [];            
        end
        
        % where position is a cell, writes each cell as a separate
        % primitive with all primitives being very similar (points, lines
        % etc), does not handle indices/faces
        if isfield(objects{i}, 'POSITION') && iscell(objects{i}.POSITION)
            [o, bin_chunk] = write_glb_array_module(objects{i}, prop, i, o, bin_chunk);
            continue
        end
        
        % apply mode - standard mesh is default
        if isfield(prop, 'mode')
            o.meshes{i}.primitives{1}.mode = convert_mode(prop.mode);
        else
            o.meshes{i}.primitives{1}.mode = 4;
        end
        
        % apply material
        if isfield(prop, 'material')
            o.meshes{i}.primitives{1}.material = n_mats;
            n_mats = n_mats + 1;
            o.materials{n_mats} = prop.material;
        end
        
        % PARSE INDICES 
        if any(strcmp(fn, 'indices'))            
            indices_data = objects{i}.indices - 1; % substitute 1 from the indices
            if ~isfield(prop, 'indices')
                prop.indices = [];
            end
            prop.indices.type = 'SCALAR';
            if ~all(ismember({'type' 'ctype' 'bytes'}, fieldnames(prop.indices)))
                prop.indices = classify_data(indices_data, prop.indices);
            end
            cash = ash(o); cbsh = bsh(o); % current a & b
            
            % append data
            [bin_chunk, lens] = add_data(indices_data, prop.indices, bin_chunk);
            
            % append json
            lens(3) = numel(indices_data); % number of indices total
            lens(4) = 0; % byteOffset for accessors
            mm = [];
            mm(1) = max(uint32(indices_data(:)));
            mm(2) = min(uint32(indices_data(:)));
            o = add_json_bv(o, cbsh, lens);
            o = add_json_ac(o, cash, cbsh, prop.indices, lens, mm);
            o.meshes{i}.primitives{1}.indices = cash;       
            o.bufferViews{cbsh + 1}.target = 34963;
        end
        
        
        % PARSE ATTRIBUTES
        attribute_names = {'POSITION' 'NORMAL' 'TANGENT' 'COLOR_' 'TEXCOORD_' 'JOINTS_' 'WEIGHTS_'};
        primitive_data = [];
        cen = []; % number of components per element
        elen = []; % length of each element in bytes
        ao = []; % attribute order
        
        for j = 1:numel(fn) % work out properties and combine the data first
            det_field = ~cellfun(@isempty, regexp(fn{j}, attribute_names, 'once'));            
            if any(det_field)     
                ao(end + 1) = j;
                if ~isfield(prop, fn{j})
                    prop.(fn{j}) = [];
                end
                prop.(fn{j}).ctype = 5126; % all vertex component data is of single type
                prop.(fn{j}).bytes = 4;
                % if ~all(ismember({'type' 'ctype' 'bytes'}, fieldnames(prop.(fn{j}))))
                if ~isfield(prop.(fn{j}), 'type')
                    prop.(fn{j}) = classify_data(objects{i}.(fn{j}), prop.(fn{j}));
                end    
                cen(end + 1) = size(objects{i}.(fn{j}), 2);
                elen(end + 1) = cen(end) * 4; % prop.(fn{j}).bytes; 
                primitive_data = [primitive_data objects{i}.(fn{j})];
            end
        end
        
        % append data - just use properties of the first attribute, doesn't matter
        [bin_chunk, lens] = add_data(primitive_data, prop.(fn{ao(1)}), bin_chunk);
        lens(3) = size(primitive_data, 1); % number of vertices total
        
        % append bufferView json 
        cbsh = bsh(o); % current b
        o.bufferViews{cbsh+1}.byteStride = sum(elen);
        o = add_json_bv(o, cbsh, lens);
        offsets = cumsum([0 elen(1:end - 1)]); 
        
        % append accessors json
        for j = 1:numel(ao) % calculate offsets and combine the data first
            cash = ash(o); % current a
            mm = [];
            mm(1, :) = max(single(objects{i}.(fn{ao(j)})), [], 1);
            mm(2, :) = min(single(objects{i}.(fn{ao(j)})), [], 1);
            lens(4) = offsets(j); % byteOffset for accessors
            o = add_json_ac(o, cash, cbsh, prop.(fn{ao(j)}), lens, mm);
            o.meshes{i}.primitives{1}.attributes.(fn{ao(j)}) = cash;
            o.bufferViews{cbsh+1}.target = 34962;
        end        
    end
    
    assert(length(bin_chunk) < 2^32, 'binary data too large for GLB format');
    o.buffers{1}.byteLength = length(bin_chunk); % buffer - uri is omitted as GLB format
    o.asset.version = '2.0'; 
    
    %% write
    
    to_uint8 = @(x) typecast(uint32(x), 'uint8');
    pad_chunk = @(chunk, pad) [chunk pad * ones(1, ceil(length(chunk) / 4) * 4 - length(chunk))];
    
    % encode all numbers in json as uint64 otherwise jsonencode will force
    % scientific notation for very large numbers which will read to
    % read problems with other software
    o = conv2uint64(o);
    
    % json chunk
    jsn = uint8(jsonencode(o)); % json byte values
    jsn = pad_chunk(jsn, 32); % pad with trailing spaces
    clen = pad_chunk(to_uint8(length(jsn)), 0); % length of json chunk data in bytes
    ctype = [74 83 79 78]; % JSON in ASCII
    json_chunk = [clen ctype jsn];
    
    % bin chunk
    bin_chunk = pad_chunk(bin_chunk, 0); % pad with trailing zeroes
    clen = pad_chunk(to_uint8(length(bin_chunk)), 0); % length of bin chunk data in bytes
    ctype = [66 73 78 00]; % BIN in ASCII
    bin_chunk = [clen ctype bin_chunk];
    
    % header
    magic = [103 108 84 70]; % magic
    version = pad_chunk(2, 0); % version
    tlen = pad_chunk(to_uint8(12 + length(json_chunk) + length(bin_chunk)), 0); % total length
    
    % write the data
    fid = fopen(fname, 'W');    
    fwrite(fid, [magic version tlen json_chunk bin_chunk]);
    fclose(fid);

end

function prop = classify_data(data, prop)

    % decide on whether input is integer and select datatype            
    isint = floor(data) == data;
    if ~isfield(prop, 'ctype')
        if ~all(isint(:)) || any(data(:) < 0)               % add signed integers later
            prop.ctype = 5126;                                % single
        else
            prop.ctype = decide_integer_type(max(data(:)));   % integer type depending on number of verts     
        end
    end

    % decide how many bytes it needs
    if ~isfield(prop, 'bytes')
        prop.bytes = 2 ^ (floor((mod(prop.ctype, 5120) - 1) / 2)); 
    end

    % decide how to classify
    if ~isfield(prop, 'type')
        ncol = size(data, 2);
        if ncol == 1
            prop.type = 'SCALAR';
        else
            prop.type = ['VEC' num2str(ncol)];
        end                
    end
end

function int_type = decide_integer_type(max_val)

    % add signed integers later
    
    if max_val < 2 ^ 8 - 1
        int_type = 5121;
    elseif max_val < 2 ^ 16 - 1
        int_type = 5123;
    elseif max_val < 2 ^ 32 - 1
        int_type = 5125;
    else
        int_type = 5126;
        warning('Converting integers to float')
    end

end

function [bin_chunk, lens] = add_data(data, prop, bin_chunk)

    % padding spaces
    spl = @(buff, bytes) zeros(1, ceil(length(buff) / bytes) * bytes - length(buff));     
    
    % parse data
    sp = spl(bin_chunk, prop.bytes);    % add spacer if needed                 
    data = reshape(data', 1, []);       % a1,1 a1,2 a1,3 b1,1 b1,2 b1,3 a2,1 a2,2 a2,3 ...
    switch prop.ctype                   % tp byte representation
        case 5120
            data = typecast(int8(data), 'uint8');
        case 5122
            data = typecast(int16(data), 'uint8');
        case 5123
            data = typecast(uint16(data), 'uint8');
        case 5125
            data = typecast(uint32(data), 'uint8');
        case 5126
            data = typecast(single(data), 'uint8');
    end

    % add data
    bin_chunk = [bin_chunk sp data];
    
    % work out lengths for json
    lens(1) = length(bin_chunk) - length(data);
    lens(2) = length(data);
    
end

function o = add_json_bv(o, cbsh, lens)

    % add json for bufferView
    o.bufferViews{cbsh+1}.buffer = 0; % just use the same buffer for everything
    o.bufferViews{cbsh+1}.byteOffset = lens(1); 
    o.bufferViews{cbsh+1}.byteLength = lens(2);

end

function o = add_json_ac(o, cash, cbsh, prop, lens, mm)

    % add json for accessors
    o.accessors{cash+1}.bufferView = cbsh;     
    o.accessors{cash+1}.componentType = prop.ctype;  
    o.accessors{cash+1}.type = prop.type;
    o.accessors{cash+1}.count = lens(3);
    o.accessors{cash+1}.byteOffset = lens(4);

    if strcmp(prop.type, 'SCALAR')
        o.accessors{cash+1}.max = {mm(1)};  
        o.accessors{cash+1}.min = {mm(2)};
    else        
        o.accessors{cash+1}.max = mm(1, :);  
        o.accessors{cash+1}.min = mm(2, :);
    end     

end

function n = ash(o)

    % next available accessors index (starts with 0)
    if isfield(o, 'accessors')
        n = numel(o.accessors);
    else
        n = 0;
    end
end

function n = bsh(o)

    % next available bufferViews index (starts with 0)
    if isfield(o, 'bufferViews')
        n = numel(o.bufferViews);
    else 
        n = 0;
    end
end

function o = conv2uint64(o)

    if isstruct(o)
        fn = fieldnames(o);
        for i = 1:numel(fn)
            o.(fn{i}) = conv2uint64(o.(fn{i}));
        end
    elseif iscell(o)
        for i = 1:numel(o)
            o{i} = conv2uint64(o{i});
        end
    elseif isnumeric(o) && all(fix(o) == o) % make sure only integers get converted
        o = uint64(o);
    end

end