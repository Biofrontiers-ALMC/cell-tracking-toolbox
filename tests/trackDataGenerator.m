classdef trackDataGenerator
    %TRACKDATAGENERATOR  Generates mock track data for testing
    
    properties
        
        numFrames = [50 100];           %Maximum number of frames in a track
        firstFrame = [1 10];
        
    end

    methods
        
        function outputData = generateTracks(obj, numTracks, varargin)
            
            outputData = struct('ID',{},...
                'SeriesID', {}, 'MotherTrackID', {}, 'DaughterTrackID', {},...
                'Frames',{}, ...
                'Data', struct('Centroid', {}, 'Area', {}, 'Intensity', {}));
            
            %--- Generate tracks ---%
            for ii = 1:numTracks
                
                outputData(ii).ID = ii;
                outputData(ii).SeriesID = 1;
                outputData(ii).MotherTrackID = 0;
                outputData(ii).DaughterTrackID = 0;
                
                if numel(obj.numFrames) > 1
                    trackNumFrames = randsample(obj.numFrames,1);
                else
                    trackNumFrames = obj.numFrames;
                end
                
                if numel(obj.firstFrame) > 1
                    trackFirstFrame = randsample(obj.firstFrame(1):obj.firstFrame(2),1);
                else
                    trackFirstFrame = obj.firstFrame;
                end
                
                outputData(ii).Frames = trackFirstFrame:trackFirstFrame + (trackNumFrames - 1);
                
                for iFrame = 1:trackNumFrames
                    outputData(ii).Data(iFrame).Centroid = round(rand(1, 2) * 2048);
                    outputData(ii).Data(iFrame).Area = round(rand(1) * 1000);
                    outputData(ii).Data(iFrame).Intensity = rand(1) * 65535;
                end
            end
            
        end
        
    end
end