function sowfaABLSolverViewer(data_folder)
    % Check if data_folder parameter is provided
    if nargin < 1 || isempty(data_folder)
        data_folder = uigetdir(pwd, 'Select the data folder containing U_mean, uu_mean, and hLevelsCell files');
        if data_folder == 0  % User clicked Cancel
            return;
        end
    end
    
    % Ensure data_folder exists
    if ~exist(data_folder, 'dir')
        error('The specified data folder does not exist: %s', data_folder);
    end
    
    % Construct file paths
    U_mean_file = fullfile(data_folder, 'U_mean');
    uu_mean_file = fullfile(data_folder, 'uu_mean');
    hLevelsCell_file = fullfile(data_folder, 'hLevelsCell');
    
    % Check if required files exist
    if ~exist(U_mean_file, 'file')
        error('U_mean file not found in: %s', data_folder);
    end
    if ~exist(uu_mean_file, 'file')
        error('uu_mean file not found in: %s', data_folder);
    end
    if ~exist(hLevelsCell_file, 'file')
        error('hLevelsCell file not found in: %s', data_folder);
    end
    
    % ====== Data Loading ======
    U_mean = load(U_mean_file, '-ascii');
    uu_mean = load(uu_mean_file, '-ascii');  % Load uu_mean data
    load(hLevelsCell_file, '-ascii');

    % Initialize data
    default_step = 500;
    rows_to_use = 1:default_step:size(U_mean,1);
    height = hLevelsCell(1,:);
    num_frames = length(rows_to_use);

    % Load initial velocity and turbulence intensity data
    [velocity_data, turbulence_data, time_data] = loadVelocityAndTurbulenceData(U_mean, uu_mean, rows_to_use, num_frames);

    % Store data in a structure for easy access
    data = struct();
    data.U_mean = U_mean;
    data.uu_mean = uu_mean;
    data.velocity_data = velocity_data;
    data.turbulence_data = turbulence_data;
    data.time_data = time_data;
    data.num_frames = num_frames;
    data.rows_to_use = rows_to_use;
    data.height = height;
    data.isPlaying = false;  % Add play state
    data.playTimer = [];     % Add timer placeholder
    data.playSpeed = 1;      % Default play speed (frames per update)
    data.xRange = [0 15];    % Default x axis range for velocity
    data.yRange = [0 max(height)];  % Default y axis range
    data.IxRange = [0 0.5];  % Default x axis range for turbulence intensity

    % ====== Create Window and Axes ======
    f = figure('Name', 'Velocity and Turbulence Intensity Viewer', ...
        'NumberTitle', 'off', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.2 0.2 0.6 0.7], ...  % Increased figure height
        'CloseRequestFcn', @figure1_CloseRequestFcn, ... % Add cleanup function
        'WindowButtonMotionFcn', []); % Disable default motion callback

    % Create subplot for velocity with adjusted position
    ax1 = subplot(1, 2, 1);
    p1 = get(ax1, 'Position');
    set(ax1, 'Position', [p1(1) p1(2)+0.2 p1(3) p1(4)-0.2], ... % Move up and reduce height
        'Box', 'on', ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.15);
    
    xlabel(ax1, 'Velocity (m/s)', 'FontWeight', 'bold');
    ylabel(ax1, 'Height (m)', 'FontWeight', 'bold');
    title(ax1, 'Velocity Profile', 'FontSize', 14, 'FontWeight', 'bold');
    xlim(ax1, data.xRange);
    ylim(ax1, data.yRange);
    grid(ax1, 'on');
    hold(ax1, 'on');

    % Create subplot for turbulence intensity with adjusted position
    ax2 = subplot(1, 2, 2);
    p2 = get(ax2, 'Position');
    set(ax2, 'Position', [p2(1) p2(2)+0.2 p2(3) p2(4)-0.2], ... % Move up and reduce height
        'Box', 'on', ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.15);
    
    xlabel(ax2, 'Turbulence Intensity I_x', 'FontWeight', 'bold');
    ylabel(ax2, 'Height (m)', 'FontWeight', 'bold');
    title(ax2, 'Turbulence Intensity Profile', 'FontSize', 14, 'FontWeight', 'bold');
    xlim(ax2, data.IxRange);
    ylim(ax2, data.yRange);
    grid(ax2, 'on');
    hold(ax2, 'on');

    % ====== Control Panel ======
    panel = uipanel(f, 'Title', 'Controls', ...
        'Position', [0.05 0.02 0.9 0.2], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'FontWeight', 'bold');

    % First row - Step size, Clear previous, and Height Time Series
    createLabel(panel, 'Step size:', [20 100 70 20]);
    stepBox = createEdit(panel, num2str(default_step), [90 100 60 20], @(src,~) updateStepSize(src, data));
    clearCheckbox = uicontrol(panel, 'Style', 'checkbox', ...
        'String', 'Clear previous', ...
        'Value', 1, ...
        'Position', [170 100 100 20], ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'FontWeight', 'bold');
    
    % Add Height Time Series button
    heightTimeSeriesBtn = uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Height Time Series', ...
        'Position', [280 100 120 20], ...
        'Callback', @(src,~) showHeightTimeSeries(f));

    % Add Calibration button
    calibrationBtn = uicontrol(panel, 'Style', 'pushbutton', ...
        'String', 'Calibration', ...
        'Position', [410 100 100 20], ...
        'Callback', @(src,~) showCalibration(f));

    % Frame and time displays
    txt_frame = createLabel(panel, 'Frame: 1', [520 100 80 20]);
    txt_time = createLabel(panel, 'Time: 0.000', [610 100 120 20]);

    % Second row - Frame control
    slider = uicontrol(panel, 'Style', 'slider', ...
        'Min', 1, ...
        'Max', data.num_frames, ...
        'Value', 1, ...
        'SliderStep', [1/(max(data.num_frames-1,1)), 5/(max(data.num_frames-1,1))], ...
        'Position', [20 60 300 20], ...
        'BackgroundColor', [0.8 0.8 0.8], ...
        'Callback', @(src,~) updatePlot(f));

    % Play controls next to slider
    playButton = uicontrol(panel, 'Style', 'pushbutton', ...
        'String', '>', ...
        'Position', [330 60 40 20], ...
        'Callback', @(src,~) togglePlay(f));

    % Speed control
    createLabel(panel, 'Speed:', [390 60 50 20]);
    speedSlider = uicontrol(panel, 'Style', 'slider', ...
        'Min', 0.1, ...
        'Max', 5, ...
        'Value', 1, ...
        'SliderStep', [0.1/4.9, 0.5/4.9], ...
        'Position', [440 60 100 20], ...
        'BackgroundColor', [0.8 0.8 0.8], ...
        'Callback', @(src,~) updateSpeed(f));
    txt_speed = createLabel(panel, '1.0x', [545 60 40 20]);

    % Third row - Range controls
    % Velocity X Range
    createLabel(panel, 'Velocity X Range:', [20 20 100 20]);
    xmin1 = createEdit(panel, num2str(data.xRange(1)), [120 20 40 20], @(src,~) updateAxisRange(f));
    xmax1 = createEdit(panel, num2str(data.xRange(2)), [165 20 40 20], @(src,~) updateAxisRange(f));
    
    % Turbulence X Range
    createLabel(panel, 'Turbulence X Range:', [220 20 120 20]);
    xmin2 = createEdit(panel, num2str(data.IxRange(1)), [340 20 40 20], @(src,~) updateAxisRange(f));
    xmax2 = createEdit(panel, num2str(data.IxRange(2)), [385 20 40 20], @(src,~) updateAxisRange(f));
    
    % Y Range
    createLabel(panel, 'Y Range:', [440 20 60 20]);
    ymin = createEdit(panel, num2str(data.yRange(1)), [500 20 40 20], @(src,~) updateAxisRange(f));
    ymax = createEdit(panel, num2str(data.yRange(2)), [545 20 40 20], @(src,~) updateAxisRange(f));

    % Store UI elements in the figure's UserData
    f.UserData = struct('data', data, 'ax1', ax1, 'ax2', ax2, 'slider', slider, ...
        'txt_frame', txt_frame, 'txt_time', txt_time, ...
        'clearCheckbox', clearCheckbox, 'playButton', playButton, ...
        'speedSlider', speedSlider, 'txt_speed', txt_speed, ...
        'xmin1', xmin1, 'xmax1', xmax1, ...  % Separate x range controls for velocity
        'xmin2', xmin2, 'xmax2', xmax2, ...  % Separate x range controls for turbulence
        'ymin', ymin, 'ymax', ymax);

    % Initial plot
    updatePlot(f);
end

function updateStepSize(stepBox, data)
    f = stepBox.Parent.Parent;
    ud = f.UserData;
    
    step = str2double(get(stepBox, 'String'));
    if isnan(step) || step <= 0
        warndlg('Please enter a valid positive integer step size', 'Invalid Input');
        return;
    end

    % Add debug information
    fprintf('Updating step size to: %d\n', step);
    fprintf('Total data rows: %d\n', size(data.U_mean, 1));
    
    % Update data
    rows_to_use = 1:step:size(data.U_mean, 1);
    num_frames = length(rows_to_use);
    
    fprintf('New number of frames: %d\n', num_frames);
    
    if num_frames < 1
        warndlg('Step size too large, no frames to display', 'Invalid Step Size');
        return;
    end
    
    [velocity_data, turbulence_data, time_data] = loadVelocityAndTurbulenceData(data.U_mean, data.uu_mean, rows_to_use, num_frames);
    
    % Update stored data
    ud.data.velocity_data = velocity_data;
    ud.data.turbulence_data = turbulence_data;
    ud.data.time_data = time_data;
    ud.data.num_frames = num_frames;
    ud.data.rows_to_use = rows_to_use;
    
    % Update slider properties
    set(ud.slider, 'Min', 1);
    set(ud.slider, 'Max', num_frames);
    set(ud.slider, 'Value', 1);
    set(ud.slider, 'SliderStep', [1/(max(num_frames-1,1)), 5/(max(num_frames-1,1))]);
    
    % Store updated data
    f.UserData = ud;
    
    % Force a complete redraw
    cla(ud.ax1);
    cla(ud.ax2);
    updatePlot(f);
end

function updatePlot(f)
    ud = f.UserData;
    data = ud.data;
    slider = ud.slider;
    ax1 = ud.ax1;  % Get velocity subplot
    ax2 = ud.ax2;  % Get turbulence subplot
    txt_frame = ud.txt_frame;
    txt_time = ud.txt_time;
    clearCheckbox = ud.clearCheckbox;
    
    % Ensure currentFrame is within valid range
    currentFrame = min(max(1, round(get(slider, 'Value'))), data.num_frames);
    set(slider, 'Value', currentFrame);

    % Clear both axes
    cla(ax1);
    cla(ax2);

    if get(clearCheckbox, 'Value')
        % Single frame mode - only show current frame
        plot(ax1, data.velocity_data{currentFrame}, data.height, 'LineWidth', 2, 'Color', [0 0.447 0.741]);
        plot(ax2, data.turbulence_data{currentFrame}, data.height, 'LineWidth', 2, 'Color', [0.85 0.325 0.098]);
    else
        % Multi-frame mode - show all frames up to current frame
        colors = parula(currentFrame);
        for i = 1:currentFrame
            plot(ax1, data.velocity_data{i}, data.height, 'LineWidth', 1.5, 'Color', colors(i,:));
            plot(ax2, data.turbulence_data{i}, data.height, 'LineWidth', 1.5, 'Color', colors(i,:));
        end
    end

    grid(ax1, 'on');
    grid(ax2, 'on');
    set(txt_frame, 'String', ['Frame: ' num2str(currentFrame)]);
    set(txt_time, 'String', sprintf('Time: %.3f s', data.time_data(currentFrame)));
end

% ====== Helper Functions ======
function [velocity_data, turbulence_data, time_data] = loadVelocityAndTurbulenceData(U_mean, uu_mean, rows_to_use, num_frames)
    velocity_data = cell(num_frames, 1);
    turbulence_data = cell(num_frames, 1);
    time_data = zeros(num_frames, 1);
    for i = 1:num_frames
        row_idx = rows_to_use(i);
        velocity = U_mean(row_idx, 3:end)';
        uu = uu_mean(row_idx, 3:end)';
        velocity_data{i} = velocity;
        % Calculate turbulence intensity: Ix = sqrt(uu_mean)/U_mean
        turbulence_data{i} = sqrt(abs(uu))./velocity;  % Using abs to avoid complex numbers
        time_data(i) = U_mean(row_idx, 1);
    end
end

function label = createLabel(parent, string, position)
    label = uicontrol(parent, 'Style', 'text', ...
        'String', string, ...
        'Position', position, ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'FontWeight', 'bold');
end

function edit = createEdit(parent, string, position, callback)
    edit = uicontrol(parent, 'Style', 'edit', ...
        'String', string, ...
        'Position', position, ...
        'Callback', callback, ...
        'BackgroundColor', 'white');
end

% Add toggle play function
function togglePlay(f)
    ud = f.UserData;
    
    if ~ud.data.isPlaying
        % Start playing
        ud.data.isPlaying = true;
        set(ud.playButton, 'String', '⏸');
        
        % Create and start timer with current speed
        ud.data.playTimer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.1/ud.data.playSpeed, ... % Update period adjusted by speed
            'TimerFcn', @(~,~) playCallback(f));
        start(ud.data.playTimer);
    else
        % Stop playing
        ud.data.isPlaying = false;
        set(ud.playButton, 'String', '▶');
        
        % Stop and delete timer
        if ~isempty(ud.data.playTimer)
            stop(ud.data.playTimer);
            delete(ud.data.playTimer);
            ud.data.playTimer = [];
        end
    end
    
    f.UserData = ud;
end

% Add play callback function
function playCallback(f)
    ud = f.UserData;
    currentFrame = get(ud.slider, 'Value');
    
    % Increment frame
    nextFrame = currentFrame + 1;
    
    % Check if we reached the end
    if nextFrame > ud.data.num_frames
        nextFrame = 1;  % Loop back to start
    end
    
    % Update slider value which will trigger plot update
    set(ud.slider, 'Value', nextFrame);
    updatePlot(f);
end

% Update the figure cleanup
function figure1_CloseRequestFcn(hObject, ~)
    ud = hObject.UserData;
    if ~isempty(ud.data.playTimer)
        stop(ud.data.playTimer);
        delete(ud.data.playTimer);
    end
    delete(hObject);
end

% Add speed update function
function updateSpeed(f)
    ud = f.UserData;
    speed = get(ud.speedSlider, 'Value');
    ud.data.playSpeed = speed;
    set(ud.txt_speed, 'String', sprintf('%.1fx', speed));
    
    % Update timer period if playing
    if ud.data.isPlaying && ~isempty(ud.data.playTimer)
        stop(ud.data.playTimer);
        set(ud.data.playTimer, 'Period', 0.1/speed);
        start(ud.data.playTimer);
    end
    
    f.UserData = ud;
end

% Update axis range update function
function updateAxisRange(f)
    ud = f.UserData;
    
    % Get values from edit boxes for both plots
    xmin1 = str2double(get(ud.xmin1, 'String'));
    xmax1 = str2double(get(ud.xmax1, 'String'));
    xmin2 = str2double(get(ud.xmin2, 'String'));
    xmax2 = str2double(get(ud.xmax2, 'String'));
    ymin = str2double(get(ud.ymin, 'String'));
    ymax = str2double(get(ud.ymax, 'String'));
    
    % Validate input
    if any(isnan([xmin1 xmax1 xmin2 xmax2 ymin ymax]))
        warndlg('Please enter valid numbers for axis ranges', 'Invalid Input');
        return;
    end
    
    % Update ranges if valid
    if xmin1 < xmax1
        ud.data.xRange = [xmin1 xmax1];
        xlim(ud.ax1, [xmin1 xmax1]);
    end
    
    if xmin2 < xmax2
        ud.data.IxRange = [xmin2 xmax2];
        xlim(ud.ax2, [xmin2 xmax2]);
    end
    
    if ymin < ymax
        ud.data.yRange = [ymin ymax];
        ylim(ud.ax1, [ymin ymax]);
        ylim(ud.ax2, [ymin ymax]);
    end
    
    f.UserData = ud;
end

% Add new function for height time series
function showHeightTimeSeries(f)
    ud = f.UserData;
    data = ud.data;
    
    % Get height input from user
    height_input = inputdlg('Enter height (m):', 'Height Time Series', 1, {num2str(mean(data.yRange))});
    
    if isempty(height_input)
        return;
    end
    
    target_height = str2double(height_input{1});
    
    % Validate height input
    if isnan(target_height)
        warndlg('Please enter a valid number for height', 'Invalid Input');
        return;
    end
    
    if target_height < min(data.height) || target_height > max(data.height)
        warndlg(sprintf('Height must be between %.2f and %.2f m', min(data.height), max(data.height)), 'Invalid Input');
        return;
    end
    
    % Create new figure for time series
    ts_fig = figure('Name', sprintf('Time Series at Height %.2f m', target_height), ...
        'NumberTitle', 'off', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.2 0.2 0.6 0.4]);
    
    % Create subplots for velocity and turbulence
    subplot(1, 2, 1);
    ax_v = gca;
    hold(ax_v, 'on');
    grid(ax_v, 'on');
    xlabel('Time (s)', 'FontWeight', 'bold');
    ylabel('Velocity (m/s)', 'FontWeight', 'bold');
    title(sprintf('Velocity at %.2f m', target_height), 'FontSize', 14, 'FontWeight', 'bold');
    
    subplot(1, 2, 2);
    ax_t = gca;
    hold(ax_t, 'on');
    grid(ax_t, 'on');
    xlabel('Time (s)', 'FontWeight', 'bold');
    ylabel('Turbulence Intensity I_x', 'FontWeight', 'bold');
    title(sprintf('Turbulence Intensity at %.2f m', target_height), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Get interpolated values at target height for all frames
    velocity_ts = zeros(data.num_frames, 1);
    turbulence_ts = zeros(data.num_frames, 1);
    
    for i = 1:data.num_frames
        velocity_ts(i) = interp1(data.height, data.velocity_data{i}, target_height, 'linear');
        turbulence_ts(i) = interp1(data.height, data.turbulence_data{i}, target_height, 'linear');
    end
    
    % Plot time series
    plot(ax_v, data.time_data, velocity_ts, 'LineWidth', 2);
    plot(ax_t, data.time_data, turbulence_ts, 'LineWidth', 2);
    
    % Set axis limits
    xlim(ax_v, [min(data.time_data) max(data.time_data)]);
    xlim(ax_t, [min(data.time_data) max(data.time_data)]);
    ylim(ax_v, data.xRange);
    ylim(ax_t, data.IxRange);
end

% Add calibration function at the end of the file
function showCalibration(f)
    ud = f.UserData;
    data = ud.data;
    
    % Get current frame data
    currentFrame = round(get(ud.slider, 'Value'));
    velocity = data.velocity_data{currentFrame};
    turbulence = data.turbulence_data{currentFrame};
    height = data.height;
    
    % Ensure all vectors are column vectors
    velocity = velocity(:);
    turbulence = turbulence(:);
    height = height(:);
    
    % Filter out any unreasonable values
    valid_idx = velocity > 0 & ...  % Only ensure positive values
               turbulence > 0 & ... % Only ensure positive values
               height > 0;          % Only ensure positive values
    
    if ~any(valid_idx)
        warndlg('No valid data points found for fitting', 'Fitting Error');
        return;
    end
    
    % Extract valid data points
    height_valid = height(valid_idx);
    velocity_valid = velocity(valid_idx);
    turbulence_valid = turbulence(valid_idx);
    
    % Create input dialog for reference values
    prompt = {'Reference height (m):', 'Roughness length z₀ (m) (leave empty to calibrate both u* and z₀):'};
    dlgtitle = 'Calibration Settings';
    dims = [1 50; 1 50];
    definput = {'90', ''};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(answer)
        return;
    end
    
    z_ref = str2double(answer{1});
    z0_input = str2double(answer{2});
    
    % Validate inputs
    if isnan(z_ref) || z_ref < min(height_valid) || z_ref > max(height_valid)
        warndlg(sprintf('Reference height must be between %.2f and %.2f m', min(height_valid), max(height_valid)), 'Invalid Input');
        return;
    end
    
    % Get reference values at z_ref
    U_ref = interp1(height_valid, velocity_valid, z_ref, 'linear');
    I_ref = interp1(height_valid, turbulence_valid, z_ref, 'linear');
    
    % Von Kármán constant
    k = 0.4;
    
    % Calculate power law exponents using linear regression in log space
    log_height_ratio = log(height_valid/z_ref);
    log_velocity_ratio = log(velocity_valid/U_ref);
    log_turbulence_ratio = log(turbulence_valid/I_ref);
    
    % Perform linear regression for power law
    alpha = log_height_ratio \ log_velocity_ratio;
    beta = log_height_ratio \ log_turbulence_ratio;
    
    % Logarithmic law fitting
    if isnan(z0_input)
        % Method 1: Calibrate both u* and z₀
        % Using linear regression: U = (u*/k)*ln(z) - (u*/k)*ln(z₀)
        % This is in the form: y = ax + b, where:
        % y = U, x = ln(z), a = u*/k, b = -(u*/k)*ln(z₀)
        X = [ones(length(height_valid), 1), log(height_valid)];
        coeffs = X \ velocity_valid;
        b = coeffs(1);
        a = coeffs(2);
        u_star = k * a;
        z0 = exp(-b/a);
    else
        % Method 2: Use specified z0 and calibrate u*
        if z0_input <= 0
            warndlg('Roughness length must be positive', 'Invalid Input');
            return;
        end
        z0 = z0_input;
        % Using U = (u*/k)*ln(z/z₀), solve for u*
        u_star = mean(k * velocity_valid ./ log(height_valid/z0));
    end
    
    % Calculate IEC turbulence model parameters
    % Fit I_ref to minimize the difference between measured and predicted I_u
    % I_u = I_ref * (0.75 + 5.6/U)
    % Using least squares to find optimal I_ref
    I_pred_norm = 0.75 + 5.6./velocity_valid;
    I_ref_IEC = (I_pred_norm' * turbulence_valid) / (I_pred_norm' * I_pred_norm);
    
    % Generate fitted curves with more points for smooth plotting
    z_fit = linspace(min(height_valid), max(height_valid), 100)';
    
    % Power law fits
    U_fit_power = U_ref * (z_fit/z_ref).^alpha;
    I_fit_power = I_ref * (z_fit/z_ref).^beta;
    
    % Logarithmic law fit for velocity
    U_fit_log = (u_star/k) * log(z_fit/z0);
    
    % IEC standard turbulence model using local wind speed
    U_fit_interp = interp1(height_valid, velocity_valid, z_fit, 'linear');
    I_fit_IEC = I_ref_IEC * (0.75 + 5.6./U_fit_interp);
    
    % Create new figure for calibration results with improved UI
    cal_fig = figure('Name', 'Wind Profile Calibration Results', ...
        'NumberTitle', 'off', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.15 0.15 0.7 0.7]);
    
    % Create panel for plots
    plot_panel = uipanel(cal_fig, 'Position', [0.05 0.25 0.9 0.7], ...
        'BackgroundColor', [0.94 0.94 0.94]);
    
    % Plot velocity profile and fits
    ax1 = subplot(1, 2, 1, 'Parent', plot_panel);
    plot(ax1, velocity_valid, height_valid, 'ko', 'DisplayName', 'Data', 'MarkerFaceColor', 'k');
    hold(ax1, 'on');
    plot(ax1, U_fit_power, z_fit, 'r-', 'LineWidth', 2, 'DisplayName', ['Power Law ($\alpha = ' sprintf('%.3f', alpha) '$)']);
    plot(ax1, U_fit_log, z_fit, 'b-', 'LineWidth', 2, 'DisplayName', ['Log Law ($u_* = ' sprintf('%.2f', u_star) '$ m/s, $z_0 = ' sprintf('%.4f', z0) '$ m)']);
    plot(ax1, U_ref, z_ref, 'gs', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Reference Point');
    grid(ax1, 'on');
    xlabel(ax1, 'Wind Speed (m/s)', 'FontWeight', 'bold');
    ylabel(ax1, 'Height (m)', 'FontWeight', 'bold');
    title(ax1, 'Wind Speed Profile', 'FontSize', 14, 'FontWeight', 'bold');
    legend(ax1, 'Location', 'best', 'Interpreter', 'latex');
    set(ax1, 'Box', 'on', 'FontSize', 11);
    
    % Plot turbulence profile and fits
    ax2 = subplot(1, 2, 2, 'Parent', plot_panel);
    plot(ax2, turbulence_valid, height_valid, 'ko', 'DisplayName', 'Data', 'MarkerFaceColor', 'k');
    hold(ax2, 'on');
    plot(ax2, I_fit_power, z_fit, 'r-', 'LineWidth', 2, 'DisplayName', ['Power Law ($\beta = ' sprintf('%.3f', beta) '$)']);
    plot(ax2, I_fit_IEC, z_fit, 'b-', 'LineWidth', 2, 'DisplayName', ['IEC Standard ($I_{ref} = ' sprintf('%.3f', I_ref_IEC) '$)']);
    plot(ax2, I_ref, z_ref, 'gs', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Reference Point');
    grid(ax2, 'on');
    xlabel(ax2, 'Turbulence Intensity I_u', 'FontWeight', 'bold');
    ylabel(ax2, 'Height (m)', 'FontWeight', 'bold');
    title(ax2, 'Turbulence Intensity Profile', 'FontSize', 14, 'FontWeight', 'bold');
    legend(ax2, 'Location', 'best', 'Interpreter', 'latex');
    set(ax2, 'Box', 'on', 'FontSize', 11);
    
    % Create panel for results with increased height and lower position
    results_panel = uipanel(cal_fig, 'Title', 'Calibration Results', ...
        'Position', [0.05 0.02 0.9 0.25], ... % Lowered position from 0.05 to 0.02
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.94 0.94 0.94]);
    
    % Create axes for text display
    text_ax = axes('Parent', results_panel, ...
        'Position', [0 0 1 1], ...
        'Visible', 'off');
    
    % Create section titles
    text(text_ax, 0.05, 0.9, 'Reference Parameters:', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Units', 'normalized');
    
    text(text_ax, 0.35, 0.9, 'Wind Speed Models:', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Units', 'normalized');
    
    text(text_ax, 0.65, 0.9, 'Turbulence Models:', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Units', 'normalized');
    
    % Create reference parameters content using latex
    ref_text = sprintf(['$z_{ref} = %.1f$ m\n', ...
                       '$U_{ref} = %.2f$ m/s\n', ...
                       '$I_{ref} = %.3f$'], ...
                       z_ref, U_ref, I_ref);
    
    text(text_ax, 0.05, 0.8, ref_text, ...
        'FontSize', 10, ...
        'VerticalAlignment', 'top', ...
        'Units', 'normalized', ...
        'Interpreter', 'latex');
    
    % Create wind speed models content using latex
    wind_text = sprintf(['Power Law:\n', ...
                        '$U(z) = U_{ref}(z/z_{ref})^{\\alpha} = %.3f(z/%.1f)^{%.3f}$\n\n', ...
                        'Log Law:\n', ...
                        '$U(z) = \\frac{u_{*}}{k}\\ln(z/z_{0}) = (%.3f/0.40)\\ln(z/%.4f)$'], ...
                        U_ref, z_ref, alpha, u_star, z0);

    
    text(text_ax, 0.35, 0.8, wind_text, ...
        'FontSize', 10, ...
        'VerticalAlignment', 'top', ...
        'Units', 'normalized', ...
        'Interpreter', 'latex');
    
    % Create turbulence models content using latex
    turb_text = sprintf(['Power Law:\n', ...
                        '$I_u(z) = I_{ref}(z/z_{ref})^{\\beta} = %.3f(z/%.1f)^{%.3f}$\n\n', ...
                        'IEC 61400-1 (Editions 3 (2005) and 4 (2019)):\n', ...
                        '$I_u(z) = I_{ref}(0.75 + 5.6/U) = %.3f(0.75 + 5.6/U)$'], ...
                        I_ref, z_ref, beta, I_ref_IEC);
    
    text(text_ax, 0.65, 0.8, turb_text, ...
        'FontSize', 10, ...
        'VerticalAlignment', 'top', ...
        'Units', 'normalized', ...
        'Interpreter', 'latex');
end
