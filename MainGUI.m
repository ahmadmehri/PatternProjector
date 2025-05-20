function MainGUI()

% Clear all variables in the base workspace
evalin('base', 'clear;');
close all;
clc;

% Find all open uifigure windows and close the one with the name 'Stereonet Analysis'
all_figs = findall(0, 'Type', 'figure');
for i = 1:length(all_figs)
    fig_name = get(all_figs(i), 'Name');
    if strcmp(fig_name, 'Main GUI')
        % Close the existing uifigure window
        close(all_figs(i));
        break; % Exit loop once the figure is found and closed
    end
end

BackgroundData =load('DefultBackground.mat');
Background=BackgroundData.Background;
% Background=imread('Black.jpg');
Back = Background;
Ax = [];
AnimationStream='';
ext='';
BackgroundLoaded=false;

% Define color scheme
mainBgColor = [0.1, 0.1, 0.1];     % Dark background
panelColor = [0.2, 0.2, 0.2];      % Slightly lighter gray for panels
tabColor = [0.15, 0.15, 0.15];     % Slightly darker tabs
btnColor = [0.3, 0.3, 0.8];        % Blue button color for better visibility
hoverColor = [0.4, 0.4, 1.0];      % Brighter blue hover effect
textColor = 'white';               % White text
headerFontSize = 14;
buttonFontSize = 12;

% Create the main GUI figure
mainFig = figure('Name', 'Main GUI', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'NumberTitle', 'off', 'Color', mainBgColor, 'Position', [200, 100, 700, 500]);
if isappdata(mainFig, 'parameters'); rmappdata(mainFig, 'parameters'); end


% Create tab group with better contrast
panel = uipanel('Parent', mainFig, 'BackgroundColor', panelColor, 'BorderType', 'none', ...
    'Position', [0.05, 0.05, 0.9, 0.4]);

% Tabs
tabGroup = uitabgroup('Parent', panel, 'Position', [0 0 1 1]);
set(tabGroup, 'FontSize', headerFontSize);

% Tab for Advanced Adjustment
advancedTab = uitab(tabGroup, 'Title', '🔧 Overlay Adjustment', 'BackgroundColor', tabColor);
uicontrol('Parent', advancedTab, 'Style', 'text', 'String', 'Advanced Adjustment Controls', ...
    'FontSize', headerFontSize, 'FontWeight', 'bold', 'ForegroundColor', textColor, ...
    'BackgroundColor', tabColor, 'Position', [5 90 350 40]);
btn2 = uicontrol('Parent', advancedTab, 'Style', 'pushbutton', 'String', 'Manual Pattern Adjustment', ...
    'Position', [350 65 250 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @openAdvancedAdjustment);
btn4 = uicontrol('Parent', advancedTab, 'Style', 'pushbutton', 'String', 'Semi-Auto Patturn Adjustment', ...
    'Position', [350 120 250 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @openAutomaticAdjustment);
btn3 = uicontrol('Parent', advancedTab, 'Style', 'pushbutton', 'String', 'Display Off', ...
    'Position', [30 20 200 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @DisplayOff);
btn4 = uicontrol('Parent', advancedTab, 'Style', 'pushbutton', 'String', 'Start Pattern Projection', ...
    'Position', [350 10 250 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @ProjectPattern);

% Button hover effects
set(btn2, 'ButtonDownFcn', @(src, ~) set(src, 'BackgroundColor', hoverColor));

% New features (added UI elements)

% Button to detect displays and show properties
btnDetectDisplays = uicontrol('Parent', mainFig, 'Style', 'pushbutton', 'String', 'Detect Displays', ...
    'Position', [30 450 150 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @detectDisplays);

% Value box to enter the Display ID
uicontrol('Parent', mainFig, 'Style', 'text', 'String', 'Enter Display ID:', ...
    'FontSize', buttonFontSize, 'ForegroundColor', textColor, 'BackgroundColor', mainBgColor, ...
    'Position', [200 440 130 30]);

% Create the input box for the display ID
displayIDBox = uicontrol('Parent', mainFig, 'Style', 'edit', 'String', '2', ...
    'FontSize', buttonFontSize, 'Position', [340 450 50 30]);


% Button to input 'Map Pattern' image file
btnMapPattern = uicontrol('Parent', mainFig, 'Style', 'pushbutton', 'String', 'Input Map Pattern', ...
    'Position', [30 340 200 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Callback', @inputMapPattern);

% Checkbox for background image activation
chkBackground = uicontrol('Parent', mainFig, 'Style', 'checkbox', 'String', 'Use Custom Background Image', ...
    'Position', [450 380 250 30], 'FontSize', buttonFontSize, 'ForegroundColor', textColor, ...
    'BackgroundColor', mainBgColor, 'Callback', @toggleBackground);

% Button to input background image file (initially disabled)
btnBackground = uicontrol('Parent', mainFig, 'Style', 'pushbutton', 'String', 'Input Background Image', ...
    'Position', [470 340 200 40], 'FontSize', buttonFontSize, 'FontWeight', 'bold', ...
    'BackgroundColor', btnColor, 'ForegroundColor', textColor, 'Enable', 'off', 'Callback', @inputBackground);

% Checkbox for Alpha Blending
chkAlphaBlending = uicontrol('Parent', mainFig, 'Style', 'checkbox', 'String', 'Enable Alpha Blending', ...
    'Position', [30 270 200 30], 'FontSize', buttonFontSize, 'ForegroundColor', textColor, ...
    'BackgroundColor', mainBgColor, 'Callback', @toggleAlphaBlending);

% Input box for Alpha (initially disabled)
uicontrol('Parent', mainFig, 'Style', 'text', 'String', 'Alpha (0-1):', ...
    'FontSize', buttonFontSize, 'ForegroundColor', textColor, 'BackgroundColor', mainBgColor, ...
    'Position', [45 240 130 30]);

alphaBox = uicontrol('Parent', mainFig, 'Style', 'edit', 'String', '0.7', ...
    'FontSize', buttonFontSize, 'Position', [160 240 60 30], 'Enable', 'off');

uicontrol('Parent', mainFig, 'Style', 'text', 'String', 'Size Scale (0-1):', ...
    'FontSize', buttonFontSize, 'ForegroundColor', textColor, 'BackgroundColor', mainBgColor, ...
    'Position', [30 300 130 30]);
defaultResizeFactor = uicontrol('Parent', mainFig, 'Style', 'edit', 'String', '0.85', ...
    'FontSize', buttonFontSize, 'Position', [160 305 60 30], 'Enable', 'on');

% Set the initial value for alpha as NaN
alphaValue = NaN;

% Checkbox callback function to enable/disable alpha input box
    function toggleAlphaBlending(~, ~)
        if get(chkAlphaBlending, 'Value') == 1
            set(alphaBox, 'Enable', 'on');
            alphaValue = str2double(get(alphaBox, 'String')); % default to 0.7 when checked
            if isnan(alphaValue)
                alphaValue = 0.7;  % default value if nothing is entered
            end
        else
            set(alphaBox, 'Enable', 'off');
            alphaValue = NaN;

        end
    end

    function detectDisplays(~, ~)
        % Example code for detecting displays and showing in a table
        screens = get(0, 'MonitorPositions');
        displayList = cell(size(screens, 1), 4); % 4 columns: Display ID, Position, Resolution, etc.

        for i = 1:size(screens, 1)
            displayList{i, 1} = num2str(i);  % Display ID
            displayList{i, 2} = sprintf('(%d, %d)', screens(i, 1), screens(i, 2));  % Position
            displayList{i, 3} = sprintf('%dx%d', screens(i, 3), screens(i, 4));  % Resolution
        end
        f = findobj('Type', 'figure', 'Name', 'Display Information');
        if ~isempty(f) && ishandle(f)
            close(f);  % Close the figure if it exists and is still open
        end
        % Create a table to show the display information
        f = figure('Name', 'Display Information', 'NumberTitle', 'off', 'Position', [600, 220, 400, 300]);
        uitable(f, 'Data', displayList, 'ColumnName', {'Display ID', 'Position', 'Resolution'}, ...
            'Position', [30 30 360 250]);
    end

    function inputMapPattern(~, ~)
        % Modify the filter to allow .mp4 and .gif files
        [file, path] = uigetfile({'*.png;*.jpg;*.jpeg;*.mp4;*.gif', 'Image and Video Files'}, 'Select Map Pattern');

        if file
            % Determine the file extension
            [~, ~, ext] = fileparts(file);

            switch ext
                case {'.png', '.jpg', '.jpeg', '.PNG', '.JPG', '.JPEG'}
                    % For image files, load the image as before
                    Ax = imread(fullfile(path, file));
                    AnimationStream = ''; % No video or GIF for image files

                case {'.mp4' '.MP4'}
                    % For .mp4 video files
                    videoObj = VideoReader(fullfile(path, file));
                    firstFrame = readFrame(videoObj); % Get the first frame of the video
                    Ax = firstFrame; % Store the first frame as Ax (thumbnail)
                    AnimationStream = fullfile(path, file); % Store the full path to the video

                case {'.gif', '.GIF'}
                    % For .gif files, read the GIF as a sequence of frames
                    [gifFrames, ~] = imread(fullfile(path, file), 'Index', 1); % Get the first frame of the GIF
                    Ax = gifFrames; % Store the first frame as Ax (thumbnail)
                    AnimationStream = fullfile(path, file); % Store the full path to the GIF
                otherwise
                    warndlg('Unsupported file type.', 'Input Error');
                    return;
            end
            if isappdata(mainFig, 'parameters'); rmappdata(mainFig, 'parameters'); end

        end
    end

    function toggleBackground(~, ~)
        % Toggle the background image button activation
        if get(chkBackground, 'Value') == 1
            set(btnBackground, 'Enable', 'on');

        else
            set(btnBackground, 'Enable', 'off');
            Background = imread('Black.jpg');    % RGB background image
            Back=Background;
        end
    end

    function inputBackground(~, ~)
        % Code to input background image file
        close(figure(20))
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png', 'Image Files'}, 'Select Background Image');
        if file
            Background = imread(fullfile(path, file));
            Back=Background;
            BackgroundLoaded=true;
        end
    end

% Checkbox for enabling grid
chkGrid = uicontrol('Parent', mainFig, 'Style', 'checkbox', 'String', 'Enable Grid', ...
    'Position', [470 300 200 25], 'FontSize', buttonFontSize, 'ForegroundColor', textColor, ...
    'BackgroundColor', mainBgColor, 'Callback', @toggleBackGrid);
% Grid spacing input
uicontrol('Parent', mainFig, 'Style', 'text', 'String', 'Grid Spacing:', ...
    'FontSize', buttonFontSize, 'ForegroundColor', textColor, 'BackgroundColor', mainBgColor, ...
    'Position', [470 270 100 25]);
gridSpacingBox = uicontrol('Parent', mainFig, 'Style', 'edit', 'String', '25', ...
    'FontSize', buttonFontSize, 'Position', [570 270 60 25], 'BackgroundColor', 'white', 'Enable','off');

% Grid color dropdown
uicontrol('Parent', mainFig, 'Style', 'text', 'String', 'Grid Color:', ...
    'FontSize', buttonFontSize, 'ForegroundColor', textColor, 'BackgroundColor', mainBgColor, ...
    'Position', [480 240 100 25]);
gridColorDropdown = uicontrol('Parent', mainFig, 'Style', 'popupmenu', ...
    'String', {'White', 'Black','Red', 'Green', 'Blue'}, ...
    'Position', [570 240 80 25], 'FontSize', buttonFontSize, 'BackgroundColor', 'white', 'Enable','off');

    function toggleBackGrid(~, ~)
    % Check if the grid checkbox is checked
    if get(chkGrid, 'Value') == 1
        % Enable grid spacing and color controls
        set(gridSpacingBox, 'Enable', 'on');
        set(gridColorDropdown, 'Enable', 'on');

        % Get grid spacing value
        GridSpacing = str2double(get(gridSpacingBox, 'String')); % default to 25 when checked
        if isnan(GridSpacing)
            GridSpacing = 25;  % default value if nothing is entered
        end

        % Get grid color
        selectedValue = gridColorDropdown.Value; % Get the selected index
        if selectedValue == 1
            GridColor = 'w'; % White
        elseif selectedValue == 2
            GridColor = 'k'; % Black
        elseif selectedValue == 3
            GridColor = 'r'; % Red
        elseif selectedValue == 4
            GridColor = 'g'; % Green
        else
            GridColor = 'b'; % Blue
        end

        % Read the background image
        BackGridOn = Background;
        % Create a figure for processing
        fig = figure('Visible', 'off'); % Make it invisible for processing
        imshow(BackGridOn, 'Border', 'tight');
        hold on;
        % Get image size
        [rows, cols, ~] = size(BackGridOn);
        % Draw vertical grid lines
        for x = 1:GridSpacing:cols
            line([x x], [1 rows], 'Color', GridColor, 'LineWidth', 1);
        end
        % Draw horizontal grid lines
        for y = 1:GridSpacing:rows
            line([1 cols], [y y], 'Color', GridColor, 'LineWidth', 1);
        end
        hold off;
        % Capture the figure as an image
        frame = getframe(gca);
        Back = frame.cdata; % Store the image with grids in a variable
        % Ensure Back has the same size as Background
        Back = imresize(Back, [rows, cols]);
        % Close the invisible figure
        close(fig);
    else
        % Disable grid spacing and color controls
        set(gridSpacingBox, 'Enable', 'off');
        set(gridColorDropdown, 'Enable', 'off');

        % Reset Back to the original Background
        Back = Background;
    end
end

    function openAutomaticAdjustment(~, ~)

        % if ~chkBackground.Value || ~BackgroundLoaded
        %     warndlg('Warning: There is No Input Background Image!', 'Invalid Input');
        %     return
        % end

        if isempty(Ax) || any(isnan(Ax(:)))
            warndlg('Warning: Inpu Map Pattern is empty!', 'Invalid Input');
            return
        end

        FIG = findobj('Type', 'figure', 'Name', 'Overlay Controls');
        FIG1 = findobj('Type', 'figure', 'Name', 'Projection Adjustment');
        FIG2 = findobj('Type', 'figure', 'Name', 'Projection Adjustment_2');
        if ~isempty(FIG) || ~isempty(FIG1) ||~isempty(FIG2)
            close(FIG);
            close(FIG1);
            close(FIG2);
            close(figure(20))
        end

        % Get the value of the display ID input box as a string, then convert it to a number
        displayIDValue = str2double(get(displayIDBox, 'String'));
        monitorPositions = get(0, 'MonitorPositions');

        % Ensure the input is a valid number
        if isnan(displayIDValue) || displayIDValue < 1|| displayIDValue>size(monitorPositions, 1)
            warndlg('Invalid Display ID input. Press Detect Displays to find your display ID.', 'Input Error');
            return
        else
            monitornumber = displayIDValue;
        end
        template = imread('template2.jpg'); % Replace with your template
        % testImage = imread('test2.jpg'); % Replace with your test image
        testImage =Background;
                ResizeFactor=str2double(get(defaultResizeFactor, 'String'));
        if isempty(ResizeFactor) || isnan (ResizeFactor) || ResizeFactor>1 || ResizeFactor<0; ResizeFactor=0.75; end

        matchedCircles = AutoPatternAdjustment(Back, Ax, monitorPositions, monitornumber,alphaValue, ResizeFactor,mainFig);



    end

% Callback functions to open respective GUIs
    function openAdvancedAdjustment(~, ~)

        ResizeFactor=str2double(get(defaultResizeFactor, 'String'));
        if isempty(ResizeFactor) || isnan (ResizeFactor) || ResizeFactor>1 || ResizeFactor<0; ResizeFactor=0.75; end

        toggleBackground()

        toggleBackGrid()

        if isempty(Ax) || any(isnan(Ax(:)))
            warndlg('Warning: Inpu Map Pattern is empty!', 'Invalid Input');
            return
        end

        if get(chkAlphaBlending, 'Value') == 1
            alphaValue = str2double(get(alphaBox, 'String')); % default to 0.7 when checked
            if isnan(alphaValue)
                warndlg('Invalid Alpha value.', 'Input Error');
                return
            end
        else
            alphaValue = NaN;
        end

        % Get the value of the display ID input box as a string, then convert it to a number
        displayIDValue = str2double(get(displayIDBox, 'String'));
        monitorPositions = get(0, 'MonitorPositions');

        % Ensure the input is a valid number
        if isnan(displayIDValue) || displayIDValue < 1|| displayIDValue>size(monitorPositions, 1)
            warndlg('Invalid Display ID input. Press Detect Displays to find your display ID.', 'Input Error');
            return
        else
            monitornumber = displayIDValue;
            % secondMonitor = monitorPositions(monitornumber, :);
            % disp(['Monitor number selected: ', num2str(monitornumber)]);
        end

        FIG = findobj('Type', 'figure', 'Name', 'Overlay Controls');
        FIG1 = findobj('Type', 'figure', 'Name', 'Projection Adjustment');
        FIG2 = findobj('Type', 'figure', 'Name', 'Projection Adjustment_2');
        if ~isempty(FIG) || ~isempty(FIG1) ||~isempty(FIG2)
            close(FIG);
            close(FIG1);
            close(FIG2);
        end
        AdvancedAdjustment(Back, Ax, monitorPositions, monitornumber,alphaValue, ResizeFactor,mainFig);
    end

    function DisplayOff(~, ~)

        % secondMonitor = monitorPositions(monitornumber, :);
        FIG = findobj('Type', 'figure', 'Name', 'Overlay Controls');
        FIG1 = findobj('Type', 'figure', 'Name', 'Projection Adjustment');
        FIG2 = findobj('Type', 'figure', 'Name', 'Projection Adjustment_2');
        FIG3 = findobj('Type', 'figure', 'Name', 'Semi-Auto Alignment');
        if ~isempty(FIG) || ~isempty(FIG1) ||~isempty(FIG2)
            close(FIG)
            close(FIG1);
            close(FIG2);
            close(FIG3);
        end

    end

    function ProjectPattern(~, ~)

        % secondMonitor = monitorPositions(monitornumber, :);
        FIG = findobj('Type', 'figure', 'Name', 'Overlay Controls');
        FIG1 = findobj('Type', 'figure', 'Name', 'Projection Adjustment');
        FIG2 = findobj('Type', 'figure', 'Name', 'Projection Adjustment_2');
        if ~isempty(FIG) || ~isempty(FIG1) ||~isempty(FIG2)
            close(FIG)
            close(FIG1);
            close(FIG2);
        end

        displayIDValue = str2double(get(displayIDBox, 'String'));
        monitornumber = displayIDValue;
        monitorPositions = get(0, 'MonitorPositions');

        if ~isappdata(mainFig, 'parameters')
            warndlg('Please, do the Pattern Adjustment first!', 'Warning');
            return;
        end

        switch ext
            case {'.png', '.jpg', '.jpeg', '.PNG', '.JPG', '.JPEG'}
                applyParameters(Background, Ax, monitorPositions, monitornumber, alphaValue,mainFig)
            case {'.mp4' '.MP4'}
                applyParameters2video(Background, AnimationStream, monitorPositions, monitornumber, alphaValue,mainFig)

            case {'.gif' '.GIF'}
                applyParameters2gif(Background, AnimationStream, monitorPositions, monitornumber, alphaValue,mainFig)
            otherwise
                warndlg('Unsupported file type.', 'Input Error');
                return;
        end


    end


end
