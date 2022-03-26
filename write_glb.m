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
    
    % padding spaces
    spl = @(buff, bytes) zeros(1, ceil(length(buff) / bytes) * bytes - length(buff)); 
    
    % number of materials
    n_mats = 0; 
    
    % parse every object
    for i = 1:nobj
        
        o.nodes{i}.mesh = i - 1;
        
        % fields
        fn = fieldnames(objects{i});
        
        % naming and coordinate system
        for j = 1:numel(fn)
            
            if strcmp(fn{j}, 'V')
                fn{j} = 'POSITION';
                objects{i}.POSITION = objects{i}.V;
                objects{i} = rmfield(objects{i}, 'V');
                if isfield(objects{i}, 'el') && isfield(objects{i}.el, 'V')
                    objects{i}.el.POSITION = objects{i}.el.V;
                end
            elseif strcmp(fn{j}, 'F')
                fn{j} = 'indices';
                objects{i}.indices = objects{i}.F;
                objects{i} = rmfield(objects{i}, 'F');
                if isfield(objects{i}, 'el') && isfield(objects{i}.el, 'F')
                    objects{i}.el.indices = objects{i}.el.F;
                end
            end
            
            if any(strcmp({'POSITION', 'NORMAL', 'TANGENT'}, fn{j}))
                objects{i}.(fn{j}) = gltf_orientation(objects{i}.(fn{j}));
            end
        end
        
        % assume this is a streamlines object
        if isfield(objects{i}, 'POSITION') && iscell(objects{i}.POSITION)
            [o, bin_chunk] = write_glb_tracks_module(objects{i}, i, o, bin_chunk);
            continue
        end
        
        % sort out the elements field
        if any(strcmp(fn, 'el'))
            el = objects{i}.el;
            objects{i} = rmfield(objects{i}, 'el');
            fn(cellfun(@(x)strcmp(x, 'el'), fn)) = [];
        else
            el = [];            
        end
        
        % ensure F and V come first
        v = strcmp(fn, 'POSITION'); f = strcmp(fn, 'indices');
        assert(any(v) && any(f), 'V/POSITION or F/indices fields missing')
        fn = {'indices' 'POSITION' fn{~v & ~f}};         
        
        % substitute 1 from indices
        objects{i}.indices = objects{i}.indices - 1;        
        
        % describe triangles 
        if isfield(el, 'material')
            o.meshes{i}.primitives{1}.material = n_mats;
            n_mats = n_mats + 1;
            o.materials{n_mats} = el.material;
        end     
        
        % enumerate accessors
        if isfield(o, 'accessors')
            ash = numel(o.accessors);
        else
            ash = 0;
        end

        % enumerate bufferViews
        if isfield(o, 'bufferViews')
            bsh = numel(o.bufferViews);
        else
            bsh = 0;
        end
        
        % deal with individual data
        for j = 1:numel(fn)
            
            u = objects{i}.(fn{j});

            % characterise data if needed (simplistic)
            if ~isfield(el, fn{j})
                el.(fn{j}) = [];
            end

            % decide on whether input is integer and select datatype            
            isint = floor(u) ~= u;
            if ~isfield(el.(fn{j}), 'ctype')
                if any(isint(:))
                    el.(fn{j}).ctype = 5126;                                 % single
                else
                    el.(fn{j}).ctype = decide_integer_type(max(u(:)));       % integer type depending on number of verts     
                end
            end

            % decide how many bytes it needs
            if ~isfield(el.(fn{j}), 'bytes')
                el.(fn{j}).bytes = 2 ^ (floor((mod(el.(fn{j}).ctype, 5120) - 1) / 2)); 
            end
                
            % decide how to classify
            if ~isfield(el.(fn{j}), 'type')
                if j == 1 || size(u, 2) == 1
                    el.(fn{j}).type = 'SCALAR';
                else
                    el.(fn{j}).type = ['VEC' num2str(size(u, 2))];
                end                
            end

            % populate primitives info
            cash = ash; % current a
            if j == 1
                o.meshes{i}.primitives{1}.indices = cash;       
                o.bufferViews{j}.target = 34963;  
            else            
                o.meshes{i}.primitives{1}.attributes.(fn{j}) = cash;
                o.bufferViews{j}.target = 34962;
            end            
            ash = ash + 1;

            % parse data
            sp = spl(bin_chunk, el.(fn{j}).bytes);                      % add spacer if needed                 
            f_data = reshape(u', 1, []);                                % a1 b1 c1 a2 b2 c2 ...    
            switch el.(fn{j}).ctype                                     % tp byte representation
                case 5123
                    f_data = typecast(uint16(f_data), 'uint8');
                case 5125
                    f_data = typecast(uint32(f_data), 'uint8');
                case 5126
                    f_data = typecast(single(f_data), 'uint8');
            end

            bin_chunk = [bin_chunk sp f_data];

            % parse json              
            o.bufferViews{bsh+1}.buffer = 0;                                % just use the same buffer for everything
            o.bufferViews{bsh+1}.byteOffset = length(bin_chunk) - length(f_data); 
            o.bufferViews{bsh+1}.byteLength = length(f_data);            

            o.accessors{cash+1}.bufferView = bsh;            
            o.accessors{cash+1}.byteOffset = 0;                           
            o.accessors{cash+1}.componentType = el.(fn{j}).ctype;  
            o.accessors{cash+1}.type = el.(fn{j}).type;
            
            bsh = bsh + 1;

            if strcmp(el.(fn{j}).type, 'SCALAR')
                o.accessors{cash+1}.count = numel(u);                 
                o.accessors{cash+1}.max = {max(single(u(:)))};  
                o.accessors{cash+1}.min = {min(single(u(:)))};
            else
                o.accessors{cash+1}.count = size(u, 1);
                o.accessors{cash+1}.max = max(single(u));  
                o.accessors{cash+1}.min = min(single(u));
            end                
        end
    end    
    
    assert(length(bin_chunk) < 2^32, 'binary data too large for GLB format');
    o.buffers{1}.byteLength = length(bin_chunk);                        % buffer - uri is omitted as GLB format
    o.asset.version = '2.0'; 
    
    %% write
    
    to_uint8 = @(x) typecast(uint32(x), 'uint8');
    pad_chunk = @(chunk, pad) [chunk pad * ones(1, ceil(length(chunk) / 4) * 4 - length(chunk))];
    
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

function int_type = decide_integer_type(max_val)

    if max_val < 2 ^ 8
        int_type = 5121;
    elseif max_val < 2 ^ 16
        int_type = 5123;
    elseif max_val < 2 ^ 32
        int_type = 5125;
    else
        warning('Possible stack overflow')
    end

end