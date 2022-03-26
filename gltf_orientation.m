function data = gltf_orientation(data)

    % RAS to LSA
    
    d2c = false;
    if ~iscell(data)
        d2c = true;
        data = {data};
    end
    
    cn = 1:size(data{1}, 2);
    cn(1:3) = [];    
    pc = [1 3 2 cn];
    
    data = cellfun( @(data) data(:, pc), data, 'un', 0);    
    data = cellfun( @(data) [-data(:, 1) data(:, 2:end)], data, 'un', 0);
    
    if d2c
        data = data{:};
    end

end