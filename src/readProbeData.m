function [time, velocities, locations] = readProbeData(filename, varargin)
    % readProbeData 读取探针数据文件并可选保存到MAT文件
    %   [time, velocities, locations] = readProbeData(filename) 读取探针数据文件
    %   [time, velocities, locations] = readProbeData(filename, 'saveToMat', true) 读取并保存到MAT文件
    %   [time, velocities, locations] = readProbeData(filename, 'saveToMat', true, 'matFilename', 'custom.mat') 读取并保存到指定MAT文件
    
    % 解析输入参数
    p = inputParser;
    addRequired(p, 'filename', @ischar);
    addParameter(p, 'saveToMat', false, @islogical);
    addParameter(p, 'matFilename', '', @ischar);
    parse(p, filename, varargin{:});
    
    saveToMat = p.Results.saveToMat;
    matFilename = p.Results.matFilename;
    
    % 如果没有指定MAT文件名，则使用与输入文件相同的名称但扩展名为.mat
    if saveToMat && isempty(matFilename)
        [filepath, name, ~] = fileparts(filename);
        if isempty(filepath)
            matFilename = [name '.mat'];
        else
            matFilename = fullfile(filepath, [name '.mat']);
        end
    end
    
    % Open the file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    % Process header lines to get probe locations
    headerLines = 0;
    locationLines = {};
    
    % Read header to extract probe locations and count probes
    while true
        line = fgetl(fid);
        headerLines = headerLines + 1;
        
        if ~ischar(line)
            break;
        end
        
        if isempty(line)
            continue;
        elseif line(1) ~= '#'
            % If not a comment line, we've reached data
            headerLines = headerLines - 1; % Adjust header count
            break;
        else
            % Store lines with probe locations
            if contains(line, 'Probe') && contains(line, '(') && contains(line, ')')
                locationLines{end+1} = line;
            end
        end
    end
    
    % Parse probe locations from header
    numProbes = length(locationLines);
    locations = zeros(numProbes, 3);
    fprintf('Number of probes: %d\n', numProbes);
    
    for i = 1:numProbes
        locLine = locationLines{i};
        
        % Extract coordinates from parentheses: format "# Probe X (x y z)"
        startParen = strfind(locLine, '(');
        endParen = strfind(locLine, ')');
        
        if ~isempty(startParen) && ~isempty(endParen)
            coordStr = locLine(startParen(1)+1:endParen(1)-1);
            coordParts = strsplit(coordStr);
            
            if length(coordParts) >= 3
                locations(i, 1) = str2double(coordParts{1});
                locations(i, 2) = str2double(coordParts{2});
                locations(i, 3) = str2double(coordParts{3});
            end
        end
    end
    
    % Rewind the file to the beginning
    frewind(fid);
    
    % Create format string for textscan based on number of probes
    formatSpec = '%f';
    for i = 1:numProbes
        formatSpec = [formatSpec ' %f %f %f'];
    end
    
    % Read all data at once using textscan
    data = textscan(fid, formatSpec, 'HeaderLines', headerLines, ...
                    'Delimiter', ' ()', 'MultipleDelimsAsOne', true, 'CollectOutput', 1);
    fclose(fid);
    
    % Convert to matrix
    data = cell2mat(data);
    
    % Extract time and velocity data
    time = data(:, 1);
    numTimeSteps = length(time);
    fprintf('Number of Time Steps: %d\n', numTimeSteps);
    
    % Initialize velocities array with proper dimensions
    velocities = zeros(numTimeSteps, 3, numProbes, 'single');
    
    % Extract velocity components for each probe
    for i = 1:numProbes
        velocities(:, 1, i) = single(data(:, (i-1)*3+2)); % x component
        velocities(:, 2, i) = single(data(:, (i-1)*3+3)); % y component
        velocities(:, 3, i) = single(data(:, (i-1)*3+4)); % z component
    end
    
    % If saveToMat is true, save the data to a MAT file
    if saveToMat
        fprintf('Saving data to MAT file: %s\n', matFilename);
        save(matFilename, 'locations', 'time', 'velocities', '-v7.3');
        fprintf('Variable sizes:\n');
        fprintf('  locations: %dx%d\n', size(locations, 1), size(locations, 2));
        fprintf('  time: %dx%d\n', size(time, 1), size(time, 2));
        fprintf('  velocities: %dx%dx%d\n', size(velocities, 1), size(velocities, 2), size(velocities, 3));
        fprintf('Save completed!\n');
    end
end
