function script

    % Magic constants
    BRIGHTNESS_THRESHOLD_PERCENT = 10.0;
    VIDEO_FILE_EXTENSION = '.mkv';
    
    CAMERA_NAMES = containers.Map(...
        {'00408CBF7DA1', '00408CA38EF0'}, ...
        {'AccCam'     , 'PlasCam'});
    
    
    % Make the user select a directory
    folder = uigetdir;
    
    % Find the video files in that directory
    videoFiles = getVideoFiles(folder);

    % Loop through all of the video files
    for i = 1:length(videoFiles)
        
        file = fullfile(folder, videoFiles{i});
        fprintf('Scanning file %s ...', videoFiles{i})
        
        % Search the file for arcs
        arcs = findArcs(file);
        fprintf(' DONE!\n');
        
        % Loop through all of the arcs we've found
        for j = 1:length(arcs)
            
            % Construct a filename
            temp = strsplit(videoFiles{i}, '_');
            dateString = temp{1};
            timeString = temp{2};
            
            temp = strsplit(temp{4}, '.');
            cameraName = CAMERA_NAMES(temp{1});
            
            imageFilename = sprintf('%s_%s_Arc%d_%s.png', ...
                dateString, cameraName, j, timeString);
            
            % Save the image
            file = fullfile(folder, imageFilename);
            imwrite(arcs{j}, file);
            fprintf(' -> Arc image saved at file %s\n', imageFilename); 
            
        end
        
        
    end

    function videoFiles = getVideoFiles(folder)
        
        % Init the return value
        videoFiles = {};
        
        % Grab the files in the directory
        files = dir(folder);
        
        % Loop through all of the files
        for i = 1:length(files)
            
            % If it ends in our extension, it's a file we care about
            if contains(files(i).name, VIDEO_FILE_EXTENSION)
                videoFiles{end+1} = files(i).name;
            end            
        end
        
        
    end

    function arcs = findArcs(videoFilename)

        % Init the return value
        arcs = {};

        % Read the video
        video = VideoReader(videoFilename);

        % Booleans we'll use for edge cases
        firstFrame   = true;
        lastFrameArc = false;
        
        % Loop through all of the frames
        while hasFrame(video)

            % Read the frame and calculate it's brightness
            frame = readFrame(video);
            brightness = sum(sum(rgb2gray(frame)));

            % Can't do anything with only 1 frame
            if firstFrame
                firstFrame = false;
                lastBrightness = brightness;
                continue;
            end

            % Calculate the relative change between adjacent frames
            relativeChange = 100*(brightness - lastBrightness) / ...
                mean([brightness lastBrightness]);

            
            % If the change is very large, we've found an arc
            if relativeChange > BRIGHTNESS_THRESHOLD_PERCENT 
                
                if lastFrameArc
                    arcs{end} = combineFrames(arcs{end}, frame);
                else
                    arcs{end+1} = frame;
                end
                
                lastFrameArc = true;
            
            % We only want to overwrite the previous value if there was no arc
            else
                lastFrameArc   = false;
                lastBrightness = brightness;
            end
        end

    end

    function frame = combineFrames(frame1, frame2)
        
        % Find the y-indexes where frame2 is brighter
        index = sum(rgb2gray(frame2), 2) > sum(rgb2gray(frame1), 2);
        
        % Combine the two frames
        frame = frame1;
        frame(index,:,:) = frame2(index,:,:);
        
    end
end


