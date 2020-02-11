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
                
                %Return the new track ID
                newTrackID(iTrack) = obj.Tracks(newTrackIdx).ID;
                
            end
            
        end
        
        function obj = setMotherID(obj, trackID, motherID)
            
            %Check that track exists
            trackIndex = findtrack(obj, trackID, true);
            obj.Tracks(trackIndex).MotherID = motherID;
            
        end
        
        function obj = setDaughterID(obj, trackID, daughterID)
            
            %Check that track exists
            trackIndex = findtrack(obj, trackID, true);
            obj.Tracks(trackIndex).DaughterID = daughterID;
            
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
        
        
        
        %--- Traversal functions ---%
        function IDout = traverse(obj, rootTrackID, varargin)
            %TRAVERSE  Return track IDs in specified order
            %
            %  M = TRAVERSE(OBJ, ROOTTRACKID) will traverse the tree in the
            %  specified order, returning track IDs in the vector M.
            %
            %  Currently, only preorder traversal is supported, e.g.
            %  the order starts with the root, then down the left tree,
            %  then the right tree.
            
            %Pre-order traversal
            queue = rootRID;
            IDout = [];
            while ~isempty(queue)
                
                IDout =[IDout, queue(1)]; %#ok<AGROW>
                cid = queue(1);
                queue(1) = [];
                
                queue = [obj.tblData(cid).DaughterIDs, queue]; %#ok<AGROW>
                queue(isnan(queue)) = [];
                
            end
            
        end
        
        function treeplot(obj, rootTrackID, varargin)
            %TREEPLOT  Plot track lineage as a binary tree
            %
            %  TREEPLOT(OBJ) will plot the tree in the current axes. By
            %  default, the tree will be plotted with branches growing
            %  upwards, and the y-axis will be the height of each node.
            %
            %  The tree is drawn using a grid-based algorithm, producing a
            %  plot similar to tournament brackets, where the branches in
            %  each level are evenly spaced apart.
            %
            %  TREEPLOT(OBJ, PROPERTY) will plot the tree with each node
            %  separated by the property specified. For example, to plot
            %  the nodes positioned by the 'distance' property: PLOT(OBJ,
            %  'distance')
            %
            %  TREEPLOT(OBJ, 'direction') will plot the tree growing in the
            %  direction specified. By default, the 'direction' plotted is
            %  'up'. The following directions are allowed:
            %       'up'  - Root is at the bottom of plot, branches grow
            %               upwards.
            %     'down'  - Root is at the top of the plot, branches grow
            %               downwards.
            %     'right' - Root is on the left of plot, branches grow
            %               right.
            %
            %  TREEPLOT(OBJ, ..., 'cumuldist', true) will plot the nodes
            %  separation cumulatively.
            %
            %  TREEPLOT(OBJ, ..., 'symmetric') will scale the non-data axis so
            %  that the tree is centered in the figure. This could make
            %  plots with missing branches look better.
            %
            %Implementation notes:
            %
            %  * During the first part of the code, the algorithm assigns X
            %    and Y values to each node in the tree, defined as though
            %    the tree is growing upwards. To get the tree growing in
            %    different directions, these X and Y values are rotated
            %    before plotting.
            %
            %  The following describe the basic principles of the
            %  algorithm:
            %
            %  * The tree is traversed in a single breadth-first traverse,
            %    to assign a position to each node.
            %
            %  * At the lowest levels, the nodes should be spaced evenly
            %    apart. Thus the maximum width of the tree (in pixels) will
            %    be 2 x 2^K - 1 (-1 because one of the edges is not drawn).
            %    K is the maximum height of the tree (h = 0 is the root
            %    node).
            %
            %  * The root should be at the very center of the tree, so root
            %    position should be (2 * 2^K)/2 = 2^K.
            %
            %  * To keep each parent centered over its children, each child
            %    node should be moved by +/- 2^(K - h) compared to the
            %    parent (e.g. in a 2 height tree, level 1 moves 2 steps
            %    away, level 2 moves 1 step away).
            %
            %  * Missing branches should be treated as though they exist
            %    and no nodes should pass through the space.
            %
            %  * Because each node is spaced progressively further apart,
            %    the algorithm does not produce overlapping node positions.
            %
            %  * If nodes are labelled, the root and leaf nodes will appear
            %    outside the border of the image.
            
            %Throw an error if the tree is empty
            if numel(obj.Tracks) == 0
                error('TrackArray:treeplot:NoTracks', 'There are no tracks');                
            end
            
            %Default plotting options
            plotDirection = 'up';
            axSymmetric = false;
            
            %Parse input arguments
            iP = 1;
            while iP <= numel(varargin)
                
                switch lower(varargin{iP})
                    
                    case 'direction'
                        plotDirection = varargin{iP + 1};
                        iP = iP + 2;
                        
                    case {'cumdist', 'cumuldist'}
                        iP = iP + 2;
                        
                    case 'symmetric'
                        axSymmetric = true;
                        iP = iP + 1;
                        
                    otherwise
                        error('Unknown input');

                end
                
            end
            
            %To start, traverse the tree breadthfirst. To do so, we create
            %a queue (LIFO) starting at the root node.
            
            %Create a struct for node and line positions
            nodes = struct('ID', {}, 'ParentIndex', {}, ...
                'isLeft', {}, 'isRight', {}, ...
                'X', {}, 'Y', {}, ...
                'lineX', {}, 'lineY', {}, ...
                'Height', {});
            
            %Initialize the root node and node pointer
            ptrNode = 1;
            
            nodes(ptrNode).ID = rootTrackID;
            nodes(ptrNode).Height = 1;
            
            %Traverse the tree
            while ptrNode <= numel(nodes)
                
                trackIndex = findtrack(obj, nodes(ptrNode).ID, true);
                
                %Add the children node(s) (if any) to the queue 
                if ~isnan(obj.Tracks(trackIndex).DaughterID)
                    
                    newNode = numel(nodes) + 1;
                    nodes(newNode).ID = obj.Tracks(trackIndex).DaughterID(1);
                    nodes(newNode).ParentIndex = ptrNode;
                    nodes(newNode).isLeft = true;
                    nodes(newNode).isRight = false;
                    nodes(newNode).Height = nodes(ptrNode).Height + 1;
                    
                    if numel(obj.Tracks(trackIndex).DaughterID) == 2
                        
                        newNode = numel(nodes) + 1;
                        nodes(newNode).ID = obj.Tracks(trackIndex).DaughterID(2);
                        nodes(newNode).ParentIndex = ptrNode;
                        nodes(newNode).isLeft = false;
                        nodes(newNode).isRight = true;
                        nodes(newNode).Height = nodes(ptrNode).Height + 1;
                        
                    end
                    
                end

                %Assign X and Y values to the node
                if ptrNode == 1
                                        
                    %Handle the root
                    nodes(ptrNode).X = 0;
                    nodes(ptrNode).Y = obj.Tracks(trackIndex).Frames(end);
                    
                    %Draw a line from (0,0) to the root node
                    nodes(ptrNode).lineX = [nodes(ptrNode).X, nodes(ptrNode).X, nodes(ptrNode).X];
                    nodes(ptrNode).lineY = [obj.Tracks(trackIndex).Frames(1), nodes(ptrNode).Y, nodes(ptrNode).Y];
                    
                else
                    
%                     %Calculate the X position of the current node 
%                     nodes(ptrNode).X = nodes(nodes(ptrNode).ParentIndex).X;
%                     nodes(ptrNode).Y = obj.Tracks(nodes(ptrNode).ID).Frames(end);
                    
                end
                
                %Move pointer to next node
                ptrNode = ptrNode + 1;
                
            end
            
            %Return to the tree and add offsets
            treeHeight = max([nodes.Height]);
            
            for ptrNode = 2:numel(nodes)
                                    
                if nodes(ptrNode).isLeft
                    
%nodes(ptrNode).X = nodes(nodes(ptrNode).ParentIndex).X
                    nodes(ptrNode).X = nodes(nodes(ptrNode).ParentIndex).X - 2^(treeHeight - nodes(ptrNode).Height);
                else
                    nodes(ptrNode).X = nodes(nodes(ptrNode).ParentIndex).X + 2^(treeHeight - nodes(ptrNode).Height);
                end
                
                %Draw the bracket lines connecting the node to its
                %parent
                nodes(ptrNode).lineX = [nodes(nodes(ptrNode).ParentIndex).X ...
                    nodes(ptrNode).X...
                    nodes(ptrNode).X];
                nodes(ptrNode).lineY = [nodes(nodes(ptrNode).ParentIndex).Y...
                    nodes(nodes(ptrNode).ParentIndex).Y...
                    nodes(ptrNode).Y];
            
            end
            
            
            %Collect actual X and Y values for plotting
            switch lower(plotDirection)
                
                case 'up'
                    %Branches grow upwards and root is at bottom of tree
                    
                    X = [nodes.X];
                    Y = [nodes.Y];
                    
                    LineX = cat(1, nodes.lineX)';
                    LineY = cat(1, nodes.lineY)';
                
                case 'down'
                    %Branches grow downwards and root is at bottom of tree
                    %Rotation matrix = [1 0; 0 -1];
                    
                    X = [nodes.X];
                    Y = -[nodes.Y];
                    
                    LineX = cat(1, nodes.lineX)';
                    LineY = -cat(1, nodes.lineY)';
                                        
                case 'right'
                    %Branches grow right and root is on the left
                    %Rotation matrix = [0 1; -1 0] for 90 deg clockwise
                    
                    X = [nodes.Y];
                    Y = -[nodes.X];
                    
                    LineX = cat(1, nodes.lineY)';
                    LineY = -cat(1, nodes.lineX)';
                    
            end
            
            %Due to the way MATLAB handles 'line' objects, we have to
            %detect if hold is on for the figure ourselves.
            
            if ~ishold
                %Overwrite the currently selected figure
                newplot(gcf);
            end
            
            %Draw the lines connecting nodes to parents
            line(LineX, LineY, 'Color','black')
            
            %Tidy up the plots and insert node labels depending on the
            %direction of the plot
            switch lower(plotDirection)
                
                case 'up'
                    
                    %Offset the labels to the right and slightly below the
                    %node center
                    text(0, - 0.05, num2str(nodes(1).ID), 'HorizontalAlignment', 'center'); %Root
                    text(X(2:end) + 0.2, Y(2:end) - 0.1, strsplit(num2str([nodes(2:end).ID])))
                    
                    set(gca, 'xTick', [])
                    
                    if axSymmetric
                        xLim = get(gca, 'XLim');
                        set(gca, 'XLim', [-max(abs(xLim)) max(abs(xLim))]);
                    end
                    
                case 'down'
                    
                    %Offset the labels to the right and slightly above the
                    %node center
                    text(0, 0.2, num2str(nodes(1).ID), 'HorizontalAlignment', 'center'); %Root
                    text(X(2:end) + 0.2, Y(2:end) + 0.2, strsplit(num2str([nodes(2:end).ID])))
                    
                    %Invert the yaxis tick mark labels
                    yTicks = get(gca, 'yTick');
                    set(gca, 'yTickLabels', -yTicks);                    
                    
                    set(gca, 'xTick', [])                    
                    
                    if axSymmetric
                        xLim = get(gca, 'XLim');
                        set(gca, 'XLim', [-max(abs(xLim)) max(abs(xLim))]);
                    end
                    
                case 'right'
                    
                    %Offset the labels to the right and slightly above the
                    %node center
                    text(- 0.1, 0, nodes(1).ID); %Root
                    text(X(2:end) + 0.1, Y(2:end), {nodes(2:end).ID})
                    
                    set(gca, 'yTick', [])
                    
                    if axSymmetric
                        yLim = get(gca, 'YLim');
                        set(gca, 'YLim', [-max(abs(yLim)) max(abs(yLim))]);
                    end
            end
                        
        end
        
        
        
        
        
        %--- Export data (TODO) ---%
        function export(obj, outputFN, varargin)
            %EXPORT  Export track data to various formats
            %
            %  EXPORT(OBJ, OUTPUTFN) will export the track data and file
            %  metadata. The output format will be determined from the
            %  extension of the output file.
            %
            %  Supported output formats are: CSV
           
            if ~exist('outputFN', 'var')
                
                [FN, outPath] = uiputfile({'*.csv', 'Comma-separated value (*.csv)'});
                
                if isequal(FN, 0)
                    return;                    
                end
                
                outputFN = fullfile(outPath, FN);
                
            end
            
            [outputDir, ~, outputFormat] = fileparts(outputFN);
            
            if ~isempty(outputDir) && exist(outputDir, 'dir')
                mkdir(outputDir);                
            end
            
            switch lower(outputFormat)
                
                case '.csv'
                    
                    try
                        exportToCSV(obj, outputFN);
                    catch ME
                        fclose('all');
                        rethrow(ME)
                    end
                    
                otherwise
                    error('Please specify an extension for the output file');
                    
            end
            
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
        
        function exportToCSV(obj, fn)
            %EXPORTTOCSV  Export track and filemetadata as CSV files
            %
            %  EXPORTTOCSV(OBJ, FN) exports the data as a CSV file.
            
            fid = fopen(fn, 'w');
            
            if fid < 0
                error('Error opening file %s for writing.', fn);                
            end
            
            %Print file metadata
            fprintf(fid, 'Filename, %s\n', obj.Filename);
            fprintf(fid, 'Track data created, %s\n', obj.CreatedOn);
            fprintf(fid, 'TimestampUnit, %s\n', obj.FileMetadata.TimestampUnit);
            fprintf(fid, 'PxSize, %s\n', mat2str(obj.FileMetadata.PxSize));
            fprintf(fid, 'PxSizeUnit, %s\n', obj.FileMetadata.PxSizeUnit);
            fprintf(fid, 'ImgSize, %s\n', mat2str(obj.FileMetadata.ImgSize));
            fprintf(fid, '\n');
            
            %Print column headers
            datafields = fieldnames(obj.Tracks.Data);
            
            fprintf(fid, 'Track ID, MotherID, DaughterID, Frame');
            
            fprintf(fid, ', %s', datafields{:});
            fprintf(fid, '\n');
            
            for iTrack = 1:numel(obj.Tracks)
                
                %Print track metadata
                fprintf(fid, '%.0f, %.0f, %.0f', ...
                    obj.Tracks(iTrack).ID, ...
                    obj.Tracks(iTrack).MotherID, ...
                    obj.Tracks(iTrack).DaughterID);
                    
                %Print track data
                for iF = 1:numel(obj.Tracks(iTrack).Frames)
                    
                    if iF > 1
                        fprintf(fid, ', , ');
                    end
                    
                    %Print frame index
                    fprintf(fid, ', %.0f', obj.Tracks(iTrack).Frames(iF));
                    
                    %Print data fields
                    for iP = 1:numel(datafields)
                        
                        switch class(obj.Tracks(iTrack).Data.(datafields{iP}){iF})
                            
                            case 'char'
                                fprintf(fid, ', %s', obj.Tracks(iTrack).Data.(datafields{iP}){iF});
                                
                            case 'double'
                                fprintf(fid, ', %s', mat2str(obj.Tracks(iTrack).Data.(datafields{iP}){iF}));
                        
                        end
                        
                    end
                    fprintf(fid, '\n');
                end
                fprintf(fid, '\n');
                
            end
            
            fclose(fid);
                        
        end
    end
    
end








