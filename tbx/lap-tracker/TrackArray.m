classdef TrackArray
    %TRACKARRAY  Data class representing an array of tracks
    %
    %  TRACKDATAARRAY Properties:
    %     Filename - Filename of the movie this data was created from
    %     FileMetadata - Timestamps, pixel size and image size
    %     CreatedOn - Time and date the object was created on
    %     NumTracks - Number of tracks in array
    %     NumFrames - Length of tracked data in frames
    %     MeanDeltaT - Mean time between frames
    %     TrackedDataFields - Cell list of data fieldnames
    %
    %  TRACKDATAARRAY Methods:
    %     addTrack - Add a track to the array
    %     deleteTrack - Delete track from array
    %     getTrack - Get a specified track
    %     updateTrack - Update specified frames of a track
    %     deleteFrame - Delete frame(s) from a track
    %     renameField - Rename data fields of all tracks in the array
    %
    %
    %  Each track has the following basic structure:
    %    ID
    %    MotherID
    %    DaughterID
    %    Frames
    %    Data
    %
    %  Add traversal algorithms, tree plotting
            
    properties (Access = private)
        
        LastID = 0;  %Last assigned track ID
    end
    
    properties (SetAccess = private)
        
        Tracks    %Struct containing data
        
        Filename = '';
        FileMetadata = struct(...
            'Timestamps', [], ...
            'TimestampUnit', '',...
            'PxSize', [], ...
            'PxSizeUnit', '', ...
            'ImgSize', [NaN, NaN]);
        
    end
    
    properties (Constant)
        
        CreatedOn = datestr(now); %Timestamp when object was created
        
    end
    
    properties (Dependent)
        
        NumTracks
        MeanDeltaT
        TrackedDataFields
        
    end
    
    methods
        
        %--- Get/Set functions
        
        function numTracks = get.NumTracks(obj)
            
            %Return number of tracks (size of Data property)
            numTracks = numel(obj.Tracks);
            
        end
        
        function numTracks = numel(obj)
            %Equal to NumTracks
            
            numTracks = numel(obj.Tracks);
            
        end
        
        %--- Get/set FileMetadata 
        
        function obj = setTimestampInfo(obj, tsIn, varargin)
            %SETTIMESTAMPINFO  Set timestamp information
            %
            %  OBJ = SETTIMESTAMPINFO(OBJ, T) sets the timestamp
            %  information in the FileMetadata property. T can be a vector,
            %  representing the timestamp for each frame. Alternatively, T
            %  can be a single number, representing the time between
            %  frames.
            %
            %  OBJ = SETTIMESTAMPINFO(OBJ, T, UNIT) allows the units to be
            %  specified. By default, a unit of seconds is assumed. This
            %  parameter could affect calculations and plots.

            if isempty(varargin)
                obj.FileMetadata.TimestampUnit = 's';
                
            elseif ischar(varargin{1})
                %!!TODO!! Add enum and checks
                obj.FileMetadata.TimestampUnit = lower(varargin{1});
                
            else
                error('TrackArray:setTimestampInfo:UnitNotString', ...
                    'Expected time unit information to be a string.');
            end
                
            obj.FileMetadata.Timestamps = tsIn;
                         
        end
        
        function [ts, tsUnits] = getTimestampInfo(obj)
            %GETTIMESTAMPINFO  Get timestamp information
            %
            %  [T, U] = A.GETTIMESTAMPINFO will return timestamps as vector
            %  T and units as string U.
            
            ts = obj.FileMetadata.Timestamps;
            tsUnits = obj.FileMetadata.TimestampUnit;
            
        end
                
        function obj = setPxSizeInfo(obj, pxLength, varargin)
            %SETPXSIZEINFO  Set pixel size information
            %
            %  A = A.SETPXSIZEINFO(L) will set the PxSize property of the
            %  FileMetadata to L. 
            %
            %  A = A.SETPXSIZEINFO(L,U) also sets a string U representing
            %  the unit of the property.
            
            obj.FileMetadata.PxSize = pxLength;
            
            if ~isempty(varargin)
                obj.FileMetadata.PxSizeUnit = varargin{1};                
            end
            
        end
        
        function [pxLength, pxUnits] = getPxSizeInfo(obj)
            %GETPXSIZEINFO  Get pixel size information
            %
            %  [L, U] = A.GETPXSIZEINFO returns the length of each image
            %  pixel L in physical units U.
            
            pxLength = obj.FileMetadata.PxSize;
            pxUnits = obj.FileMetadata.PxSizeUnit;
            
        end
        
        function obj = setImgSize(obj, imgSize)
            %SETIMGSIZE  Sets the image size in the file metadata
            %
            %  A = A.SETIMGSIZE([H W]) sets the image size to the height H
            %  and width W.
            
            obj.FileMetadata.ImgSize = imgSize;
            
        end
        
        function obj = setFilename(obj, fn)
            %SETFILENAME  Set filename property
            %
            %  The filename is linked to the dataset that this track data
            %  array was created from.
            %
            %  A = A.SETFILENAME(F) sets the filename to F.
            
            if ~isempty(obj.Filename)
                %Warn if not empty
                
                warning('TrackDataArray:setFilename:FilenameAlreadyExists',...
                    'The filename property is already set. Are you sure you want to change it?');
                s = input('Change filename (Y = change, anything else will cancel)? ','s');
                
                if ~strcmpi(s,'y')
                    return;
                end
            end
            
            obj.Filename = fn;
            
        end
        
        
        % --- To change ---%
        function meanDeltaT = get.MeanDeltaT(obj)
            %Returns the mean time between frames
            
            if ~isempty(obj.FileMetadata.Timestamps)
                meanDeltaT = mean(diff(obj.FileMetadata.Timestamps));
            else
                meanDeltaT = [];
            end
            
        end
        
        function dataFieldnames = get.TrackedDataFields(obj)
            
            dataFieldnames = obj.getTrack(1).TrackDataProps;
            
        end
        
        
        %--- Track functions
        % Notes:
        %  * Tracks are stored as a struct array in the 'Tracks' property
        %
        %  * All tracks must have the following fields:
        %      - ID: Unique, cannot be changed
        %      - MotherID: ID of mother track
        %      - DaughterID: ID of daughter tracks
        %      - Frames: Vector of frame numbers (sorted), cannot be
        %                changed by user
        %      - Data: A struct containing experimental data. Each field 
        %              is stored as a cell array, with a single cell per
        %              frame.
        %
        %  * Track data is stored in cells, where each cell corresponds to
        %    the data from a single frame. For example, the following shows
        %    a valid example:
        %        obj.Tracks(1).Frames = [1 3 4 5];
        %        obj.Tracks(1).Data.Length = {10, 32, 35, 45};
        %        obj.Tracks(1).Data.PxIndexList = {[1, 5, 3], [2, 4], [1]};
        %
        %    If data for a tracked property is not available for a single
        %    frame, it should be represented by an empty matrix:
        %        obj.Tracks(1).Data.NumSpots = {2, [], 5};
        %
        
        function [obj, newTrackID] = addTrack(obj, frameIndex, trackData)
            %ADDTRACK  Add a track to the array
            %
            %  ADDTRACK(OBJ, FRAME, S) will add a new track to the
            %  Data property, starting at the specified FRAME. The new
            %  track data S must be a struct. Note that fieldnames are
            %  case-sensitive.
            
            if ~isnumeric(frameIndex)
                error('TrackArray:addTrack:frameIndexNotNumeric', ...
                    'Expected the frame index to be a number.');
                
            elseif ~isstruct(trackData)
                error('TrackArray:addTrack:trackDataNotStruct', ...
                    'Expected track data to be a struct.');
            end
            
            if numel(frameIndex) ~= 1
                error('Expected frame index to be a single number.');                
            end
            
            numNewTracks = numel(trackData);
            
            newTrackID = zeros(1, numNewTracks);
            
            for iTrack = 1:numNewTracks
            
                newTrackIdx = numel(obj.Tracks) + 1;
                
                obj.Tracks(newTrackIdx).ID = obj.LastID + 1;
                obj.LastID = obj.LastID + 1;
                
                %Assign default values to track metadata
                obj.Tracks(newTrackIdx).MotherID = NaN;
                obj.Tracks(newTrackIdx).DaughterID = NaN;
                obj.Tracks(newTrackIdx).Frames = frameIndex;
                
                %Update the data for the new track
                props = fieldnames(trackData(iTrack));
                for iP = 1:numel(props)
                    obj.Tracks(newTrackIdx).Data.(props{iP}) = {trackData(iTrack).(props{iP})};
                end
                
            end
            
            %Return the new track ID
            newTrackID(iTrack) = obj.Tracks(newTrackIdx).ID;
            
        end
        
        function obj = updateTrack(obj, trackID, frameIndex, trackData, varargin)
            %UPDATETRACK  Update the specified track
            %
            %  OBJ = UPDATETRACK(OBJ, TRACKID, FRAME, S) will update
            %  the data stored for the track with TRACKID. The frame(s)
            %  which should be modified can be specified by FRAME. S
            %  should be a struct specifying the new data.
            %
            %  Multiple frames can be replaced at once by supplying a
            %  vector for FRAME. S must either be a single-element struct,
            %  in which case all specified frames will be overwritten with
            %  the same struct, or S must have the same number of elements
            %  as FRAME.
            
            %Check that track exists
            trackIndex = findtrack(obj, trackID, true);
            
            %Update the track depending on the position of the frame(s)
            for frame = frameIndex
                
                %Update the mother/daughterIDs
                if isfield(trackData, 'MotherID')
                    obj.Tracks(trackIndex).MotherID = trackData.MotherID;
                    trackData = rmfield(trackData, 'MotherID');
                end
                
                if isfield(trackData, 'DaugtherID')
                    obj.Tracks(trackIndex).MotherID = trackData.DaughterID;
                    trackData = rmfield(trackData, 'DaugtherID');
                end
                
                %Get current (existing) data fields
                currDataFields = fieldnames(obj.Tracks(trackIndex).Data);
                
                %Identify fields that are not going to be updated
                inputFields = fieldnames(trackData);
                notUpdated = find(~ismember(currDataFields, inputFields));
                
                if frame < obj.Tracks(trackIndex).Frames(1)                    
                    %Add data to the start of the track
                    
                    %Update frames
                    obj.Tracks(trackIndex).Frames = [frame, obj.Tracks(trackIndex).Frames];

                    for iP = 1:numel(inputFields)
                        if ~ismember(inputFields{iP}, currDataFields)
                            %Create new field and append empty matrices to
                            %the rest of the data
                            obj.Tracks(trackIndex).Data.(inputFields{iP}) = cell(1, numel(obj.Tracks(trackIndex).Frames));
                            obj.Tracks(trackIndex).Data.(inputFields{iP}){1} = trackData.(inputFields{iP});
                            
                        else
                            %Append new data to the start
                            obj.Tracks(trackIndex).Data.(currDataFields{iP}) = ...
                                [trackData.(inputFields{iP}), obj.Tracks(trackIndex).Data.(inputFields{iP})];
                        end
                    end
                    
                    %Append empty matrices to any fields that were not
                    %assigned new data
                    if ~isempty(notUpdated)
                        for ii = notUpdated
                            obj.Tracks(trackIndex).Data.(currDataFields{ii}) = ...
                                [{[]}, obj.Tracks(trackIndex).Data.(currDataFields{ii})];
                        end
                    end
                    
                elseif frame > obj.Tracks(trackIndex).Frames(end)
                    %Add data to the end of the track
                    
                    %Update frames
                    obj.Tracks(trackIndex).Frames = [obj.Tracks(trackIndex).Frames, frame];

                    for iP = 1:numel(inputFields)
                        if ~ismember(inputFields{iP}, currDataFields)
                            %Create new field and append empty matrices to
                            %the rest of the data
                            obj.Tracks(trackIndex).Data.(inputFields{iP}) = cell(1, numel(obj.Tracks(trackIndex).Frames));
                            obj.Tracks(trackIndex).Data.(inputFields{iP}){end} = trackData.(inputFields{iP});
                            
                        else
                            
                            %Append new data to the end
                            obj.Tracks(trackIndex).Data.(inputFields{iP}) = ...
                                [obj.Tracks(trackIndex).Data.(inputFields{iP}), trackData.(inputFields{iP})];
                            
                        end
                    end
                    
                    %Append empty matrices to any fields that were not
                    %assigned new data
                    if ~isempty(notUpdated)
                        for ii = notUpdated
                            obj.Tracks(trackIndex).Data.(currDataFields{ii}) = ...
                                [obj.Tracks(trackIndex).Data.(currDataFields{ii}), {[]}];
                        end
                    end
                    
                else
                    %Update existing frame
                    
                    %Find index of existing frame
                    frameIdx = find(obj.Tracks(trackIndex).Frames == frame);
                    
                    for iP = 1:numel(inputFields)
                        if ~ismember(inputFields{iP}, currDataFields)
                            
                            %Create new field and append empty matrices to
                            %the rest of the data
                            obj.Tracks(trackIndex).Data.(inputFields{iP}) = cell(1, numel(obj.Tracks(trackIndex).Frames));
                            obj.Tracks(trackIndex).Data.(inputFields{iP}){frameIdx} = trackData.(inputFields{iP});
                            
                        else
                            
                            %Update data to the start
                            obj.Tracks(trackIndex).Data.(inputFields{iP}){frameIdx} = ...
                                trackData.(inputFields{iP});
                            
                        end
                    end
                    
                    %Right now this is skipped but could be modified to
                    %change to a default value e.g. NaN or an empty matrix
%                     %Append empty matrices to any fields that were not
%                     %assigned new data
%                     for ii = notUpdated
%                         obj.Tracks(trackIndex).(existingFields{ii}) = ...
%                             [obj.Tracks(trackIndex).(existingFields{ii}), {[]}];
%                     end
%                     
                    
                end
            
            
            end
            
            
        end
        
        function obj = deleteTrack(obj, trackID)
            %DELETETRACK  Remove a track
            %
            %  A.DELETETRACK(trackIndex) will remove the TrackData object
            %  at the index specified.
            
            if isempty(obj.Tracks)
                error('TrackArray:deleteTrack:NoTracks',...
                    'There are no tracks to delete.');
            else
                
                %Check track exists
                trackIndex = findtrack(obj, trackID, true);
                
                %Remove the track
                obj.Tracks(trackIndex) = [];
            end
            
        end
                
        function obj = deleteFrame(obj, trackID, frame)
            %DELETEFRAME  Remove a frame from a track
            %
            %  OBJ = DELETEFRAME(OBJ, TRACKID, FRAME) deletes data from a
            %  frame.
            
            trackIndex = findtrack(obj, trackID, true);
                        
            %Check that the frame exists
            frameIndex = find(obj.Tracks(trackIndex).Frames == frame, 1, 'first');
            
            if isempty(frameIndex)
                error('TrackArray:deleteFrame:FrameNotFound', ...
                    'Frame %.0f not found in track %.0f.', frame, trackID);
            end
            
            obj.Tracks(trackIndex).Frames(frameIndex) = [];
            
            props = fieldnames(obj.Tracks(trackIndex).Data);
            for iP = 1:numel(props)
                obj.Tracks(trackIndex).Data.(props{iP})(frameIndex) = [];
            end
            
        end
        
        function [obj, newTrackID] = splitTrack(obj, trackID, frame)
            %SPLITTRACK  Split an existing track at a specific frame
            %
            %  OBJ = SPLITTRACK(OBJ, TRACKID, FRAME) will split the track
            %  specified by TRACKID at the frame FRAME. A new track will
            %  be created containing the data from FRAME+1...END.
            %
            %  [OBJ, NEWTRACK] = SPLITTRACK(...) will also return the ID of
            %  the new track (the new track is created at the end of the
            %  array).
            %
            %  This function is used primarily during track assignment if a
            %  division event was detected to split the mother-daughter
            %  track.
            %
            %  Example:
            %  %Split track 5 at frame 3
            %  OBJ = SPLITTRACK(OBJ, 5, 3);
            
            %Check that track exists
            trackIndex = findtrack(obj, trackID, true);
            
            frameIndex = find(obj.Tracks(trackIndex).Frames == frame);
            
            %Create the new track
            newTrackIdx = numel(obj.Tracks) + 1;
            
            obj.Tracks(newTrackIdx).ID = obj.LastID + 1;
            obj.LastID = obj.LastID + 1;
            
            %Assign default values (overwritten if present in trackData)
            obj.Tracks(newTrackIdx).MotherID = NaN;
            obj.Tracks(newTrackIdx).DaughterID = NaN;
            obj.Tracks(newTrackIdx).Frames = obj.Tracks(trackIndex).Frames(frameIndex:end);
            
            %Update the data for the new track
            props = fieldnames(obj.Tracks(trackIndex).Data);
            for iP = 1:numel(props)
                obj.Tracks(newTrackIdx).Data.(props{iP}) = obj.Tracks(trackIndex).Data.(props{iP})(frameIndex:end);
                
                %Delete frames from the old track
                obj.Tracks(trackIndex).Data.(props{iP})(frameIndex:end) = [];
            end
            
            %Delete frames from the old track
            obj.Tracks(trackIndex).Frames = obj.Tracks(trackIndex).Frames(1:frameIndex-1);

            %Return the new track ID
            newTrackID = obj.Tracks(newTrackIdx).ID;
                        
        end
        
        function trackOut = getTrack(obj, trackID, varargin)
            %GETTRACK  Get track or specific frames from track
            %
            %  S = getTrack(obj, trackID) will return track data as a
            %  struct S.
            %
            %  S = getTrack(obj, trackID, FRAME) will return a specific
            %  frame as a struct S.
            %
            %  Specifically, this method moves the Data struct into the
            %  main track structure, and reformats the struct into matrices
            %  as appropriate.
            %
            %  Example:
            %  Say input track has the following fields
            %    IN.ID = 1;
            %    IN.MotherID = NaN;
            %    IN.DaughterID = NaN;
            %    IN.Frames = [1, 2, 4];
            %    IN.Data.Length = {10, [], 40};
            %    IN.Data.PxIdxList = {[10, 30, 50], [10, 20], [80, 90]};
            %    IN.Data.Centroid = {[5, 2], [6, 7], [8, 10]};
            %
            %  The output track will have:
            %    OUT.ID = 1;
            %    OUT.MotherID = NaN;
            %    OUT.DaughterID = NaN;
            %    OUT.Frames = [1, 2, 4];
            %    OUT.Length = [10; NaN; 40];
            %    OUT.PxIdxList = {[10, 30, 50], [10, 20], [80, 90]};
            %    OUT.Centroid = [5, 2; 6, 7; 8, 10];
           
            trackIndex = findtrack(obj, trackID, true);
            
            %Copy track metadata
            trackOut.ID = obj.Tracks(trackIndex).ID;
            trackOut.MotherID = obj.Tracks(trackIndex).MotherID;
            trackOut.DaughterID = obj.Tracks(trackIndex).DaughterID;
            
            
            %Determine how many frames to export                        
            if isempty(varargin)
                %Export all frames
                
                trackOut.Frames = obj.Tracks(trackIndex).Frames;
                
                datafields = fieldnames(obj.Tracks(trackIndex).Data);
                for iP = 1:numel(datafields)
                    
                    %Check if data is numeric
                    if all(cellfun(@isnumeric, obj.Tracks(trackIndex).Data.(datafields{iP})))
                        
                        %Check if the number of elements in each column
                        %(excluding empty fields) is equal
                        numElems = cellfun(@numel, obj.Tracks(trackIndex).Data.(datafields{iP}));
                        
                        if all(numElems == numElems(1) | numElems == 0)
                            
                            %Replace empty data with NaNs of the correct length
                            tmp = obj.Tracks(trackIndex).Data.(datafields{iP});
                            
                            if any(numElems == 0)
                                nzSize = numElems(numElems ~= 0);
                                nzSize = nzSize(1);
                                
                                tmp{cellfun(@isempty, tmp)} = NaN(1, nzSize);
                            end
                            
                            %Reformat into a matrix
                            trackOut.(datafields{iP}) = ...
                                cell2mat(tmp');
                            continue;
                        end
                    end
                    
                    %Otherwise, keep as cell array
                    trackOut.(datafields{iP}) = ...
                        obj.Tracks(trackIndex).Data.(datafields{iP});
                    
                end
                
            else
                %Export a single frame
                
                trackOut.Frames = obj.Tracks(trackIndex).Frames(varargin{1});
                
                datafields = fieldnames(obj.Tracks(trackIndex).Data);
                for iP = 1:numel(datafields)
                    
                    if isempty(obj.Tracks(trackIndex).Data.(datafields{iP}){varargin{1}})
                        trackOut.(datafields{iP}) = NaN;                        
                    else
                        trackOut.(datafields{iP}) = obj.Tracks(trackIndex).Data.(datafields{iP}){varargin{1}};
                    end
                end
            end
            
        end
        
        
        %--- Export data (TODO) ---%
        function exportToCSV(obj, fn)
            
            fid = fopen(fn, 'w');
            
            fprintf(fid, 'TID, MotherIdx, DaughterIdx1, DaughterIdx2, Frame, ');
            
            fprintf(fid,'%s ,', obj.TrackedDataFields{1:end-1});
            fprintf(fid,'%s \n', obj.TrackedDataFields{end});
            
            for iTrack = 1:numel(obj)
                
                ct = obj.getTrack(iTrack);
                
                fprintf(fid, '%d, %d, %d, %d', ct.ID, ct.MotherIdx, ct.DaughterIdxs(1), ct.DaughterIdxs(end));
                
                for iF = 1:ct.NumFrames
                    
                    if iF > 1
                        fprintf(fid, ', , , ');
                    end
                    
                    fprintf(fid, ', %d', ct.FrameIndex(iF));
                    
                    for iP = 1:numel(obj.TrackedDataFields)
                        
                        if numel(ct.Tracks(iF).(obj.TrackedDataFields{iP})) > 5
                            
                            fprintf(fid, ', %%');
                            
                        elseif numel(ct.Tracks(iF).(obj.TrackedDataFields{iP})) > 1
                            
                            fprintf(fid, ', %s', mat2str(ct.Tracks(iF).(obj.TrackedDataFields{iP}), 3));
                            
                        else
                            fprintf(fid, ', %d', ct.Tracks(iF).(obj.TrackedDataFields{iP}));
                            
                        end
                    end
                    fprintf(fid, '\n');
                end
                fprintf(fid, '\n');
                
            end
            
            fclose(fid);
            
            
        end
        
        function structOut = struct(obj)
            %STRUCT  Convert the object to struct
            %
            %  STRUCT(OBJ) will convert the object to a MATLAB
            %  structured array.
            
            %Initialize the track data struct
            structOut.TrackData = struct('FirstFrame', {}, ...
                'LastFrame', {}, ...
                'MotherIdx', {}, ...
                'DaughterIdx', {});
            
            trackProps = obj.TrackedDataFields;
            
%             for iP = 1:numel(trackProps)
%                 structOut.TrackData.(trackProps{iP}) = {};
%             end
            
            structOut.TrackData(obj.NumTracks).FirstFrame = 0;
            
            
            %Copy the data
            for iTrack = 1:obj.NumTracks
                
                ct = getTrack(obj, iTrack);
                
                structOut.TrackData(iTrack).FirstFrame = ct.FirstFrame;
                structOut.TrackData(iTrack).LastFrame = ct.LastFrame;
                structOut.TrackData(iTrack).MotherIdx = ct.MotherIdx;
                structOut.TrackData(iTrack).DaughterIdx = ct.DaughterIdxs;
                structOut.TrackData(iTrack).NumFrames = ct.NumFrames;
                structOut.TrackData(iTrack).FrameIndex = ct.FrameIndex;
                
                for iP = 1:numel(trackProps)
                    structOut.TrackData(iTrack).(trackProps{iP}) = ...
                       getData(ct, trackProps{iP});
                end
                
            end
            
            
            %Copy the metadata
            structOut.MeanDeltaT = obj.MeanDeltaT;
            structOut.Timestamps = obj.FileMetadata.Timestamps;
            structOut.TimestampUnit = obj.FileMetadata.TimestampUnit;
            structOut.PxSize = obj.FileMetadata.PxSize;
            structOut.PxSizeUnit = obj.FileMetadata.PxSizeUnit;
            structOut.ImgSize = obj.FileMetadata.ImgSize;
            structOut.NumTracks = obj.NumTracks;
            structOut.NumFrames = obj.NumFrames;
            structOut.TrackedDataFields = obj.TrackedDataFields;
            structOut.CreatedOn = obj.CreatedOn;
            structOut.Filename = obj.Filename;
            
        end

    end
    
    methods (Access = private)

        function varargout = findtrack(obj, trackID, varargin)
            %FINDTRACK  Returns track index
            %
            %  INDEX = FINDTRACK(OBJ, TRACKID, STOP_ON_ERROR) returns the
            %  track index if it exists. 
            %
            %  If STOP_ON_ERROR is true (default: false), the method will
            %  throw an error if the track is not found. Otherwise it will
            %  return an empty matrix.
            
            if isempty(varargin)
                throwError = false;
            else
                throwError = varargin{1};
            end
            
            doesExist = ismember(trackID, [obj.Tracks.ID]);
            
            %Find matching index
            if throwError && ~doesExist
                
                error('Could not find track ID %.0f.', trackID);
                
            elseif doesExist
                
                varargout{1} = find(trackID == [obj.Tracks.ID], 1, 'first');      
                
            elseif ~throwError && ~doesExist
                
                varargout{1} = [];
                
            end
                  
            
        end
        
    end
    
end








