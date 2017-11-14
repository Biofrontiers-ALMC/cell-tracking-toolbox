classdef TrackDataArray
    %TRACKDATAARRAY  Data class to hold data for multiple tracks
    
    properties (Access = private)
        
        Tracks  %Array of TrackData objects
        
    end
    
    properties (Constant, Hidden)
        
        CreatedOn = datestr(now); %Timestamp when object was created
        
    end
    
    methods
        
        function [obj, newTrackId] = addTrack(obj, frameIndex, trackData)
            %ADDTRACK  Add a track to the array
            %
            %  A.ADDTRACK(frameIndex, data) will add a new TrackData
            %  object, initializing it so it starts at the frame index
            %  and with the data specified. ''data'' should be a struct.
            
            if isempty(obj.Tracks)
                newTrackId = 1;
                obj.Tracks = TrackData(frameIndex,trackData);
                
            else
                newTrackId = numel(obj) + 1;
                obj.Tracks(newTrackId) = TrackData(frameIndex,trackData);
            end
            
        end
        
        function obj = updateTrack(obj, trackIndex, frameIndex, trackData)
            %UPDATETRACK  Update the specified track
            %
            %  A = A.UPDATETRACK(I, F, D) will update track I, frame F,
            %  with the data D.
            
            if trackIndex > numel(obj)
                error('TrackDataArray:updateTrack:InvalidIndex',...
                    'Expected track index to be between 1 and %d.',numel(obj));                
            end
            
            if frameIndex > obj.Tracks(trackIndex).LastFrame || frameIndex < obj.Tracks(trackIndex).FirstFrame
                obj.Tracks(trackIndex) = obj.Tracks(trackIndex).addFrame(frameIndex, trackData);
            else
                obj.Tracks(trackIndex) = obj.Tracks(trackIndex).updateFrame(frameIndex, trackData);
            end
            
        end
        
        function obj = deleteTrack(obj, trackIndex)
            %DELETETRACK  Remove a track
            %
            %  A.DELETETRACK(trackIndex) will remove the TrackData object
            %  at the index specified.
            
            if isempty(obj.Tracks)
                error('TrackDataArray:deleteTrack:ArrayIsEmpty',...
                    'The track data array is empty.');
            else
                obj.Tracks(trackIndex) = [];
            end
            
        end
        
        function trackOut = getTrack(obj, trackIndex)
            %GETTRACK  Get the selected track
            %
            %  T = A.GETTRACK(I) will get the track at index I, returning a
            %  TrackData object to T.
            
            trackOut = obj.Tracks(trackIndex);
            
        end
        
        function obj = deleteFrame(obj, trackIndex, frameIndex)
            
            obj.Tracks(trackIndex) = obj.Tracks(trackIndex).deleteFrame(frameIndex);
            
        end
        
        function obj = updateMotherTrackIdx(obj, trackIndex, motherTrackIdx)
            
            obj.Tracks(trackIndex).MotherIdx = motherTrackIdx;
            
        end
        
        function obj = updateDaughterTrackIdxs(obj, trackIndex, daughterTrackIdxs)
            
            obj.Tracks(trackIndex).DaughterIdxs = daughterTrackIdxs;
            
        end
        
        function numTracks = numel(obj)
            %NUMEL  Count number of TrackData objects in the array 
            
            numTracks = numel(obj.Tracks);
            
        end
        
    end
    
end