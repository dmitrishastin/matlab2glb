function [o, bin_chunk] = write_glb_tracks_module(obj, i, o, bin_chunk)

    spl = @(buff, bytes) zeros(1, ceil(length(buff) / bytes) * bytes - length(buff));
    sl_len = cellfun(@(x)size(x, 1), obj.POSITION);  
    len_shift = [0 cumsum(sl_len(1:end - 1))];

    fn = fieldnames(obj);        
    % POSITION NORMAL TANGENT COLOR_0

    % merge all strealmine vertex data
    merged = cell(numel(fn), 1);
    attr_off = zeros(numel(fn), 1);
    for j = 1:numel(fn)
        merged{j} = cell2mat(obj.(fn{j})(:));
        attr_off(j) = size(merged{j}, 2); 
    end        
    merged = cell2mat(merged');
    sum_off = sum(attr_off * 4);
    attr_off = cumsum([0 attr_off(1:j-1)]) * 4;

    % process into binary
    sp = spl(bin_chunk, 4);                      % add spacer if needed  
    f_data = reshape(merged', 1, []);                                
    f_data = typecast(single(f_data), 'uint8'); 
    bin_chunk = [bin_chunk sp f_data];  
    
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
    
    % parse some json     
    o.bufferViews{bsh+1}.target = 34962;          
    o.bufferViews{bsh+1}.buffer = 0;                               
    o.bufferViews{bsh+1}.byteOffset = length(bin_chunk) - length(f_data); 
    o.bufferViews{bsh+1}.byteLength = length(f_data);
    o.bufferViews{bsh+1}.byteStride = sum_off;    

    % deal with individual streamlines - one primitive per each     
    for sl = 1:numel(sl_len)

        o.meshes{i}.primitives{sl}.mode = 3;            

        for j = 1:numel(fn)

            % accessors: different per streamline and attribute 
            a = ash + (sl - 1) * numel(fn) + j;
            o.meshes{i}.primitives{sl}.attributes.(fn{j}) = a - 1; 
            o.accessors{a}.bufferView = bsh;            
            o.accessors{a}.byteOffset = attr_off(j) + len_shift(sl) * sum_off; 
            o.accessors{a}.componentType = 5126;  
            o.accessors{a}.type = ['VEC' num2str(size(obj.(fn{j}){sl}, 2))];
            o.accessors{a}.count = sl_len(sl);
            o.accessors{a}.max = max(single(obj.(fn{j}){sl}));  
            o.accessors{a}.min = min(single(obj.(fn{j}){sl}));

        end                
    end        
end  