function applyParameters2gif(newBack, gifPath, monitorPositions, monitornumber, alphaValue,mainFig)
    % Load transformation parameters
    % load('overlayParameters.mat', 'parameters');
        parameters = getappdata(mainFig, 'parameters');
    
    % Verify projector monitor exists
    if size(monitorPositions, 1) < 2
        warndlg('Projector not detected.', 'Monitor Error');
        return;
    end

    % Configure projector monitor
    secondMonitor = monitorPositions(monitornumber, :);
    monitorHeight = secondMonitor(4);
    monitorWidth = secondMonitor(3);

    % Resize background if needed
    if size(newBack, 1) ~= monitorHeight || size(newBack, 2) ~= monitorWidth
        newBack = imresize(newBack, [monitorHeight, monitorWidth]);
    end

    % ========== GIF-SPECIFIC SETUP ========== %
    % Read all GIF frames and delays
    [gifFrames, ~, gifDelays] = imread(gifPath, 'frames', 'all');
    numFrames = size(gifFrames, 4);
    
    % Convert delays to seconds (GIF delays are in 0.01s units)
    % frameDelays = cat(1, gifDelays(:).DelayTime) / 100; 
    if isstruct(gifDelays) && isfield(gifDelays, 'DelayTime')
        frameDelays = cat(1, gifDelays.DelayTime) / 100;
    else
        frameDelays = ones(numFrames, 1) * 0.1; % Default to 0.1s if delay is not found
    end
    
    % Preprocess frames (resize, convert to RGB)
    processedFrames = cell(numFrames, 1);
    for i = 1:numFrames
        frame = im2uint8(gifFrames(:,:,:,i));
        if size(frame, 3) == 1  % Handle grayscale GIFs
            frame = repmat(frame, [1 1 3]);
        end
        processedFrames{i} = imresize(frame, [size(newBack,1), size(newBack,2)]);
    end
    % ======================================== %

    % Create fullscreen figure with stop controls
    displayFig = figure('MenuBar', 'none', 'ToolBar', 'none', ...
        'Color', 'black', 'Units', 'pixels', 'Position', secondMonitor, ...
        'WindowStyle', 'normal', 'Name', 'Projection Adjustment_2', ...
        'Tag', 'ProjectionAdjustment2', ...
        'WindowState', 'fullscreen', ...
        'KeyPressFcn', @(src,event) setappdata(src, 'stopFlag', true), ...
        'CloseRequestFcn', @(src,~) deleteFig(src));

    % Initialize display
    hImage = imshow(newBack, 'Border', 'tight');
    axis off;
    setappdata(displayFig, 'stopFlag', false);

    % Main animation loop
    currentFrame = 1;
    while ishandle(displayFig) && ~getappdata(displayFig, 'stopFlag')
        % ========== GIF FRAME PROCESSING ========== %
        % Get current frame
        rawFrame = processedFrames{currentFrame};
        
        % Apply transformations (same as video version)
        rotatedFrame = imrotate(rawFrame, parameters.RotationAngle, 'bilinear', 'crop');
        inputCorners = [1,1; size(rotatedFrame,2),1; 
                       1,size(rotatedFrame,1); size(rotatedFrame,2),size(rotatedFrame,1)];
        outputCorners = [parameters.TopLeftX+parameters.ShiftX, parameters.TopLeftY+parameters.ShiftY; 
                        parameters.TopRightX+parameters.ShiftX, parameters.TopRightY+parameters.ShiftY; 
                        parameters.BottomLeftX+parameters.ShiftX, parameters.BottomLeftY+parameters.ShiftY; 
                        parameters.BottomRightX+parameters.ShiftX, parameters.BottomRightY+parameters.ShiftY];
        tform = fitgeotrans(inputCorners, outputCorners, 'projective');
        transformedFrame = imwarp(rotatedFrame, tform, 'OutputView', imref2d(size(newBack,[1 2])));
        % ========================================== %

        % Overlay composition (same as video version)
        overlay = newBack;
        if isnan(alphaValue)
            mask = any(transformedFrame, 3);
            for c = 1:3
                frameChannel = transformedFrame(:,:,min(c, size(transformedFrame,3)));
                overlay(:,:,c) = overlay(:,:,c) .* uint8(~mask) + frameChannel .* uint8(mask);
            end
        else
            for c = 1:3
                frameChannel = transformedFrame(:,:,min(c, size(transformedFrame,3)));
                overlay(:,:,c) = (1-alphaValue)*double(newBack(:,:,c)) + alphaValue*double(frameChannel);
            end
            overlay = uint8(overlay);
        end

        % Update display
        set(hImage, 'CData', overlay);
        drawnow limitrate;

        % ========== GIF TIMING CONTROL ========== %
        % Use GIF frame delay (loop back to start when needed)
        pause(frameDelays(mod(currentFrame-1, numel(frameDelays)) + 1));
        currentFrame = mod(currentFrame, numFrames) + 1;
        % ======================================== %
    end

    % Cleanup
    if ishandle(displayFig)
        close(displayFig);
    end
end

% CloseRequestFcn helper (same as video version)
function deleteFig(src)
    setappdata(src, 'stopFlag', true);
    delete(src);
end