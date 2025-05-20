function Ax_resized = AdvancedAdjustment(Back, Ax, monitorPositions, monitornumber, alphaValue, defaultResizeFactor,mainFig)

% Ensure there is a second monitor
if size(monitorPositions, 1) >= 2
    secondMonitor = monitorPositions(monitornumber, :);
    monitorWidth = secondMonitor(3);
    monitorHeight = secondMonitor(4);

    % % Resize Back to match the projector's resolution
    % if size(Back, 1) ~= monitorHeight || size(Back, 2) ~= monitorWidth
    %     Back = imresize(Back, [monitorHeight, monitorWidth]);
    % end

    % Create a full-screen figure on the target monitor
    displayFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', ...
        'Color', 'black', 'Units', 'pixels', 'Position', secondMonitor, ...
        'WindowStyle', 'normal', 'Name', 'Projection Adjustment', ...
        'WindowState', 'fullscreen'); % Force full screen
    
    W = size(Back, 2);
    H = size(Back, 1);
    scaledW = W * defaultResizeFactor;
    scaledH = H * defaultResizeFactor;
    startX = round((W - scaledW)/2);
    startY = round((H - scaledH)/2);
    endX = startX + scaledW;
    endY = startY + scaledH;

    % if exist('overlayParameters.mat', 'file')
    if isappdata(mainFig, 'parameters')
        % loaded = load('overlayParameters.mat');
            parameters = getappdata(mainFig, 'parameters');
        % parameters = loaded.parameters;
        % Validate loaded parameters against current Back dimensions
        % if parameters.TopRightX > W || parameters.BottomRightY > H
        %     warndlg('Loaded parameters incompatible with current Background image - using defaults', 'Warning');
        %     return
        % else
            defaultValues = [parameters.TopLeftX, parameters.TopLeftY, ...
                parameters.TopRightX, parameters.TopRightY, ...
                parameters.BottomLeftX, parameters.BottomLeftY, ...
                parameters.BottomRightX, parameters.BottomRightY, ...
                parameters.ShiftX, parameters.ShiftY, parameters.RotationAngle];
        % end
    else

        defaultValues = [startX, startY, endX, startY, startX, endY, endX, endY, 0, 0, 0];
    end

    % Process Ax through transformation pipeline using DEFAULTS
    Ax_resized = imresize(Ax, defaultResizeFactor);
    rotatedAx = imrotate(Ax_resized, 0, 'bilinear', 'crop');

    % Define input/output corners for initial projection
    inputCorners = [1, 1; size(rotatedAx, 2), 1; 1, size(rotatedAx, 1); size(rotatedAx, 2), size(rotatedAx, 1)];
    outputCorners = [defaultValues(1), defaultValues(2); ...  % TopLeft
        defaultValues(3), defaultValues(4); ...  % TopRight
        defaultValues(5), defaultValues(6); ...  % BottomLeft
        defaultValues(7), defaultValues(8)];     % BottomRight

    % Create transformed overlay
    tform = fitgeotrans(inputCorners, outputCorners, 'projective');
    Ax_transformed = imwarp(rotatedAx, tform, 'OutputView', imref2d([H, W]));

    % Create initial overlay
    overlay = Back;
    numChannels = size(Ax_transformed, 3);
    if isnan(alphaValue)
        if numChannels == 1
            % Handle binary/grayscale
            if islogical(Ax_transformed) || max(Ax_transformed(:)) <= 1
                overlay(:,:,1) = overlay(:,:,1) + uint8(Ax_transformed * 255);
            else
                overlay(:,:,1) = overlay(:,:,1) + uint8(Ax_transformed);
            end
        else
            % Handle RGB
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
            % Handle binary/grayscale
            if islogical(Ax_transformed) || max(Ax_transformed(:)) <= 1
                blended = (1 - alphaValue) * double(Back(:,:,1)) + alphaValue * double(Ax_transformed) * 255;
            else
                blended = (1 - alphaValue) * double(Back(:,:,1)) + alphaValue * double(Ax_transformed);
            end
            overlay(:,:,1) = uint8(blended);
            overlay(:,:,2:3) = uint8((1 - alphaValue) * double(Back(:,:,2:3)));
        else
            % Handle RGB
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

    % Display the final image with overlay
    hImage = imshow(overlay, 'Border', 'tight');
    axis off;
    set(displayFig, 'Position', secondMonitor);

    % Create UI Controls in a separate figure
    controlFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', ...
        'Color', 'black', 'Units', 'pixels', 'Position', [900, 100, 500, 600], ...
        'WindowStyle', 'normal', 'Name', 'Overlay Controls');

    % Slider Definitions
    sliders = struct();
    displays = struct();
    sliderNames = {"TopLeftX", "TopLeftY", "TopRightX", "TopRightY", ...
        "BottomLeftX", "BottomLeftY", "BottomRightX", "BottomRightY", ...
        "ShiftX", "ShiftY", "RotationAngle"};

    minValues = [-size(Back,2), -size(Back,1), -size(Back,2), -size(Back,1), ...
        -size(Back,2), -size(Back,1), -size(Back,2), -size(Back,1), ...
        -size(Back,2), -size(Back,1), -180];
    maxValues = [size(Back,2), size(Back,1), 2*size(Back,2), size(Back,1), ...
        size(Back,2), 2*size(Back,1), 2*size(Back,2), 2*size(Back,1), ...
        size(Back,2), size(Back,1), 180];
    stepSizes = (maxValues - minValues) * 0.0001;
    largeSteps = (maxValues - minValues) * 0.001;

    % Create sliders and display boxes
    sliderMargin = 20;
    for i = 1:length(sliderNames)
        uicontrol('Style', 'text', 'String', sliderNames{i}, 'Position', [sliderMargin 550-40*i 150 30], ...
            'ForegroundColor', 'w', 'BackgroundColor', 'black', 'FontSize', 12, 'HorizontalAlignment', 'left');
        sliders.(sliderNames{i}) = uicontrol('Style', 'slider', 'Min', minValues(i), 'Max', maxValues(i), ...
            'Value', defaultValues(i), 'Position', [170 550-40*i 180 30], ...
            'BackgroundColor', [0.8, 0.8, 0.8], 'FontSize', 12, ...
            'SliderStep', [stepSizes(i)/(maxValues(i)-minValues(i)), largeSteps(i)/(maxValues(i)-minValues(i))]);
        displays.(sliderNames{i}) = uicontrol('Style', 'edit', ...
            'String', num2str(defaultValues(i), '%.2f'), ...
            'Position', [360 550-40*i 70 30], ...
            'BackgroundColor', 'white', 'FontSize', 10, ...
            'Enable', 'inactive', 'HorizontalAlignment', 'center');
        uicontrol('Style', 'text', 'String', '-', 'Position', [150 550-40*i 20 30], 'ForegroundColor', 'white', ...
            'BackgroundColor', 'black', 'FontSize', 14, 'HorizontalAlignment', 'center');
        uicontrol('Style', 'text', 'String', '+', 'Position', [350 550-40*i 20 30], 'ForegroundColor', 'white', ...
            'BackgroundColor', 'black', 'FontSize', 14, 'HorizontalAlignment', 'center');
        addlistener(sliders.(sliderNames{i}), 'ContinuousValueChange', @(src, event) updateOverlay(controlFig));
    end

    % Reset Button
    resetButton = uicontrol('Style', 'pushbutton', 'String', 'Reset', 'Position', [260 20 120 40], ...
        'BackgroundColor', [0.6, 0.6, 0.6], 'FontSize', 14, 'Callback', @(src, event) resetOverlay(controlFig, true));
    ExportButton = uicontrol('Style', 'pushbutton', 'String', 'Set Pattern', 'Position', [100 20 120 40], ...
        'BackgroundColor', [0.8, 0.8, 0.8], 'FontSize', 14, 'Callback', @(src, event) SetPattern(controlFig));

    % Add draggable markers to displayFig
    axesHandle = gca(displayFig);
    hold(axesHandle, 'on');
    cornersX = [sliders.TopLeftX.Value, sliders.TopRightX.Value, ...
        sliders.BottomLeftX.Value, sliders.BottomRightX.Value];
    cornersY = [sliders.TopLeftY.Value, sliders.TopRightY.Value, ...
        sliders.BottomLeftY.Value, sliders.BottomRightY.Value];
    markerHandles = gobjects(4,1);
    for i = 1:4
        markerHandles(i) = plot(axesHandle, cornersX(i), cornersY(i), 'wo', 'MarkerSize', 15, 'LineWidth', 3,'MarkerFaceColor', 'b');
        set(markerHandles(i), 'ButtonDownFcn', {@startDrag, i});
    end
    hold(axesHandle, 'off');

    % Store application data
    setappdata(displayFig, 'markerHandles', markerHandles);
    setappdata(displayFig, 'controlFig', controlFig);
    guidata(controlFig, struct(...
        'Back', Back, 'Ax', Ax, 'hImage', hImage, ...
        'sliders', sliders, 'displays', displays, 'resetButton', resetButton, ...
        'displayFig', displayFig, ...
        'startX', startX, 'startY', startY, 'endX', endX, 'endY', endY, ...
        'defaultResizeFactor', defaultResizeFactor));

else
    warndlg('Projector not detected.', 'Monitor Error');
    return;
end

%% Nested functions for updates, reset, and export
    function updateOverlay(controlFig)
        data = guidata(controlFig);
        Back = data.Back;
        Ax = data.Ax;
        hImage = data.hImage;
        sliders = data.sliders;
        displays = data.displays;
        displayFig = data.displayFig;

        resizeFactor = data.defaultResizeFactor;
        shiftX = sliders.ShiftX.Value;
        shiftY = sliders.ShiftY.Value;
        rotationAngle = sliders.RotationAngle.Value;

        for i = 1:length(fieldnames(sliders))
            currentValue = sliders.(sliderNames{i}).Value;
            set(displays.(sliderNames{i}), 'String', sprintf('%.2f', currentValue));
        end

        Ax_resized = imresize(Ax, resizeFactor);
        rotatedAx = imrotate(Ax_resized, rotationAngle, 'bilinear', 'crop');

        inputCorners = [1, 1; size(rotatedAx, 2), 1; 1, size(rotatedAx, 1); size(rotatedAx, 2), size(rotatedAx, 1)];
        outputCorners = [sliders.TopLeftX.Value + shiftX, sliders.TopLeftY.Value + shiftY; ...
            sliders.TopRightX.Value + shiftX, sliders.TopRightY.Value + shiftY; ...
            sliders.BottomLeftX.Value + shiftX, sliders.BottomLeftY.Value + shiftY; ...
            sliders.BottomRightX.Value + shiftX, sliders.BottomRightY.Value + shiftY];

        tform = fitgeotrans(inputCorners, outputCorners, 'projective');
        Ax_transformed = imwarp(rotatedAx, tform, 'OutputView', imref2d([H, W]));

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

        set(hImage, 'CData', overlay);

        if ishandle(displayFig)
            markerHandles = getappdata(displayFig, 'markerHandles');
            if ~isempty(markerHandles) && all(isvalid(markerHandles))
                cornersX = [sliders.TopLeftX.Value + shiftX, sliders.TopRightX.Value + shiftX, ...
                    sliders.BottomLeftX.Value + shiftX, sliders.BottomRightX.Value + shiftX];
                cornersY = [sliders.TopLeftY.Value + shiftY, sliders.TopRightY.Value + shiftY, ...
                    sliders.BottomLeftY.Value + shiftY, sliders.BottomRightY.Value + shiftY];
                for i = 1:4
                    set(markerHandles(i), 'XData', cornersX(i), 'YData', cornersY(i));
                end
            end
        end
    end

    function SetPattern(controlFig)
        data = guidata(controlFig);
        sliders = data.sliders;

        parameters.TopLeftX = sliders.TopLeftX.Value;
        parameters.TopLeftY = sliders.TopLeftY.Value;
        parameters.TopRightX = sliders.TopRightX.Value;
        parameters.TopRightY = sliders.TopRightY.Value;
        parameters.BottomLeftX = sliders.BottomLeftX.Value;
        parameters.BottomLeftY = sliders.BottomLeftY.Value;
        parameters.BottomRightX = sliders.BottomRightX.Value;
        parameters.BottomRightY = sliders.BottomRightY.Value;
        parameters.ShiftX = sliders.ShiftX.Value;
        parameters.ShiftY = sliders.ShiftY.Value;
        parameters.RotationAngle = sliders.RotationAngle.Value;

        % save('overlayParameters.mat', 'parameters');
            setappdata(mainFig, 'parameters', parameters);


        FIG = findobj('Type', 'figure', 'Name', 'Overlay Controls');
        FIG1 = findobj('Type', 'figure', 'Name', 'Projection Adjustment');
        FIG2 = findobj('Type', 'figure', 'Name', 'Projection Adjustment_2');
        if ~isempty(FIG) || ~isempty(FIG1) || ~isempty(FIG2)
            close(FIG);
            close(FIG1);
            close(FIG2);
        end
    end

    function resetOverlay(controlFig, hardReset)
        data = guidata(controlFig);
        sliders = data.sliders;

        % Always use fundamental defaults from Back image and resize factor
        W = size(data.Back, 2);
        H = size(data.Back, 1);
        scaledW = W * data.defaultResizeFactor;
        scaledH = H * data.defaultResizeFactor;
        startX = round((W - scaledW)/2);
        startY = round((H - scaledH)/2);
        endX = startX + scaledW;
        endY = startY + scaledH;

        defaultValues = [...
            startX, startY, ...       % Top-left
            endX, startY, ...         % Top-right
            startX, endY, ...         % Bottom-left
            endX, endY, ...           % Bottom-right
            0, 0, 0 ...               % Shifts & rotation
            ];

        % Update sliders
        sliderNames = fieldnames(sliders);
        for i = 1:length(sliderNames)
            set(sliders.(sliderNames{i}), 'Value', defaultValues(i));
        end

        % Force immediate update
        updateOverlay(controlFig);

        % Clear persistent shifts if hard reset requested
        if hardReset
            % Reset transformation pipeline
            Ax_resized = imresize(data.Ax, data.defaultResizeFactor);
            rotatedAx = imrotate(Ax_resized, 0, 'bilinear', 'crop');
            guidata(controlFig, setfield(guidata(controlFig), 'Ax', rotatedAx));
        end
    end

    function startDrag(src, ~, cornerIndex)
        displayFig = ancestor(src, 'figure');
        controlFig = getappdata(displayFig, 'controlFig');
        data = guidata(controlFig);
        data.draggingCorner = cornerIndex;
        guidata(controlFig, data);
        set(displayFig, 'WindowButtonMotionFcn', @dragging);
        set(displayFig, 'WindowButtonUpFcn', @stopDrag);
    end

    function dragging(src, ~)
        displayFig = src;
        controlFig = getappdata(displayFig, 'controlFig');
        data = guidata(controlFig);
        cornerIndex = data.draggingCorner;
        currentPoint = get(gca(displayFig), 'CurrentPoint');
        x = currentPoint(1,1);
        y = currentPoint(1,2);
        switch cornerIndex
            case 1
                data.sliders.TopLeftX.Value = x - data.sliders.ShiftX.Value;
                data.sliders.TopLeftY.Value = y - data.sliders.ShiftY.Value;
            case 2
                data.sliders.TopRightX.Value = x - data.sliders.ShiftX.Value;
                data.sliders.TopRightY.Value = y - data.sliders.ShiftY.Value;
            case 3
                data.sliders.BottomLeftX.Value = x - data.sliders.ShiftX.Value;
                data.sliders.BottomLeftY.Value = y - data.sliders.ShiftY.Value;
            case 4
                data.sliders.BottomRightX.Value = x - data.sliders.ShiftX.Value;
                data.sliders.BottomRightY.Value = y - data.sliders.ShiftY.Value;
        end
        guidata(controlFig, data);
        updateOverlay(controlFig);
    end

    function stopDrag(src, ~)
        displayFig = src;
        controlFig = getappdata(displayFig, 'controlFig');
        data = guidata(controlFig);
        data.draggingCorner = [];
        guidata(controlFig, data);
        set(displayFig, 'WindowButtonMotionFcn', '');
        set(displayFig, 'WindowButtonUpFcn', '');
    end

end