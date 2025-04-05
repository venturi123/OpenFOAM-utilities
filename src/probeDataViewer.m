function probeDataViewer(varargin)
    % probeDataViewer Visualize SOWFA probe data
    % Usage:
    %   probeDataViewer() - Open file dialog to select a probe data file or MAT file
    %   probeDataViewer(filename) - Use the specified probe data file or MAT file
    %   probeDataViewer(matFile, 'locationsVar', 'myLocations') - Load locations from a specific variable name in MAT file
    
    % Parse input parameters
    p = inputParser;
    addOptional(p, 'filename', '', @ischar);
    addParameter(p, 'locationsVar', 'locations', @ischar);  % Default variable name for locations
    parse(p, varargin{:});
    
    filename = p.Results.filename;
    locationsVarName = p.Results.locationsVar;
    
    % Handle input parameters
    if isempty(filename)
        % If no file specified, open file selection dialog
        [filename, filepath] = uigetfile({'*.mat', 'MAT Files (*.mat)'; '*.*', 'All Files (*.*)'}, 'Select Probe Data File');
        if isequal(filename, 0) || isequal(filepath, 0)
            return; % User cancelled the selection
        end
        fullFilePath = fullfile(filepath, filename);
    else
        % Use the provided filename
        fullFilePath = filename;
        if ~exist(fullFilePath, 'file')
            error('Specified file does not exist: %s', fullFilePath);
        end
    end
    
    % Load probe data
    fprintf('Reading probe data file: %s\n', fullFilePath);
    try
        [~, ~, ext] = fileparts(fullFilePath);
        
        % Initialize variables for time and velocities (if available)
        time = [];
        velocities = [];
        
        if strcmpi(ext, '.mat')
            % Load from MAT file
            matData = load(fullFilePath);
            
            % Check if the specified variable exists
            if isfield(matData, locationsVarName)
                locations = matData.(locationsVarName);
                fprintf('Loaded locations from variable "%s"\n', locationsVarName);
            else
                % Try to find a variable with locations data
                varNames = fieldnames(matData);
                locFound = false;
                
                % Look for variables that might contain locations
                for i = 1:length(varNames)
                    varData = matData.(varNames{i});
                    % Check if it looks like location data (numeric array with 3 columns)
                    if isnumeric(varData) && (size(varData, 2) == 3 || size(varData, 1) == 3)
                        if size(varData, 2) ~= 3
                            varData = varData'; % Transpose if needed
                        end
                        locations = varData;
                        locationsVarName = varNames{i};
                        locFound = true;
                        fprintf('Found locations in variable "%s"\n', locationsVarName);
                        break;
                    end
                end
                
                if ~locFound
                    error('Could not find locations data in MAT file. Available variables: %s', strjoin(varNames, ', '));
                end
            end
            
            % Try to load time and velocities data if available
            if isfield(matData, 'time') && isfield(matData, 'velocities')
                time = matData.time;
                velocities = matData.velocities;
                fprintf('Loaded time and velocity data from MAT file\n');
            end
        else
            % Load from original probe data file using readProbeData
            [time, velocities, locations] = readProbeData(fullFilePath);
        end
        
        fprintf('Data loaded successfully. Found %d probes.\n', size(locations, 1));
    catch e
        errordlg(['Cannot read probe data file: ' e.message], 'Error');
        return;
    end
    
    % Calculate probe position boundaries and center
    minLoc = min(locations);
    maxLoc = max(locations);
    center = mean([minLoc; maxLoc]);
    
    % Determine maximum range to ensure equal scaling across dimensions
    maxRange = max(maxLoc - minLoc);
    if maxRange == 0
        maxRange = 1; % Handle case where all points are at the same location
    end
    
    % Create main window
    f = figure('Name', 'Probe Locations Viewer', ...
        'NumberTitle', 'off', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.2 0.2 0.6 0.7], ...
        'CloseRequestFcn', @(~,~) cleanupOnClose(gcf));
    
    % Main display area - 3D plot
    ax = axes('Parent', f, ...
        'Position', [0.1 0.3 0.8 0.65], ...
        'Box', 'on', ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.2);
    
    % Plot probe positions
    scatter3(ax, locations(:,1), locations(:,2), locations(:,3), 50, 'filled', ...
        'MarkerFaceColor', [0.3 0.6 0.9], ...
        'MarkerEdgeColor', [0.1 0.2 0.5]);
    
    % Initialize text labels for probe numbers (will be updated based on user settings)
    labelHandles = cell(size(locations, 1), 1);
    hold(ax, 'on');
    
    % Default label frequency (show all labels)
    labelFrequency = 1;
    
    % Create empty text objects for all probe labels
    for i = 1:size(locations, 1)
        labelHandles{i} = text(locations(i,1), locations(i,2), locations(i,3), ...
            sprintf(' %d', i), ...
            'FontSize', 8, ...
            'Color', [0.1 0.1 0.7], ...
            'Visible', 'on');
    end
    hold(ax, 'off');
    
    % Set axis labels and grid
    xlabel(ax, 'X (m)', 'FontWeight', 'bold');
    ylabel(ax, 'Y (m)', 'FontWeight', 'bold');
    zlabel(ax, 'Z (m)', 'FontWeight', 'bold');
    title(ax, 'Probe Locations', 'FontSize', 14, 'FontWeight', 'bold');
    grid(ax, 'on');
    axis(ax, 'equal');
    
    % % Enable interactive 3D rotation with the mouse
    % rotate3d(ax);
    
    % Update figure title to indicate rotation mode is on
    title(ax, 'Probe Locations', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Control panel
    panel = uipanel(f, 'Title', 'Controls', ...
        'Position', [0.05 0.05 0.9 0.15], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'FontWeight', 'bold');
    
    % Create view control buttons
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Top View (X-Y)', ...
        'Position', [20 70 100 30], ...
        'Callback', @(~,~) view(ax, 2));
    
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Front View (X-Z)', ...
        'Position', [130 70 100 30], ...
        'Callback', @(~,~) view(ax, 0, 0));
    
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Side View (Y-Z)', ...
        'Position', [240 70 100 30], ...
        'Callback', @(~,~) view(ax, 90, 0));
    
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', '3D View', ...
        'Position', [350 70 100 30], ...
        'Callback', @(~,~) view(ax, 3));
    
    % Add rotation speed control slider
    uicontrol(panel, 'Style', 'text', ...
        'String', 'Rotation Speed:', ...
        'Position', [20 30 90 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    rotSpeed = uicontrol(panel, 'Style', 'slider', ...
        'Min', 0, ...
        'Max', 10, ...
        'Value', 0, ...
        'Position', [110 30 190 20], ...
        'Callback', @(src,~) startStopRotation(src, ax));
    
    % Add label frequency control
    uicontrol(panel, 'Style', 'text', ...
        'String', 'Label Every N Probes:', ...
        'Position', [300 5 110 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    labelFreqEdit = uicontrol(panel, 'Style', 'edit', ...
        'String', '1', ...
        'Position', [410 5 40 20], ...
        'BackgroundColor', 'white', ...
        'Callback', @(src,~) updateLabelFrequency(src, labelHandles));
    
    % Add probe selection by ID
    uicontrol(panel, 'Style', 'text', ...
        'String', 'Select Probe ID:', ...
        'Position', [680 30 90 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    probeIdEdit = uicontrol(panel, 'Style', 'edit', ...
        'String', '', ...
        'Position', [775 30 40 20], ...
        'BackgroundColor', 'white');
    
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'View Velocity', ...
        'Position', [680 70 140 30], ...
        'Callback', @(~,~) selectProbeById(probeIdEdit, locations, f));
    
    % Add full screen button
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Full Screen', ...
        'Position', [460 30 100 30], ...
        'Callback', @(~,~) toggleFullScreen(f, ax, panel));
    
    % Add export button
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Export PNG', ...
        'Position', [460 70 100 30], ...
        'Callback', @(~,~) exportFigure(f));
    
    % Add grid display checkbox
    uicontrol(panel, 'Style', 'checkbox', ...
        'String', 'Show Grid', ...
        'Value', 1, ...
        'Position', [570 30 100 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'Callback', @(src,~) grid(ax, onOff(src.Value)));
    
    % Add save to MAT button
    uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Save to MAT', ...
        'Position', [570 70 100 30], ...
        'Callback', @(~,~) saveToMatFile(locations));
    
    % Display file info and probe count in panel
    [~, filename, ext] = fileparts(fullFilePath);
    uicontrol(panel, 'Style', 'text', ...
        'String', sprintf('File: %s%s | Probes: %d', filename, ext, size(locations, 1)), ...
        'Position', [20 5 550 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    % Store rotation timer and other user data
    f.UserData.rotTimer = [];
    f.UserData.rotSpeed = rotSpeed;
    f.UserData.isFullScreen = false;
    f.UserData.originalPositions = struct('figure', f.Position, 'axes', ax.Position, 'panel', panel.Position);
    f.UserData.locations = locations;
    f.UserData.labelHandles = labelHandles;
    f.UserData.labelFreqEdit = labelFreqEdit;
    f.UserData.dataFile = fullFilePath;
    
    % Store time and velocities data if available
    if ~isempty(time) && ~isempty(velocities)
        f.UserData.time = time;
        f.UserData.velocities = velocities;
    end
    
    % Add context menu
    createContextMenu(ax, locations);
end

function updateLabelFrequency(src, labelHandles)
    % Function to update probe label visibility based on frequency input
    
    % Get the frequency from the edit box
    freqStr = get(src, 'String');
    freq = str2double(freqStr);
    
    % Validate input
    if isnan(freq) || freq < 0 || freq ~= round(freq)
        % Invalid input, reset to 1
        set(src, 'String', '1');
        freq = 1;
        warndlg('Please enter a non-negative integer value', 'Invalid Input');
    end
    
    % Update label visibility
    numProbes = length(labelHandles);
    
    for i = 1:numProbes
        if freq == 0 || mod(i, freq) ~= 0
            % If freq is 0 or i is not a multiple of freq, hide label
            set(labelHandles{i}, 'Visible', 'off');
        else
            % Show label for every freq-th probe
            set(labelHandles{i}, 'Visible', 'on');
        end
    end
    
    % Special case: if freq is 0, hide all labels
    if freq == 0
        for i = 1:numProbes
            set(labelHandles{i}, 'Visible', 'off');
        end
    end
end

function cleanupOnClose(f)
    % Stop and delete any timer before closing
    if ~isempty(f.UserData) && isfield(f.UserData, 'rotTimer') && ...
            ~isempty(f.UserData.rotTimer) && isvalid(f.UserData.rotTimer)
        stop(f.UserData.rotTimer);
        delete(f.UserData.rotTimer);
    end
    delete(f);
end

% Rotation control function
function startStopRotation(src, ax)
    f = ancestor(src, 'figure');
    speed = get(src, 'Value');
    
    % Stop and delete any existing timer
    if ~isempty(f.UserData.rotTimer) && isvalid(f.UserData.rotTimer)
        stop(f.UserData.rotTimer);
        delete(f.UserData.rotTimer);
        f.UserData.rotTimer = [];
    end
    
    % Create new rotation timer if speed > 0
    if speed > 0
        f.UserData.rotTimer = timer(...
            'ExecutionMode', 'FixedRate', ...
            'Period', 0.1, ...
            'TimerFcn', @(~,~) rotateView(ax, speed/50));
        start(f.UserData.rotTimer);
    end
end

% View rotation function
function rotateView(ax, angle)
    if isvalid(ax)
        camview = get(ax, 'View');
        azimuth = camview(1) + angle;
        elevation = camview(2);
        view(ax, azimuth, elevation);
    end
end

% Toggle full screen function
function toggleFullScreen(f, ax, panel)
    if ~f.UserData.isFullScreen
        % Save current positions
        f.UserData.originalPositions.figure = f.Position;
        f.UserData.originalPositions.axes = ax.Position;
        f.UserData.originalPositions.panel = panel.Position;
        
        % Set to full screen
        f.WindowState = 'maximized';
        ax.Position = [0.05 0.25 0.9 0.7];
        panel.Position = [0.05 0.05 0.9 0.15];
        f.UserData.isFullScreen = true;
    else
        % Restore original positions
        f.WindowState = 'normal';
        f.Position = f.UserData.originalPositions.figure;
        ax.Position = f.UserData.originalPositions.axes;
        panel.Position = f.UserData.originalPositions.panel;
        f.UserData.isFullScreen = false;
    end
end

% Export figure function
function exportFigure(f)
    [filename, filepath] = uiputfile({'*.png', 'PNG Image (*.png)'; ...
                                     '*.jpg', 'JPEG Image (*.jpg)'}, ...
                                     'Save Image As', 'probe_locations.png');
    if isequal(filename, 0) || isequal(filepath, 0)
        return; % User cancelled the save
    end
    
    fullname = fullfile(filepath, filename);
    print(f, fullname, '-dpng', '-r300'); % 300 dpi high quality
    msgbox(['Image saved to: ' fullname], 'Success');
end

% Convert checkbox value to on/off string
function status = onOff(value)
    if value
        status = 'on';
    else
        status = 'off';
    end
end

% Create context menu
function createContextMenu(ax, locations)
    % Create context menu
    cmenu = uicontextmenu(ax.Parent);
    
    % Add options to view probe information
    uimenu(cmenu, 'Label', 'View All Probe Coordinates', 'Callback', @(~,~) viewAllProbeInfo(locations));
    uimenu(cmenu, 'Label', 'View Nearest Probe Info', 'Callback', @(~,~) viewNearestProbeInfo(ax, locations));
    
    % Add axis options submenu
    axisMenu = uimenu(cmenu, 'Label', 'Axis Options');
    uimenu(axisMenu, 'Label', 'Equal Scaling', 'Checked', 'on', 'Callback', @(src,~) toggleAxisMode(src, ax, 'equal'));
    uimenu(axisMenu, 'Label', 'Auto Scaling', 'Checked', 'off', 'Callback', @(src,~) toggleAxisMode(src, ax, 'normal'));
    
    % Add label options
    labelMenu = uimenu(cmenu, 'Label', 'Label Options');
    uimenu(labelMenu, 'Label', 'Show All Labels', 'Callback', @(~,~) setLabelFrequency(ax.Parent, 1));
    uimenu(labelMenu, 'Label', 'Show No Labels', 'Callback', @(~,~) setLabelFrequency(ax.Parent, 0));
    uimenu(labelMenu, 'Label', 'Show Every 5th Label', 'Callback', @(~,~) setLabelFrequency(ax.Parent, 5));
    uimenu(labelMenu, 'Label', 'Show Every 10th Label', 'Callback', @(~,~) setLabelFrequency(ax.Parent, 10));
    
    % Set menu to axes
    ax.UIContextMenu = cmenu;
    
    % Also set context menu to the scatter points
    scatter_obj = findobj(ax, 'Type', 'scatter');
    if ~isempty(scatter_obj)
        scatter_obj.UIContextMenu = cmenu;
    end
end

% Function to set label frequency from context menu
function setLabelFrequency(f, freq)
    % Set the frequency in the edit box and trigger update
    ud = f.UserData;
    set(ud.labelFreqEdit, 'String', num2str(freq));
    updateLabelFrequency(ud.labelFreqEdit, ud.labelHandles);
end

% Toggle axis mode
function toggleAxisMode(src, ax, mode)
    % Uncheck all options
    set(src.Parent.Children, 'Checked', 'off');
    % Check current option
    set(src, 'Checked', 'on');
    % Set axis mode
    axis(ax, mode);
end

% View all probe information
function viewAllProbeInfo(locations)
    % Create table data
    tableData = cell(size(locations, 1), 4);
    for i = 1:size(locations, 1)
        tableData{i, 1} = i;
        tableData{i, 2} = locations(i, 1);
        tableData{i, 3} = locations(i, 2);
        tableData{i, 4} = locations(i, 3);
    end
    
    % Create a new figure window
    f = figure('Name', 'Probe Location Information', ...
        'NumberTitle', 'off', ...
        'Position', [300 200 500 400], ...
        'MenuBar', 'none', ...
        'ToolBar', 'none');
    
    % Create table
    t = uitable(f, ...
        'Data', tableData, ...
        'ColumnName', {'Probe ID', 'X (m)', 'Y (m)', 'Z (m)'}, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.05 0.1 0.9 0.85]);
    
    % Add export to CSV button
    uicontrol(f, 'Style', 'pushbutton', ...
        'String', 'Export to CSV', ...
        'Units', 'normalized', ...
        'Position', [0.7 0.02 0.25 0.06], ...
        'Callback', @(~,~) exportProbesToCSV(locations));
end

% View nearest probe information
function viewNearestProbeInfo(ax, locations)
    % Get current click position
    point = ax.CurrentPoint(1, 1:3);
    
    % Calculate distance to all probes
    distances = sqrt(sum((locations - repmat(point, size(locations, 1), 1)).^2, 2));
    
    % Find closest probe
    [~, idx] = min(distances);
    
    % Create message
    msg = sprintf('Nearest probe:\nProbe ID: %d\nX: %.4f m\nY: %.4f m\nZ: %.4f m\nDistance: %.4f m', ...
        idx, locations(idx, 1), locations(idx, 2), locations(idx, 3), distances(idx));
    
    % Show message box
    msgbox(msg, 'Probe Information');
end

% Export probe data to CSV
function exportProbesToCSV(locations)
    [filename, filepath] = uiputfile({'*.csv', 'CSV File (*.csv)'}, 'Save as CSV', 'probe_locations.csv');
    if isequal(filename, 0) || isequal(filepath, 0)
        return; % User cancelled the save
    end
    
    % Create data including IDs and coordinates
    data = [(1:size(locations, 1))', locations];
    
    % Open file for writing
    fid = fopen(fullfile(filepath, filename), 'w');
    fprintf(fid, 'ProbeID,X,Y,Z\n');
    for i = 1:size(data, 1)
        fprintf(fid, '%d,%.6f,%.6f,%.6f\n', data(i, 1), data(i, 2), data(i, 3), data(i, 4));
    end
    fclose(fid);
    
    msgbox(['File saved to: ' fullfile(filepath, filename)], 'Export Successful');
end

% Save to MAT file function
function saveToMatFile(locations)
    [filename, filepath] = uiputfile({'*.mat', 'MAT File (*.mat)'}, 'Save to MAT file', 'probe_locations.mat');
    if isequal(filename, 0) || isequal(filepath, 0)
        return; % User cancelled the save
    end
    
    % Ask for variable name
    varName = inputdlg('Enter variable name for locations:', 'Variable Name', 1, {'locations'});
    if isempty(varName) || isempty(varName{1})
        return; % User cancelled or entered empty name
    end
    
    % Create the variable with the specified name in a struct and save
    saveData = struct();
    saveData.(varName{1}) = locations;
    
    % Save to MAT file
    fullname = fullfile(filepath, filename);
    save(fullname, '-struct', 'saveData');
    
    % Display confirmation
    msgbox(sprintf('Data saved to: %s\nVariable name: %s\nNumber of probes: %d', ...
        fullname, varName{1}, size(locations, 1)), 'Save Successful');
end

% Handle probe selection by ID
function selectProbeById(src, locations, fig)
    % Get probe ID from edit box
    probeIdStr = get(src, 'String');
    probeId = str2double(probeIdStr);
    
    % Validate input
    if isnan(probeId) || probeId < 1 || probeId > size(locations, 1) || probeId ~= round(probeId)
        warndlg(sprintf('Please enter a valid probe ID between 1 and %d', size(locations, 1)), 'Invalid Input');
        return;
    end
    
    % Show velocity data window
    viewProbeVelocityData(probeId, fig);
end

% View velocity data for a specific probe ID
function viewProbeVelocityData(probeIdx, fig)
    % Get locations data
    locations = fig.UserData.locations;
    
    % Load velocity data if needed
    try
        % Check if data is already loaded
        if isfield(fig.UserData, 'velocities') && isfield(fig.UserData, 'time')
            time = fig.UserData.time;
            velocities = fig.UserData.velocities;
        else
            % If not stored, ask user for data file
            [filename, filepath] = uigetfile({'*.mat', 'MAT Files (*.mat)'; '*.*', 'All Files (*.*)'}, 'Select Probe Data File');
            if isequal(filename, 0) || isequal(filepath, 0)
                return; % User cancelled the selection
            end
            fullFilePath = fullfile(filepath, filename);
            
            % Load data from file
            [~, ~, ext] = fileparts(fullFilePath);
            
            if strcmpi(ext, '.mat')
                % Load from MAT file
                matData = load(fullFilePath);
                
                % Look for time and velocities
                if isfield(matData, 'time') && isfield(matData, 'velocities')
                    time = matData.time;
                    velocities = matData.velocities;
                else
                    error('Could not find time and velocities data in MAT file.');
                end
            else
                % Load from original probe data file
                [time, velocities, ~] = readProbeData(fullFilePath);
            end
            
            % Store data in figure UserData for future use
            fig.UserData.time = time;
            fig.UserData.velocities = velocities;
            fig.UserData.dataFile = fullFilePath;
        end
        
        % Show velocity data window
        showVelocityWindow(probeIdx, time, velocities, locations);
        
    catch e
        errordlg(['Error loading velocity data: ' e.message], 'Error');
    end
end

% Show velocity data window with plots
function showVelocityWindow(probeIdx, time, velocities, locations)
    % Create a new figure for velocity data
    vfig = figure('Name', sprintf('Probe %d Velocity Data', probeIdx), ...
        'NumberTitle', 'off', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.1 0.1 0.8 0.8]);
    
    % Store data in figure UserData
    vfig.UserData.probeIdx = probeIdx;
    vfig.UserData.time = time;
    vfig.UserData.dt = round((time(end) - time(1)) / (length(time) - 1), 3);
    vfig.UserData.velocities = velocities;
    vfig.UserData.locations = locations;
    vfig.UserData.averagingWindow = 0.1; % Default 0.1 second window (minimal averaging)
    vfig.UserData.timeRange = [min(time), max(time)]; % Default: use full time range
    
    % Extract velocities for this probe
    u_raw = squeeze(velocities(:,1,probeIdx));
    v_raw = squeeze(velocities(:,2,probeIdx));
    w_raw = squeeze(velocities(:,3,probeIdx));
    
    % Calculate original turbulence intensity
    u_std = std(u_raw);
    u_mean = mean(u_raw);
    original_Iu = u_std / u_mean * 100; % Turbulence intensity as percentage
    
    % Create layout - improve spacing and reduce the gap between plots
    % Top row: Time series plots for u, v, w
    ax_u_ts = subplot('Position', [0.08 0.75 0.25 0.15]);
    plot(ax_u_ts, time, u_raw, 'r-', 'LineWidth', 1);
    grid(ax_u_ts, 'on');
    xlabel(ax_u_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(ax_u_ts, 'u (m/s)', 'FontWeight', 'bold');
    title(ax_u_ts, 'u-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    ax_v_ts = subplot('Position', [0.40 0.75 0.25 0.15]);
    plot(ax_v_ts, time, v_raw, 'g-', 'LineWidth', 1);
    grid(ax_v_ts, 'on');
    xlabel(ax_v_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(ax_v_ts, 'v (m/s)', 'FontWeight', 'bold');
    title(ax_v_ts, 'v-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    ax_w_ts = subplot('Position', [0.72 0.75 0.25 0.15]);
    plot(ax_w_ts, time, w_raw, 'b-', 'LineWidth', 1);
    grid(ax_w_ts, 'on');
    xlabel(ax_w_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(ax_w_ts, 'w (m/s)', 'FontWeight', 'bold');
    title(ax_w_ts, 'w-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    
    % Middle row: PSD plots for u, v, w
    ax_u_psd = subplot('Position', [0.08 0.50 0.25 0.15]);
    [pxx_u_raw, f_u_raw] = computePSD(time, u_raw);
    
    cla(ax_u_psd);
    loglog(ax_u_psd, f_u_raw, pxx_u_raw, 'r-', 'LineWidth', 1.2);
    
    grid(ax_u_psd, 'on');
    xlabel(ax_u_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(ax_u_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(ax_u_psd, [min(f_u_raw), max(f_u_raw), min(pxx_u_raw)*0.1, max(pxx_u_raw)*10]);
    
    ax_v_psd = subplot('Position', [0.40 0.50 0.25 0.15]);
    [pxx_v_raw, f_v_raw] = computePSD(time, v_raw);
    
    cla(ax_v_psd);
    loglog(ax_v_psd, f_v_raw, pxx_v_raw, 'g-', 'LineWidth', 1.2);
    
    grid(ax_v_psd, 'on');
    xlabel(ax_v_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(ax_v_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(ax_v_psd, [min(f_v_raw), max(f_v_raw), min(pxx_v_raw)*0.1, max(pxx_v_raw)*10]);
    
    ax_w_psd = subplot('Position', [0.72 0.50 0.25 0.15]);
    [pxx_w_raw, f_w_raw] = computePSD(time, w_raw);
    
    cla(ax_w_psd);
    loglog(ax_w_psd, f_w_raw, pxx_w_raw, 'b-', 'LineWidth', 1.2);
    
    grid(ax_w_psd, 'on');
    xlabel(ax_w_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(ax_w_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(ax_w_psd, [min(f_w_raw), max(f_w_raw), min(pxx_w_raw)*0.1, max(pxx_w_raw)*10]);
    
    % Bottom row: Turbulence intensity plot - closer to input panel
    ax_ti = subplot('Position', [0.08 0.25 0.89 0.16]);
    % Placeholder for turbulence intensity - will be populated by the averaging function
    title(ax_ti, 'turbulence intensity Iu vs interval average duration', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax_ti, 'interval average duration (s)', 'FontWeight', 'bold');
    ylabel(ax_ti, 'turbulence intensity Iu (%)', 'FontWeight', 'bold');
    grid(ax_ti, 'on');
    
    % Input panel - reduce gap with plots above
    input_panel = uipanel(vfig, 'Title', 'Input panel', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.02 0.9 0.18], ... % Closer to plots above
        'FontWeight', 'bold');
    
    % --- Top row: original TI and interval list ---
    % Display original turbulence intensity
    uicontrol(input_panel, 'Style', 'text', ...
        'String', 'Original turbulence intensity Iu:', ...
        'Position', [20 110 180 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    uicontrol(input_panel, 'Style', 'text', ...
        'String', sprintf('%.2f%%', original_Iu), ...
        'Position', [200 110 60 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left', ...
        'FontWeight', 'bold');
    
    % Add interval averaging controls for multiple intervals
    uicontrol(input_panel, 'Style', 'text', ...
        'String', 'Interval average list (seconds):', ...
        'Position', [300 110 160 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    % Default interval list based on original turbulence intensity
    default_intervals = '1,2,3,5,10,30,60';
    
    interval_edit = uicontrol(input_panel, 'Style', 'edit', ...
        'String', default_intervals, ...
        'Position', [460 110 200 20], ...
        'BackgroundColor', 'white', ...
        'Callback', @(src,~) updateIntervalList(src, vfig));
    
    % Add apply button for interval list
    apply_btn = uicontrol(input_panel, 'Style', 'pushbutton', ...
        'String', 'Apply interval list', ...
        'Position', [670 110 120 20], ...
        'Callback', @(~,~) calculateMultipleIntervals(vfig));
    
    % --- Middle row: single interval and time range ---
    % Add single interval input
    uicontrol(input_panel, 'Style', 'text', ...
        'String', 'Single interval duration (s):', ...
        'Position', [20 70 150 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    single_interval_edit = uicontrol(input_panel, 'Style', 'edit', ...
        'String', vfig.UserData.dt, ...
        'Position', [170 70 60 20], ...
        'BackgroundColor', 'white');
    
    % Add apply single interval button
    uicontrol(input_panel, 'Style', 'pushbutton', ...
        'String', 'Apply single interval', ...
        'Position', [240 70 120 20], ...
        'Callback', @(~,~) applySingleInterval(vfig, single_interval_edit));
    
    % Add time range selection
    uicontrol(input_panel, 'Style', 'text', ...
        'String', 'Time range (start,end):', ...
        'Position', [400 70 130 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'HorizontalAlignment', 'left');
    
    time_range_edit = uicontrol(input_panel, 'Style', 'edit', ...
        'String', sprintf('%.1f,%.1f', min(time), max(time)), ...
        'Position', [530 70 120 20], ...
        'BackgroundColor', 'white', ...
        'Callback', @(src,~) updateTimeRange(src, vfig));
    
    % --- Bottom row: export and file info ---
    % Add export button
    uicontrol(input_panel, 'Style', 'pushbutton', ...
        'String', 'Export data', ...
        'Position', [670 70 120 20], ...
        'Callback', @(~,~) exportVelocityData(vfig));

    
    % Store axes and controls in figure UserData for future access
    vfig.UserData.axes = struct(...
        'u_ts', ax_u_ts, ...
        'v_ts', ax_v_ts, ...
        'w_ts', ax_w_ts, ...
        'u_psd', ax_u_psd, ...
        'v_psd', ax_v_psd, ...
        'w_psd', ax_w_psd, ...
        'ti', ax_ti);
    
    vfig.UserData.controls = struct(...
        'interval_edit', interval_edit, ...
        'time_range_edit', time_range_edit, ...
        'single_interval_edit', single_interval_edit);
    
    % Initialize with turbulence intensity data from original signal
    vfig.UserData.ti_data = struct('intervals', [0], 'intensities', [original_Iu]);
    vfig.UserData.intervalList = str2num(default_intervals); % Default interval list
    
    % Calculate turbulence intensity for default intervals
    calculateMultipleIntervals(vfig);
end

% Update interval list from the input field
function updateIntervalList(src, fig)
    intervalStr = get(src, 'String');
    
    try
        % Split by comma and convert to numbers
        intervalParts = strsplit(intervalStr, ',');
        intervals = zeros(1, length(intervalParts));
        
        for i = 1:length(intervalParts)
            intervals(i) = str2double(strtrim(intervalParts{i}));
        end
        
        % Validate input
        if any(isnan(intervals)) || any(intervals <= 0)
            warndlg('Please enter a valid list of averaging intervals (greater than 0, separated by commas)', 'Invalid Input');
            return;
        end
        
        % Sort intervals
        intervals = sort(intervals);
        
        % Store in figure UserData
        fig.UserData.intervalList = intervals;
        
        % Update display
        set(src, 'String', strjoin(arrayfun(@num2str, intervals, 'UniformOutput', false), ','));
        
    catch
        warndlg('Invalid input format, please use comma-separated numbers', 'Invalid Input');
    end
end

% Update time range from the input field
function updateTimeRange(src, fig)
    rangeStr = get(src, 'String');
    
    try
        % Split by comma and convert to numbers
        rangeParts = strsplit(rangeStr, ',');
        
        if length(rangeParts) ~= 2
            warndlg('Please enter two numbers representing the start and end times', 'Invalid Input');
            return;
        end
        
        timeRange = [str2double(strtrim(rangeParts{1})), str2double(strtrim(rangeParts{2}))];
        
        % Validate input
        if any(isnan(timeRange)) || timeRange(1) >= timeRange(2)
            warndlg('Please enter a valid time range (start time < end time)', 'Invalid Input');
            return;
        end
        
        % Check if within data range
        allTime = fig.UserData.time;
        if timeRange(1) < min(allTime) || timeRange(2) > max(allTime)
            warndlg(sprintf('Time range exceeds data range (%.1f to %.1f)', min(allTime), max(allTime)), 'Invalid Input');
            return;
        end
        
        % Store in figure UserData
        fig.UserData.timeRange = timeRange;
        
    catch
        warndlg('Invalid input format, please use comma-separated two numbers', 'Invalid Input');
    end
end

% Calculate turbulence intensity for multiple averaging intervals
function calculateMultipleIntervals(fig)
    % Get data from figure UserData
    probeIdx = fig.UserData.probeIdx;
    time = fig.UserData.time;
    velocities = fig.UserData.velocities;
    axes_data = fig.UserData.axes;
    timeRange = fig.UserData.timeRange;
    
    % Get interval list
    intervals = fig.UserData.intervalList;
    
    if isempty(intervals)
        warndlg('Please enter at least one valid averaging interval', 'Invalid Input');
        return;
    end
    
    % Filter data within time range
    timeIdx = time >= timeRange(1) & time <= timeRange(2);
    time_filtered = time(timeIdx);
    
    % Extract u velocity for this probe and filter by time range
    u_raw = squeeze(velocities(timeIdx,1,probeIdx));
    v_raw = squeeze(velocities(timeIdx,2,probeIdx));
    w_raw = squeeze(velocities(timeIdx,3,probeIdx));
    
    % Ensure data is real (fix for complex number warning)
    u_raw = real(u_raw);
    v_raw = real(v_raw);
    w_raw = real(w_raw);

    Iu_original = std(u_raw) / mean(u_raw) * 100;
    
    % Calculate time step
    dt = mean(diff(time_filtered));
    
    % Initialize arrays for results
    intensities = zeros(size(intervals));
    
    % Calculate turbulence intensity for each interval
    for i = 1:length(intervals)
        interval = intervals(i);
        window_samples = max(1, round(interval / dt));
        
        if window_samples <= 1
            % No averaging
            u = u_raw;
            v = v_raw;
            w = w_raw;
        else
            % Apply moving average to entire arrays
            u = movmean(u_raw, window_samples);
            v = movmean(v_raw, window_samples);
            w = movmean(w_raw, window_samples);
        end
        
        % Calculate turbulence intensity
        u_std = std(u);
        u_mean = mean(u);
        intensities(i) = u_std / u_mean * 100; % As percentage
    end
    
    % Store results in figure UserData
    fig.UserData.ti_data.intervals = intervals;
    fig.UserData.ti_data.intensities = intensities;
    
    % Update turbulence intensity plot
    cla(axes_data.ti);
    
    % Plot points
    plot(axes_data.ti, intervals, intensities, 'ro-', 'MarkerFaceColor', 'r', 'MarkerSize', 6, 'LineWidth', 1.5);
    hold(axes_data.ti, 'on');
    plot(axes_data.ti, intervals, Iu_original*ones(size(intervals)), 'k--', 'LineWidth', 1.5);
    legend(axes_data.ti, {'interval average', 'original'}, 'Location', 'southwest', 'FontSize', 8);
    
    % Configure plot appearance
    xlabel(axes_data.ti, 'interval average duration (s)', 'FontWeight', 'bold');
    ylabel(axes_data.ti, 'turbulence intensity Iu (%)', 'FontWeight', 'bold');
    title(axes_data.ti, 'turbulence intensity Iu vs interval average duration', 'FontSize', 12, 'FontWeight', 'bold');
    
    hold(axes_data.ti, 'off');
    
end

% Replace computePSD function with the method from spectrum_pwelch.m
function [pxx, f] = computePSD(time, signal)
    % Get sampling frequency
    dt = mean(diff(time));
    fs = 1/dt;
    
    % Use the same parameters as in spectrum_pwelch.m
    n = 2^8;  % Window length
    window = hanning(n);
    noverlap = 128;
    nfft = 2^13;
    range = 'oneside';
    
    % Compute PSD using Welch's method with the same parameters
    [pxx, f] = pwelch(signal, window, noverlap, nfft, fs, range);
    
    % Remove zero frequency component if present
    if f(1) == 0 && length(f) > 1
        f = f(2:end);
        pxx = pxx(2:end);
    end
end

% Add new function to handle applying a single interval
function applySingleInterval(fig, interval_edit)
    % Get interval value
    interval_str = get(interval_edit, 'String');
    interval = str2double(interval_str);
    
    % Validate input
    if isnan(interval) || interval <= 0
        warndlg('Please enter a valid averaging interval (greater than 0)', 'Invalid Input');
        return;
    end
    
    % Store current interval
    fig.UserData.averagingWindow = interval;
    
    % Apply averaging and update plots
    applyAveraging(fig);
end

% Export velocity data to CSV
function exportVelocityData(fig)
    % Get data from figure UserData
    probeIdx = fig.UserData.probeIdx;
    time = fig.UserData.time;
    velocities = fig.UserData.velocities;
    timeRange = fig.UserData.timeRange;
    intervals = fig.UserData.intervalList;
    ti_data = fig.UserData.ti_data;
    
    % Filter data within time range
    timeIdx = time >= timeRange(1) & time <= timeRange(2);
    time_filtered = time(timeIdx);
    
    % Extract velocities for this probe
    u_raw = squeeze(velocities(timeIdx,1,probeIdx));
    v_raw = squeeze(velocities(timeIdx,2,probeIdx));
    w_raw = squeeze(velocities(timeIdx,3,probeIdx));
    
    % Calculate time step
    dt = mean(diff(time_filtered));
    
    % Ask user for file location
    [filename, filepath] = uiputfile({'*.xlsx', 'Excel File (*.xlsx)'; ...
                                      '*.csv', 'CSV File (*.csv)'}, ...
        'Save Velocity Data', sprintf('probe_%d_velocity.xlsx', probeIdx));
    
    if isequal(filename, 0) || isequal(filepath, 0)
        return; % User cancelled the save
    end
    
    fullname = fullfile(filepath, filename);
    [~, ~, ext] = fileparts(fullname);
    
    try
        % Create table with raw data
        T_raw = table(time_filtered, u_raw, v_raw, w_raw, 'VariableNames', {'Time', 'U', 'V', 'W'});
        
        % Create tables for averaged data
        averaged_tables = cell(length(intervals), 1);
        
        for i = 1:length(intervals)
            interval = intervals(i);
            window_samples = max(1, round(interval / dt));
            
            if window_samples <= 1
                u = u_raw;
                v = v_raw;
                w = w_raw;
            else
                u = movmean(u_raw, window_samples);
                v = movmean(v_raw, window_samples);
                w = movmean(w_raw, window_samples);
            end
            
            % Calculate turbulence intensity
            u_std = std(u);
            u_mean = mean(u);
            I_u = u_std / u_mean * 100;
            
            % Create table for this interval
            averaged_tables{i} = table(time_filtered, u, v, w, ...
                'VariableNames', {sprintf('Time_%.1fs', interval), ...
                                  sprintf('U_%.1fs', interval), ...
                                  sprintf('V_%.1fs', interval), ...
                                  sprintf('W_%.1fs', interval)});
        end
        
        % Create table for turbulence intensity data
        T_ti = table(ti_data.intervals', ti_data.intensities', ...
            'VariableNames', {'AveragingInterval', 'TurbulenceIntensity'});
        
        % Write to file based on extension
        if strcmpi(ext, '.xlsx')
            % Write to Excel file with multiple sheets
            writetable(T_raw, fullname, 'Sheet', 'RawData');
            
            for i = 1:length(intervals)
                interval = intervals(i);
                writetable(averaged_tables{i}, fullname, 'Sheet', sprintf('Avg_%.1fs', interval));
            end
            
            writetable(T_ti, fullname, 'Sheet', 'TurbulenceIntensity');
            
        else
            % Write to CSV (only raw data and turbulence intensity)
            writetable(T_raw, fullname);
            
            % Write turbulence intensity to separate file
            [path, name, ~] = fileparts(fullname);
            ti_filename = fullfile(path, [name '_turbulence.csv']);
            writetable(T_ti, ti_filename);
        end
        
        msgbox(['Data saved to: ' fullname], 'Export Successful');
    catch e
        errordlg(['Error exporting data: ' e.message], 'Export Failed');
    end
end

% Apply averaging to velocity data and update plots
function applyAveraging(fig)
    % Get data from figure UserData
    probeIdx = fig.UserData.probeIdx;
    time = fig.UserData.time;
    velocities = fig.UserData.velocities;
    interval = fig.UserData.averagingWindow;
    axes_data = fig.UserData.axes;
    timeRange = fig.UserData.timeRange;
    
    % Filter data within time range
    timeIdx = time >= timeRange(1) & time <= timeRange(2);
    time_filtered = time(timeIdx);
    
    % Extract velocities for this probe
    u_raw = squeeze(velocities(timeIdx,1,probeIdx));
    v_raw = squeeze(velocities(timeIdx,2,probeIdx));
    w_raw = squeeze(velocities(timeIdx,3,probeIdx));
    
    % Calculate time step
    dt = mean(diff(time_filtered));
    
    % Initialize arrays for results
    u_avg = zeros(size(time_filtered));
    v_avg = zeros(size(time_filtered));
    w_avg = zeros(size(time_filtered));
    
    % Apply averaging
    window_samples = max(1, round(interval / dt));
    
    if window_samples <= 1
        % No averaging
        u_avg = u_raw;
        v_avg = v_raw;
        w_avg = w_raw;
    else
        % Apply moving average to entire arrays
        u_avg = movmean(u_raw, window_samples);
        v_avg = movmean(v_raw, window_samples);
        w_avg = movmean(w_raw, window_samples);
    end
    
    % Update plots
    cla(axes_data.u_ts);
    cla(axes_data.v_ts);
    cla(axes_data.w_ts);
    
    % Plot both original and averaged time series
    plot(axes_data.u_ts, time_filtered, u_raw, 'k:', 'LineWidth', 0.8); % Original in black dotted line
    hold(axes_data.u_ts, 'on');
    plot(axes_data.u_ts, time_filtered, u_avg, 'r-', 'LineWidth', 1.2);
    legend(axes_data.u_ts, {'original', 'averaged'}, 'Location', 'northeast', 'FontSize', 8);
    hold(axes_data.u_ts, 'off');
    
    plot(axes_data.v_ts, time_filtered, v_raw, 'k:', 'LineWidth', 0.8); % Original in black dotted line
    hold(axes_data.v_ts, 'on');
    plot(axes_data.v_ts, time_filtered, v_avg, 'g-', 'LineWidth', 1.2);
    legend(axes_data.v_ts, {'original', 'averaged'}, 'Location', 'northeast', 'FontSize', 8);
    hold(axes_data.v_ts, 'off');
    
    plot(axes_data.w_ts, time_filtered, w_raw, 'k:', 'LineWidth', 0.8); % Original in black dotted line
    hold(axes_data.w_ts, 'on');
    plot(axes_data.w_ts, time_filtered, w_avg, 'b-', 'LineWidth', 1.2);
    legend(axes_data.w_ts, {'original', 'averaged'}, 'Location', 'northeast', 'FontSize', 8);
    hold(axes_data.w_ts, 'off');
    
    % Restore axes labels and titles for time series plots
    xlabel(axes_data.u_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(axes_data.u_ts, 'u (m/s)', 'FontWeight', 'bold');
    title(axes_data.u_ts, 'u-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    xlabel(axes_data.v_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(axes_data.v_ts, 'v (m/s)', 'FontWeight', 'bold');
    title(axes_data.v_ts, 'v-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    xlabel(axes_data.w_ts, 'Time (s)', 'FontWeight', 'bold');
    ylabel(axes_data.w_ts, 'w (m/s)', 'FontWeight', 'bold');
    title(axes_data.w_ts, 'w-component time series', 'FontSize', 10, 'FontWeight', 'bold');
    
    % Update PSD plots with both raw and averaged data
    [pxx_u_raw, f_u_raw] = computePSD(time_filtered, u_raw);
    [pxx_u, f_u] = computePSD(time_filtered, u_avg);
    
    cla(axes_data.u_psd);
    loglog(axes_data.u_psd, f_u_raw, pxx_u_raw, 'k:', 'LineWidth', 0.8); % Original PSD in black dotted line
    hold(axes_data.u_psd, 'on');
    loglog(axes_data.u_psd, f_u, pxx_u, 'r-', 'LineWidth', 1.2);
    legend(axes_data.u_psd, {'original', 'averaged'}, 'Location', 'southwest', 'FontSize', 8);
    
    grid(axes_data.u_psd, 'on');
    xlabel(axes_data.u_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(axes_data.u_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(axes_data.u_psd, [min(f_u_raw), max(f_u_raw), min(pxx_u_raw)*0.1, max(pxx_u_raw)*10]);
    hold(axes_data.u_psd, 'off');
    
    [pxx_v_raw, f_v_raw] = computePSD(time_filtered, v_raw);
    [pxx_v, f_v] = computePSD(time_filtered, v_avg);
    
    cla(axes_data.v_psd);
    loglog(axes_data.v_psd, f_v_raw, pxx_v_raw, 'k:', 'LineWidth', 0.8); % Original PSD in black dotted line
    hold(axes_data.v_psd, 'on');
    loglog(axes_data.v_psd, f_v, pxx_v, 'g-', 'LineWidth', 1.2);
    legend(axes_data.v_psd, {'original', 'averaged'}, 'Location', 'southwest', 'FontSize', 8);
    
    grid(axes_data.v_psd, 'on');
    xlabel(axes_data.v_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(axes_data.v_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(axes_data.v_psd, [min(f_v_raw), max(f_v_raw), min(pxx_v_raw)*0.1, max(pxx_v_raw)*10]);
    hold(axes_data.v_psd, 'off');
    
    [pxx_w_raw, f_w_raw] = computePSD(time_filtered, w_raw);
    [pxx_w, f_w] = computePSD(time_filtered, w_avg);
    
    cla(axes_data.w_psd);
    loglog(axes_data.w_psd, f_w_raw, pxx_w_raw, 'k:', 'LineWidth', 0.8); % Original PSD in black dotted line
    hold(axes_data.w_psd, 'on');
    loglog(axes_data.w_psd, f_w, pxx_w, 'b-', 'LineWidth', 1.2);
    legend(axes_data.w_psd, {'original', 'averaged'}, 'Location', 'southwest', 'FontSize', 8);
    
    grid(axes_data.w_psd, 'on');
    xlabel(axes_data.w_psd, 'Frequency (Hz)', 'FontWeight', 'bold');
    ylabel(axes_data.w_psd, 'PSD (m²/s)', 'FontWeight', 'bold');
    axis(axes_data.w_psd, [min(f_w_raw), max(f_w_raw), min(pxx_w_raw)*0.1, max(pxx_w_raw)*10]);
    hold(axes_data.w_psd, 'off');

end
