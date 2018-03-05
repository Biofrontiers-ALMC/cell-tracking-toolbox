classdef trackDataGenerator
    %TRACKDATAGENERATOR  Generates mock track data for testing
    
    properties
        
        numFrames = [50 100];           %Maximum number of frames in a track
        firstFrame = [1 10];
        
    end

    methods
        
        function outputData = generateTracks(obj, numTracks, varargin)
            
            outputData = struct('trackID',{},...
                'seriesID', {}, 'motherTrackID', {}, 'daughterTrackIDs', {},...
                'frames',{}, ...
                'data', struct('Centroid', {}, 'Area', {}, 'Intensity', {}));
            
            %--- Generate tracks ---%
            for ii = 1:numTracks
                
                outputData(ii).trackID = ii;
                outputData(ii).seriesID = 1;
                outputData(ii).motherTrackID = 0;
                outputData(ii).daughterTrackIDs = [0 0];
                
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
                
                outputData(ii).frames = trackFirstFrame:trackFirstFrame + (trackNumFrames - 1);
                
                for iFrame = 1:trackNumFrames
                    outputData(ii).data(iFrame).Centroid = round(rand(1, 2) * 2048);
                    outputData(ii).data(iFrame).Area = round(rand(1) * 1000);
                    outputData(ii).data(iFrame).Intensity = rand(1) * 65535;
                end
            end
            
        end
        
    end
end