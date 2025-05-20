function applyParameters2video(newBack, videoPath, monitorPositions, monitornumber, alphaValue, mainFig)
    % Load parameters
    parameters = getappdata(mainFig, 'parameters');
    matlab.video.read.UseHardwareAcceleration('off');

    % Check for second monitor
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

    % Create figure with unique Tag and CloseRequestFcn
    displayFig = figure('MenuBar', 'none', 'ToolBar', 'none', ...
        'Color', 'black', 'Units', 'pixels', 'Position', secondMonitor, ...
        'WindowStyle', 'normal', 'Name', 'Projection Adjustment_2', ...
        'Tag', 'ProjectionAdjustment2', ...
        'WindowState', 'fullscreen', ...
        'CloseRequestFcn', @(src,~) deleteFig(src));

    % Initialize display and video
    hImage = imshow(newBack, 'Border', 'tight', 'InitialMagnification', 'fit');
    axis off;
    videoReader = VideoReader(videoPath);
    setappdata(displayFig, 'stopFlag', false);

    % Main loop with video reset on end
    while ishandle(displayFig) && ~getappdata(displayFig, 'stopFlag')
        if hasFrame(videoReader)
            % Read and process frame
            videoFrame = readFrame(videoReader);
            videoFrame = imresize(videoFrame, [size(newBack,1), size(newBack,2)]);

            % Apply transformations (your existing code)
            rotatedFrame = imrotate(videoFrame, parameters.RotationAngle, 'bilinear', 'crop');
            inputCorners = [1,1; size(rotatedFrame,2),1; 1,size(rotatedFrame,1); size(rotatedFrame,2),size(rotatedFrame,1)];
            outputCorners = [parameters.TopLeftX+parameters.ShiftX, parameters.TopLeftY+parameters.ShiftY; 
                            parameters.TopRightX+parameters.ShiftX, parameters.TopRightY+parameters.ShiftY; 
                            parameters.BottomLeftX+parameters.ShiftX, parameters.BottomLeftY+parameters.ShiftY; 
                            parameters.BottomRightX+parameters.ShiftX, parameters.BottomRightY+parameters.ShiftY];
            tform = fitgeotrans(inputCorners, outputCorners, 'projective');
            transformedFrame = imwarp(rotatedFrame, tform, 'OutputView', imref2d(size(newBack,[1 2])));

            % Overlay logic (your existing code)
            overlay = newBack;
            if isnan(alphaValue)
                mask = any(transformedFrame, 3);
                for c = 1:3
                    frameChannel = transformedFrame(:,:,min(c, size(transformedFrame,3)));
                    if isfloat(frameChannel) && max(frameChannel(:)) <= 1
                        frameChannel = uint8(frameChannel * 255);
                    end
                    overlay(:,:,c) = overlay(:,:,c) .* uint8(~mask) + frameChannel .* uint8(mask);
                end
            else
                for c = 1:3
                    frameChannel = transformedFrame(:,:,min(c, size(transformedFrame,3)));
                    if isfloat(frameChannel) && max(frameChannel(:)) <= 1
                        frameChannel = frameChannel * 255;
                    end
                    overlay(:,:,c) = (1-alphaValue)*double(newBack(:,:,c)) + alphaValue*double(frameChannel);
                end
                overlay = uint8(overlay);
            end

            % Update display
            set(hImage, 'CData', overlay);
            drawnow limitrate;
            pause(1/videoReader.FrameRate);
        else
            % Reset video to the beginning when it ends
            videoReader.currentTime = 0;
        end
    end

    % Cleanup
    if ishandle(displayFig)
        close(displayFig);
    end
end

% CloseRequestFcn helper
function deleteFig(src)
    setappdata(src, 'stopFlag', true); % Set flag first
    delete(src); % Delete figure afterward
end