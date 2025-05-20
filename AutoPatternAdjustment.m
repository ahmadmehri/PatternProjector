function Ax_resized = AutoPatternAdjustment(Back, Ax, monitorPositions, monitorNumber, alphaValue, defaultResizeFactor, mainFig)
    % Ensure there's a second monitor
    if size(monitorPositions, 1) < 2
        warndlg('Projector not detected.', 'Monitor Error');
        Ax_resized = [];
        return;
    end

    % Get second monitor details
    secondMonitor = monitorPositions(monitorNumber, :);
    monitorWidth = secondMonitor(3);
    monitorHeight = secondMonitor(4);
    
    % Create variables for process control - make them global within this function
    % so they can be accessed from all nested functions including customGinput
    global isCanceled needsReset;
    isCanceled = false;
    needsReset = false;
    
    % Create control GUI on primary monitor
    controlFig = createControlGUI();
    
    % Store the controlFig handle for access in nested functions
    controlFigHandle = controlFig;

    % Create full-screen figure on the target monitor
    displayFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', ...
        'Color', 'black', 'Units', 'pixels', 'Position', secondMonitor, ...
        'WindowStyle', 'normal', 'Name', 'Semi-Auto Alignment', ...
        'WindowState', 'fullscreen');
    
    % Custom large cursor implementation
    hCursor = [];
    % Create cursor tracking functions
    set(displayFig, 'WindowButtonMotionFcn', @trackCursor);
    
    % Create CloseRequestFcn for displayFig to properly handle closing
    set(displayFig, 'CloseRequestFcn', @handleDisplayFigClose);

    % Determine initial parameters
    if isappdata(mainFig, 'parameters')
        parameters = getappdata(mainFig, 'parameters');
        defaultValues = [parameters.TopLeftX, parameters.TopLeftY, ...
            parameters.TopRightX, parameters.TopRightY, ...
            parameters.BottomLeftX, parameters.BottomLeftY, ...
            parameters.BottomRightX, parameters.BottomRightY, ...
            parameters.ShiftX, parameters.ShiftY, parameters.RotationAngle];
    else
        W = size(Back, 2);
        H = size(Back, 1);
        scaledW = W * defaultResizeFactor;
        scaledH = H * defaultResizeFactor;
        startX = round((W - scaledW)/2);
        startY = round((H - scaledH)/2);
        endX = startX + scaledW;
        endY = startY + scaledH;
        defaultValues = [startX, startY, endX, startY, startX, endY, endX, endY, 0, 0, 0];
    end

    % Apply initial transformation
    Ax_resized = imresize(Ax, defaultResizeFactor);
    rotationAngle = defaultValues(11);
    rotatedAx = imrotate(Ax_resized, rotationAngle, 'bilinear', 'crop');

    % Input and output corners for initial projection
    inputCorners = [1, 1; size(rotatedAx, 2), 1; 1, size(rotatedAx, 1); size(rotatedAx, 2), size(rotatedAx, 1)];
    shiftX = defaultValues(9);
    shiftY = defaultValues(10);
    outputCorners = [defaultValues(1) + shiftX, defaultValues(2) + shiftY; ...
                     defaultValues(3) + shiftX, defaultValues(4) + shiftY; ...
                     defaultValues(5) + shiftX, defaultValues(6) + shiftY; ...
                     defaultValues(7) + shiftX, defaultValues(8) + shiftY];

    % Compute initial projective transform
    tform = fitgeotrans(inputCorners, outputCorners, 'projective');
    Ax_transformed = imwarp(rotatedAx, tform, 'OutputView', imref2d([size(Back,1), size(Back,2)]));

    % Create overlay
    overlay = createOverlay(Back, Ax_transformed, alphaValue);
    hImage = imshow(overlay, 'Border', 'tight');
    axis off;
    
    % Maximize window to fill screen
    set(displayFig, 'Position', secondMonitor);
    drawnow;

    % Update control GUI to show source points instruction
    updateInstructionText(controlFig, 'Step 1: Select 4 source points on the projection');
    
    % Start the alignment process
    while true
        % Select source points with enhanced markers
        sourcePoints = zeros(4, 2);
        
        % Enable reset for source points selection
        needsReset = false;
        
        for i = 1:4
            % Check if process was canceled or reset requested
            if isCanceled
                cleanupAndExit();
                return;
            end
            
            if needsReset
                break; % Break the loop to restart point selection
            end
            
            % Update point counter
            updatePointCounter(controlFig, i, 4, 'source');
            
            figure(displayFig);
            drawnow;
            set(0, 'CurrentFigure', displayFig);
            
            [x, y] = customGinput(displayFig, 1);
            
            % Check again if process was canceled during point selection
            if isCanceled
                cleanupAndExit();
                return;
            end
            
            if needsReset
                break; % Break the loop if reset was requested during point selection
            end
            
            sourcePoints(i, :) = [x, y];
            hold on;
            % Enhanced point markers
            plot(x, y, 'o', 'Color', [1 1 0], 'MarkerSize', 40, 'LineWidth', 10, ...
                'MarkerFaceColor', [1 1 1]);
            text(x+15, y+15, num2str(i), 'Color', [1 1 0], 'FontSize', 30, ...
                'FontWeight', 'bold', 'BackgroundColor', [0 0 0.5]);
            hold off;
            drawnow;
        end
        
        % If reset was requested, clear the display and start over
        if needsReset
            % Clear markers from the display
            figure(displayFig);
            imshow(overlay, 'Border', 'tight');
            axis off;
            drawnow;
            
            % Reset the needsReset flag
            needsReset = false;
            continue; % Start over from source points collection
        end
        
        % Update control GUI to show destination points instruction
        updateInstructionText(controlFig, 'Step 2: Now select 4 destination points');
        
        % Destination points selection
        destinationPoints = zeros(4, 2);
        
        for i = 1:4
            % Check if process was canceled or reset requested
            if isCanceled
                cleanupAndExit();
                return;
            end
            
            if needsReset
                break; % Break the loop to restart point selection
            end
            
            % Update point counter
            updatePointCounter(controlFig, i, 4, 'destination');
            
            figure(displayFig);
            drawnow;
            set(0, 'CurrentFigure', displayFig);
            
            [x, y] = customGinput(displayFig, 1);
            
            % Check again if process was canceled during point selection
            if isCanceled
                cleanupAndExit();
                return;
            end
            
            if needsReset
                break; % Break the loop if reset was requested during point selection
            end
            
            destinationPoints(i, :) = [x, y];
            hold on;
            % Enhanced destination markers
            plot(x, y, 'o', 'Color', [0 1 0], 'MarkerSize', 40, 'LineWidth', 10, ...
                'MarkerFaceColor', [1 1 0.5]);
            text(x+15, y+15, num2str(i), 'Color', [1 1 0], 'FontSize', 30, ...
                'FontWeight', 'bold', 'BackgroundColor', [0 0 0.5]);
            hold off;
            drawnow;
        end
        
        % If reset was requested, clear the display and start over
        if needsReset
            % Clear markers from the display
            figure(displayFig);
            imshow(overlay, 'Border', 'tight');
            axis off;
            drawnow;
            
            % Reset the needsReset flag
            needsReset = false;
            
            % Reset the instruction to source points
            updateInstructionText(controlFig, 'Step 1: Select 4 source points on the projection');
            continue; % Start over from source points collection
        end
        
        % If we've reached here, both sets of points have been collected successfully
        break;
    end

    % Once points are collected successfully, update status
    updateInstructionText(controlFig, 'Computing transformation...');

    % Compute homography
    H = fitgeotrans(sourcePoints, destinationPoints, 'projective');

    % Apply homography to initial output corners
    initialOutputCorners = outputCorners;
    newOutputCorners = transformPointsForward(H, initialOutputCorners);

    % Update parameters
    parameters = struct();
    parameters.TopLeftX = newOutputCorners(1, 1);
    parameters.TopLeftY = newOutputCorners(1, 2);
    parameters.TopRightX = newOutputCorners(2, 1);
    parameters.TopRightY = newOutputCorners(2, 2);
    parameters.BottomLeftX = newOutputCorners(3, 1);
    parameters.BottomLeftY = newOutputCorners(3, 2);
    parameters.BottomRightX = newOutputCorners(4, 1);
    parameters.BottomRightY = newOutputCorners(4, 2);
    parameters.ShiftX = 0;
    parameters.ShiftY = 0;
    parameters.RotationAngle = 0;

    % Update status and close figures
    updateInstructionText(controlFig, 'Alignment complete! Closing...');
    pause(1); % Show completion message briefly
    
    setappdata(mainFig, 'parameters', parameters);
    cleanupAndExit();
    
    % Nested function to cleanup and exit
    function cleanupAndExit()
        % Clean up custom cursor if it exists
        if ishandle(hCursor)
            delete(hCursor);
        end
        
        % Close all opened figures
        if ishandle(controlFig)
            close(controlFig);
        end
        if ishandle(displayFig)
            close(displayFig);
        end
    end
    
    % Nested function for cursor tracking
    function trackCursor(~, ~)
        % Get current axis and point
        axesHandle = gca;
        currentPoint = get(axesHandle, 'CurrentPoint');
        x = currentPoint(1, 1);
        y = currentPoint(1, 2);
        
        % Delete previous cursor if it exists
        if ishandle(hCursor)
            delete(hCursor);
        end
        
        % Define cursor properties - size and thickness
        cursorSize = 100; % Size of crosshair - increased from 60 to 100
        lineWidth = 6;    % Thickness of lines - increased from 4 to 6
        
        % Create new cursor with custom appearance
        hold on;
        hCursor = [];
        
        % Vertical line - changed color to white [1 1 1]
        hCursor(1) = plot([x x], [y-cursorSize/2 y+cursorSize/2], '-', 'Color', [1 1 1], 'LineWidth', lineWidth);
        
        % Horizontal line - changed color to white [1 1 1]
        hCursor(2) = plot([x-cursorSize/2 x+cursorSize/2], [y y], '-', 'Color', [1 1 1], 'LineWidth', lineWidth);
        
        % Add circular marker at center for better visibility - increased size from 15 to 25
        hCursor(3) = plot(x, y, 'o', 'MarkerSize', 25, 'MarkerEdgeColor', [1 0 0], 'LineWidth', lineWidth, 'MarkerFaceColor', [1 1 0]);
        
        hold off;
        drawnow;
    end
    
    % Nested function to handle display figure close
    function handleDisplayFigClose(~, ~)
        isCanceled = true;
        cleanupAndExit();
    end
    
    % Create the control GUI
    function controlFigHandle = createControlGUI()
        % Get primary monitor position for placement
        primaryScreen = get(0, 'MonitorPositions');
        primaryScreen = primaryScreen(1, :);
        
        % Define figure size
        figWidth = 400;
        figHeight = 300;
        
        % Position in the center of primary monitor
        figX = primaryScreen(1) + (primaryScreen(3) - figWidth) / 2;
        figY = primaryScreen(2) + (primaryScreen(4) - figHeight) / 2;
        
        % Create figure
        controlFigHandle = figure('Name', 'Alignment Control', ...
            'NumberTitle', 'off', ...
            'MenuBar', 'none', ...
            'ToolBar', 'none', ...
            'Position', [figX, figY, figWidth, figHeight], ...
            'Color', [0.2 0.2 0.2], ...
            'CloseRequestFcn', @handleControlFigClose);
        
        % Create panels
        instructionPanel = uipanel('Parent', controlFigHandle, ...
            'Title', 'Instructions', ...
            'TitlePosition', 'centertop', ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'ForegroundColor', [1 1 0], ...
            'FontSize', 12, ...
            'FontWeight', 'bold', ...
            'Position', [0.05 0.55 0.9 0.4]);
        
        buttonPanel = uipanel('Parent', controlFigHandle, ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'Position', [0.05 0.05 0.9 0.3]);
        
        progressPanel = uipanel('Parent', controlFigHandle, ...
            'Title', 'Progress', ...
            'TitlePosition', 'centertop', ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'ForegroundColor', [1 1 0], ...
            'FontSize', 12, ...
            'FontWeight', 'bold', ...
            'Position', [0.05 0.35 0.9 0.2]);
        
        % Create instruction text
        instructionText = uicontrol('Parent', instructionPanel, ...
            'Style', 'text', ...
            'String', 'Waiting to start...', ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'ForegroundColor', [1 1 1], ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'Position', [10 10 instructionPanel.Position(3)*figWidth-20 instructionPanel.Position(4)*figHeight-30]);
        
        % Create progress text
        progressText = uicontrol('Parent', progressPanel, ...
            'Style', 'text', ...
            'String', '', ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'ForegroundColor', [0 1 0], ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'Position', [10 10 progressPanel.Position(3)*figWidth-20 progressPanel.Position(4)*figHeight-30]);
        
        % Create buttons
        cancelButton = uicontrol('Parent', buttonPanel, ...
            'Style', 'pushbutton', ...
            'String', 'Cancel', ...
            'FontSize', 12, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [0.8 0 0], ...
            'ForegroundColor', [1 1 1], ...
            'Position', [20 buttonPanel.Position(4)*figHeight/2-20 160 40], ...
            'Callback', @cancelCallback);
        
        resetButton = uicontrol('Parent', buttonPanel, ...
            'Style', 'pushbutton', ...
            'String', 'Reset', ...
            'FontSize', 12, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [0 0.6 0.8], ...
            'ForegroundColor', [1 1 1], ...
            'Position', [200 buttonPanel.Position(4)*figHeight/2-20 160 40], ...
            'Callback', @resetCallback);
        
        % Store handles for later access
        setappdata(controlFigHandle, 'instructionText', instructionText);
        setappdata(controlFigHandle, 'progressText', progressText);
    end
    
    % Handle control figure close request
    function handleControlFigClose(~, ~)
        isCanceled = true;
        cleanupAndExit();
    end
    
    % Cancel button callback
    function cancelCallback(src, ~)
        isCanceled = true;
        Ax_resized = [];
        
        % Update instruction text only - no button color changes
        figure(controlFigHandle);
        updateInstructionText(controlFigHandle, 'Canceling alignment process...');
    end
    
    % Reset button callback
    function resetCallback(src, ~)
        needsReset = true;
        
        % Update instruction text only - no button color changes
        figure(controlFigHandle);
        updateInstructionText(controlFigHandle, 'Resetting point selection...');
    end
    
    % Update instruction text
    function updateInstructionText(figHandle, newText)
        instructionText = getappdata(figHandle, 'instructionText');
        set(instructionText, 'String', newText);
        drawnow;
    end
    
    % Update point counter
    function updatePointCounter(figHandle, currentPoint, totalPoints, pointType)
        progressText = getappdata(figHandle, 'progressText');
        if strcmp(pointType, 'source')
            pointTypeStr = 'Source';
        else
            pointTypeStr = 'Destination';
        end
        set(progressText, 'String', sprintf('%s Points: %d of %d', pointTypeStr, currentPoint, totalPoints));
        drawnow;
    end
end

% Custom ginput function that checks for figure closure
function [x, y] = customGinput(fig, n)
    % Access global control variables
    global isCanceled needsReset;
    
    % Check if figure is still valid
    if ~ishandle(fig)
        x = [];
        y = [];
        return;
    end
    
    % Set up timer to check for cancel/reset
    timerObj = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.1, ...
                    'TimerFcn', @checkCancelReset);
    start(timerObj);
    
    % Store original button down function
    origButtonDownFcn = get(fig, 'WindowButtonDownFcn');
    
    % Set a button down function that will be used to detect clicks
    hasInput = false;
    inputX = [];
    inputY = [];
    set(fig, 'WindowButtonDownFcn', @buttonDownCallback);
    
    % Wait for input or cancel/reset
    while ~hasInput && ishandle(fig) && ~isCanceled && ~needsReset
        drawnow;
        pause(0.05);
    end
    
    % Stop and delete timer
    try
        stop(timerObj);
        delete(timerObj);
    catch
        % Timer might already be deleted
    end
    
    % Restore original button down function if figure still exists
    if ishandle(fig)
        set(fig, 'WindowButtonDownFcn', origButtonDownFcn);
    end
    
    % Return coordinates
    x = inputX;
    y = inputY;
    
    % Button down callback
    function buttonDownCallback(~, ~)
        % Get current point
        currentPoint = get(gca, 'CurrentPoint');
        inputX = currentPoint(1, 1);
        inputY = currentPoint(1, 2);
        hasInput = true;
    end
    
    % Timer callback to check for cancel/reset
    function checkCancelReset(~, ~)
        if ~ishandle(fig) || isCanceled || needsReset
            try
                stop(timerObj);
                delete(timerObj);
            catch
                % Timer might already be deleted
            end
        end
    end
end


%% Helper Functions

function overlay = createOverlay(Back, Ax_transformed, alphaValue)
    overlay = Back;
    numChannels = size(Ax_transformed, 3);

    if isnan(alphaValue)
        if numChannels == 1
            if islogical(Ax_transformed) || max(Ax_transformed(:)) <= 1
                overlay(:,:,1) = overlay(:,:,1) + uint8(Ax_transformed * 255);
            else
                overlay(:,:,1) = overlay(:,:,1) + uint8(Ax_transformed);
            end
        else
            mask = any(Ax_transformed, 3);
            for c = 1:3
                axChannel = Ax_transformed(:,:,c);
                if isfloat(axChannel) && max(axChannel(:)) <= 1
                    axChannel = uint8(axChannel * 255);
                else
                    axChannel = uint8(axChannel);
                end
                overlay(:,:,c) = overlay(:,:,c) .* uint8(~mask) + axChannel .* uint8(mask);
            end
        end
    else
        if numChannels == 1
            if islogical(Ax_transformed) || max(Ax_transformed(:)) <= 1
                blended = (1 - alphaValue) * double(Back(:,:,1)) + alphaValue * double(Ax_transformed) * 255;
            else
                blended = (1 - alphaValue) * double(Back(:,:,1)) + alphaValue * double(Ax_transformed);
            end
            overlay(:,:,1) = uint8(blended);
            overlay(:,:,2:3) = uint8((1 - alphaValue) * double(Back(:,:,2:3)));
        else
            for c = 1:3
                axChannel = Ax_transformed(:,:,c);
                if isfloat(axChannel) && max(axChannel(:)) <= 1
                    axChannel = axChannel * 255;
                end
                blended = (1 - alphaValue) * double(Back(:,:,c)) + alphaValue * double(axChannel);
                overlay(:,:,c) = uint8(blended);
            end
        end
    end
end