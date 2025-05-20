function applyParameters(newBack, newAx, monitorPositions, monitornumber, alphaValue,mainFig)
    % Load the exported parameters
    % load('overlayParameters.mat', 'parameters');
        parameters = getappdata(mainFig, 'parameters');

    % Ensure there is a second monitor
    if size(monitorPositions, 1) >= 2
        secondMonitor = monitorPositions(monitornumber, :);
        monitorWidth = secondMonitor(3);
        monitorHeight = secondMonitor(4);

        % % Resize newBack to match the projector's resolution
        % if size(newBack, 1) ~= monitorHeight || size(newBack, 2) ~= monitorWidth
        %     newBack = imresize(newBack, [monitorHeight, monitorWidth]);
        % end

        % Create a full-screen figure on the target monitor
        displayFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', ...
            'Color', 'black', 'Units', 'pixels', 'Position', secondMonitor, ...
            'WindowStyle', 'normal', 'Name', 'Projection Adjustment_2', ...
            'WindowState', 'fullscreen'); % Force full screen

        % Calculate initial transformation parameters
        W = size(newBack, 2);  % Background width
        H = size(newBack, 1);  % Background height

        % Process newAx through transformation pipeline using exported parameters
        Ax_resized = imresize(newAx, 1);
        rotatedAx = imrotate(Ax_resized, parameters.RotationAngle, 'bilinear', 'crop');

        % Define input/output corners for initial projection
        inputCorners = [1, 1; size(rotatedAx, 2), 1; 1, size(rotatedAx, 1); size(rotatedAx, 2), size(rotatedAx, 1)];
        outputCorners = [parameters.TopLeftX + parameters.ShiftX, parameters.TopLeftY + parameters.ShiftY; ...
                         parameters.TopRightX + parameters.ShiftX, parameters.TopRightY + parameters.ShiftY; ...
                         parameters.BottomLeftX + parameters.ShiftX, parameters.BottomLeftY + parameters.ShiftY; ...
                         parameters.BottomRightX + parameters.ShiftX, parameters.BottomRightY + parameters.ShiftY];

        tform = fitgeotrans(inputCorners, outputCorners, 'projective');
        Ax_transformed = imwarp(rotatedAx, tform, 'OutputView', imref2d([H, W]));

        % Create initial overlay
        overlay = newBack;
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
                    blended = (1 - alphaValue) * double(newBack(:,:,1)) + alphaValue * double(Ax_transformed) * 255;
                else
                    blended = (1 - alphaValue) * double(newBack(:,:,1)) + alphaValue * double(Ax_transformed);
                end
                overlay(:,:,1) = uint8(blended);
                overlay(:,:,2:3) = uint8((1 - alphaValue) * double(newBack(:,:,2:3)));
            else
                % Handle RGB
                for c = 1:3
                    axChannel = Ax_transformed(:,:,c);
                    if isfloat(axChannel) && max(axChannel(:)) <= 1
                        axChannel = axChannel * 255;
                    end
                    blended = (1 - alphaValue) * double(newBack(:,:,c)) + alphaValue * double(axChannel);
                    overlay(:,:,c) = uint8(blended);
                end
            end
        end

        % Display the final image with overlay
        hImage = imshow(overlay, 'Border', 'tight');
        axis off;
        set(displayFig, 'Position', secondMonitor);

    else
        warndlg('Projector not detected.', 'Monitor Error');
        return;
    end
end