classdef trackarray
    %TRACKARRAY  Container class to hold multiple trackdata objects
    %
        
    properties (Access = private)
        tracks        
        metadata = timedata.trackmetadata;
    end
    
    properties (Dependent)
        
        Tracks
        
        numTracks
        
        numFrames
        firstFrame
        lastFrame
    end
    
    methods
        
        function obj = trackarray(varargin)
            %TRACKARRAY  Object to hold multiple tracks
            %
            %  TA = timedata.trackarray(10) will initialize a trackarray
            %  object with 10 tracks
            
            if nargin == 1
                
                if isnumeric(varargin{1}) && isscalar(varargin{1})
                    %Create an empty array
                    obj.tracks = timedata.trackdata(varargin{1});
                    
                elseif isstruct(varargin{1})
                    obj.tracks = timedata.trackdata.struct2track(varargin{1});
                    
                elseif isa(varargin{1}, 'timedata.trackdata')
                    obj.tracks = varargin{1};                    
                    
                else
                    error('trackarray:InvalidInputType', ...
                        'Expected input to be scalar and numeric, a compatible struct, or a trackdata object.');
                end
                
            elseif nargin > 1
                error('trackarray:TooManyInputs',...
                    'Too many input arguments.'); 
            end
            
        end
        
        function numTracks = get.numTracks(obj)
            numTracks = numel(obj.tracks);
        end
        
        function numFrames = get.numFrames(obj)
            
            if ~isnan(obj.firstFrame)
                numFrames = obj.lastFrame - obj.firstFrame + 1;
            else
                numFrames = 0;
            end
            
        end
        
        function firstFrame = get.firstFrame(obj)
            
            %Find the smallest frame value in the tracks
            trackframes = [obj.tracks.firstFrame];
            trackframes(isinf(trackframes)) = [];
            
            if ~isempty(trackframes)
                firstFrame = min(trackframes);
            else
                firstFrame = NaN;
            end
            
        end
        
        function lastFrame = get.lastFrame(obj)
            %Find the smallest frame value in the tracks
            trackframes = [obj.tracks.lastFrame];
            trackframes(isinf(trackframes)) = [];
            
            if ~isempty(trackframes)
                lastFrame = max(trackframes);
            else
                lastFrame = NaN;
            end
            
        end
        
        
        function [obj, newTrackInd] = addTrack(obj, varargin)
            %ADDTRACK  Add track(s) to the array
            %
            %  OBJ = addTrack(OBJ) will add an empty trackdata object to
            %  the array.
            %
            %  OBJ = ADDTRACK(OBJ, N) will add N empty tracks to the array.
            %
            %  OBJ = ADDTRACK(OBJ, trackObjs) will add the track objects to
            %  the array.
            %
            %  OBJ = ADDTRACK(OBJ, F, data) will add the track to the array
            %  with the data
            
            if isempty(varargin) || (numel(varargin) == 1 && isnumeric(varargin{1}))
                %Create empty tracks
                
                if isempty(varargin)
                    tracksToAdd = timedata.trackdata;
                else
                    tracksToAdd = timedata.trackdata(varargin{1});
                end
                
            elseif numel(varargin) == 1 && isa(varargin{1}, 'timedata.trackdata')
                
                tracksToAdd = varargin{1};
                
            elseif numel(varargin) == 2
                %Frame and regionprops like data
                
                if ~isnumeric(varargin{1}) && ~isscalar(varargin{1})
                    error('trackarray:addTrack:InvalidFrame',...
                        'Expected frame number to be numeric and scalar.');
                end
                
                if ~isstruct(varargin{2})
                    error('trackarray:addTrack:FrameDataNotStruct',...
                        'Expected frame data to be a struct');                    
                end
                
                iFrame = varargin{1};
                numNewTracks = numel(varargin{2});
                
                tracksToAdd = timedata.trackdata(numNewTracks);
                %Make tracks from the data
                for iTrack = 1:numNewTracks
                    tracksToAdd(iTrack) = ...
                        tracksToAdd(iTrack).addFrame(iFrame,varargin{2}(iTrack));                    
                end
                
            else
                error('trackarray:addTrack:InvalidInput',...
                    'Input was invalid.');                
                
            end
            
            %Add the new tracks to the object
            if isempty(obj.tracks)
                obj.tracks = tracksToAdd;
                newTrackInd = 1:numel(obj.tracks);
                
            else                
                lastTrackID = obj.tracks(end).trackID;
                %Modify trackIDs to be sequential
                for ii = 1:numel(tracksToAdd)
                    tracksToAdd(ii).trackID = lastTrackID + ii;
                end
                                
                newTrackInd = (numel(obj.tracks) + 1):(numel(obj.tracks) + numel(tracksToAdd));
                obj.tracks(newTrackInd) = tracksToAdd;                
                
            end
            
        end

        
        function obj = delTrackByID(obj, IDtoDel)
            %DELTRACKBYID  Delete track specified by trackID
            %
            %  OBJ = DELTRACKBYID(OBJ, trackID) will delete the tracks
            %  specified by the trackID(s).
            
            for iObj = 1:numel(obj)
                obj(iObj) = delTrack(obj(iObj), obj(iObj).trackid2ind(IDtoDel));
            end
        end
        
        function obj = delTrack(obj, indToDel, varargin)
            %DELTRACK  Delete track(s) from the array
            %
            %  OBJ = DELTRACK(OBJ, I) will delete track I from the array. I
            %  can be either a vector listing the tracks to delete or a
            %  logical array. If I is logical, it should have the same
            %  number of elements as the number of tracks in the array.
            %
            %  Note: This function only works for single objects, not
            %  object arrays. If you have an object array, index the
            %  trackarray you are trying to delete from. Example: A(5) =
            %  DELTRACK(A(5), I).

            if numel(obj) > 1
                error('trackarray:delTrack:CannotOperateOnObjectArray',...
                    'Cannot run this operation on an object array.');                
            end
            
            if ~isnumeric(indToDel) && ~islogical(indToDel)
                error('trackarray:delTrack:InvalidInput',...
                    'Input should be either numeric or logical.');
            elseif isnumeric(indToDel)
                indices = 1:numel(obj.tracks);
                indToDel = ismember(indices, indToDel);
            end
            
            %Delete the tracks
            obj.tracks = obj.tracks(~indToDel);
            
        end
        
        function obj = delFrame(obj, framesToDel, IDtoDel)
            %DELFRAME  Remove specified frame(s) from all tracks
            %
            %  OBJ = DELFRAME(OBJ, F) will remove frame(s) F from all
            %  tracks in the array.
            %
            %  OBJ = DELFRAME(OBJ, F, I) will remove frame(s) F from the
            %  tracks specified by their ID I.
            
            trackInd = 1:numel(obj.tracks); 
            if nargin == 3
                %Convert to indices
                currIDs = [obj.tracks.trackID];
                trackInd = trackInd(ismember(currIDs, IDtoDel));
            end
            
            obj.tracks(trackInd) = delFrame(obj.tracks(trackInd), framesToDel);
            
        end
                
        
        function trackOut = getTrackByID(obj, ID)
            %GETTRACKBYID  Gets track(s) by track ID
            %
            %  T = GETTRACKBYID(OBJ, I) will return the tracks specified by
            %  their trackID values. If more than one trackID was
            %  specified, T will be an object array.
            
            trackOut = obj.tracks(obj.trackid2ind(ID));
            
        end
                
       
        function obj = setMetadata(obj, varargin)
            %SETMETADATA  Set metadata information
            %
            %  OBJ = SETMETADATA(OBJ, 'property', value, ...) will set the
            %  metadata property to the value specified. User-specified
            %  metadata is supported.
            %
            %  Example:
            %      %Set the filename related to this dataset
            %      OBJ = SETMETADATA(OBJ, 'filename', 'newFile.nd2');
            %
            %      %Create a new user-specified metadata property called
            %      %well location
            %      OBJ = SETMETADATA(OBJ, 'WellLocation', 'A01');
            %
            %  Note that the metadata property names are case-insensitive;
            %  the names are converted to lowercase (i.e. 'WellLocation'
            %  and 'welllocation' will set the same property).
            %   
            %  See also: timedata.trackmetadata, getMetadata
            
            obj.metadata = set(obj.metadata, varargin{:});
            
        end
        
        function mdValue = getMetadata(obj, propName)
            %GETMETADATA  Set metadata information
            %
            %  OBJ = GETMETADATA(OBJ, 'property') will get the
            %  metadata property specified. 
            %
            %  Example:
            %      %Set the filename related to this dataset
            %      OBJ = SETMETADATA(OBJ, 'filename', 'newFile.nd2');
            %
            %      GETMETADATA(OBJ, 'filename');
            %
            %  Note that the metadata property names are case-insensitive;
            %  the names are converted to lowercase (i.e. 'Filename'
            %  and 'filename' will get the same property).
            %
            %  See also: timedata.trackmetadata, setMetadata
            
            mdValue = get(obj.metadata, propName);
            
        end
        
        function tracksOut = get.Tracks(obj)
            
            if ~isempty(obj.tracks)
                
                tracksOut = obj.tracks;
            else
                tracksOut = [];
                
            end
            
        end
        
    end
    
    methods (Hidden)
        
        function indOut = trackid2ind(obj, trackID)
            %TRACKID2IND  Convert trackIDs into indices
            %
            %  IND = TRACKID2IND(OBJ, ID) will find the trackIDs specified
            %  and return the matching indices.
            
            %Convert to indices
            currIDs = [obj.tracks.trackID];
            indices = 1:numel(obj.tracks);
            
            indOut = NaN(1, numel(trackID));
            for ii = 1:numel(trackID)
                indOut(ii) = indices(currIDs == trackID(ii));                                
            end
            
        end
        
    end
    
end