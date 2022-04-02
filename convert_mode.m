function mode = convert_mode(mode)

    if isnumeric(mode)
        return
    elseif ischar(mode)
        switch mode
            case 'Points'
                mode = 0;
            case 'Line Strips'
                mode = 3;
            case 'Line Loops'
                mode = 2;
            case 'Lines'
                mode = 1;
            case 'Triangles'
                mode = 4;
            case 'Triangle Strips'
                mode = 5;
            case 'Triangle Fans'
                mode = 6;
            otherwise
                warning('Mode provided incorrectly, handling as triangles')
                mode = 4;
        end
    else
        warning('Mode provided incorrectly, handling as triangles')
        mode = 4;
    end

end