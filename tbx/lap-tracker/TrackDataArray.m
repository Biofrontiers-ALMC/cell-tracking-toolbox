classdef TrackDataArray
    %TRACKDATAARRAY  Data class to hold data for multiple tracks
    
    properties (Access = private)
        
        Tracks  %Array of TrackData objects
        Timestamps
        TimestampUnit
        PxLength
        PxLengthUnit
        
    end
    
    properties (Constant, Hidden)
        
        CreatedOn = datestr(now); %Timestamp when object was created
        
    end
    
    properties (Dependent)
        
        NumTracks
        NumFrames
        MeanDeltaT
        
    end
    
    methods
        
        function numTracks = get.NumTracks(obj)
            
            numTracks = numel(obj.Tracks);
            
        end
        
        function numFrames = get.NumFrames(obj)
            
            firstFrame = min([obj.Tracks.FirstFrame]);
            
            lastFrame = max([obj.Tracks.FirstFrame]);
            
            numFrames = lastFrame - firstFrame + 1;
            
        end
        
        function meanDeltaT = get.MeanDeltaT(obj)
            %Returns the mean time between frames
            
            if ~isempty(obj.Timestamps)
                meanDeltaT = mean(diff(obj.Timestamps));
            else
                meanDeltaT = [];
            end
            
        end
        
        function [obj, newTrackId] = addTrack(obj, frameIndex, trackData)
            %ADDTRACK  Add a track to the array
            %
            %  A.ADDTRACK(frameIndex, data) will add a new TrackData
            %  object, initializing it so it starts at the frame index
            %  and with the data specified. ''data'' should be a struct.
            
            if isempty(obj.Tracks)
                newTrackId = 1;
                obj.Tracks = TrackData(frameIndex,trackData);
                obj.Tracks(1).ID = newTrackId;
                
            else
                newTrackId = numel(obj) + 1;
                obj.Tracks(newTrackId) = TrackData(frameIndex,trackData);
                obj.Tracks(newTrackId).ID = newTrackId;
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
%             else
%                 obj.Tracks(trackIndex) = obj.Tracks(trackIndex).updateFrame(frameIndex, trackData);
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
        
        function obj = setTimestampInfo(obj, tsIn, varargin)
            %SETTIMESTAMPINFO  Set timestamp information
            %
            %  A = A.SETTIMESTAMPS(V) where V is a 1xN vector will set the
            %  timestamp information to V. N must be equal to the number of
            %  frames in the array.
            %
            %  A = A.SETTIMESTAMPINFO(T) where T is a number will set the
            %  timestamp to (1:N) * T, i.e. T should be the time between
            %  frames.
            
            if nargin == 1
                %No timestamp units provided. Assume seconds.
                tsUnits = 's';
            else
                tsUnits = varargin{1};
            end
            
            if numel(tsIn) == obj.NumFrames
                
                obj.Timestamps = tsIn;
                
            elseif numel(tsIn) == 1
                
                obj.Timestamps = (1:obj.NumFrames) * tsIn;
                
            else
                
                error('TrackDataArray:setTimestamps:UnexpectedInputLength',...
                    'Expected number of timestamps to match the number of frames (%d) or be equal to 1 to specify time between frames.',...
                    obj.NumFrames);
                
            end
            
            obj.TimestampUnit = tsUnits;            
            
        end
        
        function [ts, tsUnits] = getTimestampInfo(obj)
            %GETTIMESTAMPINFO  Get timestamp information
            %
            %  [T, U] = A.GETTIMESTAMPINFO will return timestamps as vector
            %  T and units as string U.
            
            ts = obj.Timestamps;
            tsUnits = obj.TimestampUnit;
            
        end
        
        function obj = setPxLengthInfo(obj, pxLength, varargin)
            
            obj.PxLength = pxLength;
            
            if ~isempty(varargin)
                obj.PxLengthUnit = varargin{1};                
            end
            
        end
        
        function [pxLength, pxUnits] = getPxLengthInfo(obj)
            %GETPXLENGTHINFO  Get pixel length information
            %
            %  [L, U] = A.GETPXLENGTHINFO returns the length of each image
            %  pixel L in physical units U.
            
            pxLength = obj.PxLength;
            pxUnits = obj.PxLengthUnit;
            
        end
        
    end
    
end