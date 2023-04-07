classdef LAPLinker
    %LAPLINKER  Links objects in movies using linear assignment
    %
    %  OBJ = LAPLinker constructs a LAPLINKER object to link objects in
    %  movies using linear assignment. The objective is to create "tracks",
    %  which contain timeseries data corresponding to a single object over
    %  time.
    %
    %  Objects detected in the current frame (called "detections") are
    %  either linked to objects from previous frames to form tracks, or new
    %  tracks are created if no possible links are found. The likelihood of
    %  either outcome is determined by calculating a "cost" of linking two
    %  objects. For example, for tracking moving objects, the straight-line
    %  (euclidean) distance between detections and last known object
    %  positions could be used as the cost. The final outcome of each
    %  detected object is found by solving the cost matrix using a linear
    %  assignment algorithm which minimizes the total cost.
    %
    %  The algorithm used here follows closely from Jaqaman et al.'s
    %  original approach. However, several modifications have been made:
    %
    %    * Simplified version without the repair (merge/split) phase
    %
    %    * Division events are tested for during new track creation
    %
    %    * The Jonker-Volgenant (JV) algorithm is used rather than the
    %      munkres/Hungarian algorithm in the original publication. In
    %      testing, the JV algorithm yields solutions about 10x faster and
    %      appear to be just as accurate. The munkres algorithm is also
    %      provided as an optional solver.
    %
    %    * A different metric for tracking non-motile cells using an
    %      overlap score
    %
    %  LAPLinker Properties:
    %  ---------------------
    %   Solver              - Name of assignment solver
    %   LinkedBy            - Property to compute linking cost
    %   LinkCostMetric      - Function to compute linking cost
    %   LinkScoreRange      - Min and max values for linking objects
    %   MaxTrackAge         - Maximum number of frames a track can go 
    %                         without being updated
    %   TrackDivision       - If true, division events will be tracked.
    %                         Otherwise, new tracks will be created for
    %                         new objects
    %   DivisionType        - 'mitosis' for mitosis detection. Anything
    %                         else for a generic division detection 
    %   DivisionParameter   - Property to determine division
    %   DivisionScoreMetric - Function to compute division cost
    %   DivisionScoreRange  - Min and max values for a division to occur
    %   MinFramesBetweenDiv - Minimum number of frames between divisions
    %   activeTrackIDs      - A vector containing IDs of active tracks
    %   NumTracks - Number of tracks in the array
    %
    %  LAPLinker Methods:
    %  ------------------
    %   assignToTrack  - Main method to call. Assigns new data to tracks
    %   updateMetadata - Sets file metadata options
    %   startTrack     - Start a new track
    %   updateTrack    - Modify or add values to an existing track
    %   splitTrack     - Splits a track into two (used to handle 
    %                    division events)
    %
    %  Example:
    %  % This example shows only the outline of a typical program. To see
    %  % working examples, have a look at the 'demo' folder.
    %  
    %  % Declare a new object
    %  L = LAPLinker;
    %
    %  % Set properties as required
    %  L.LinkedBy = 'PixelIdxList';
    %  L.LinkCostMetric = 'pxintersect';
    %
    %  for iT = 1:numFrames
    %     %Run your segmentation code, then call regionprops to measure
    %     %object properties. Make sure the output is a struct with a field
    %     %as specified in the 'LinkedBy' property.
    %     data = regionprops(mask, 'Area', 'PixelIdxList');
    %
    %     %Update the tracks
    %     L = assignToTrack(L, iT, data)
    %  end
    %
    %  %Retrieve the struct containing track data once tracking is complete
    %  tracks = L.tracks;
    %
    %
    %  Credits: 
    %    Ref: K. Jaqaman et al. Nature Methods 5, 695-702 (2008)
    %    JV algorithm: Yi Cao, Cranfield University, from Mathworks File
    %                  Exchange
    %    Author: Jian Wei Tay, University of Colorado Boulder
    
    properties
        
        Solver = 'lapjv';   %Algorithm to solve assignment problem
        
        LinkedBy = 'Centroid';  %Data fieldname used to link cells
        LinkCostMetric = 'euclidean'; %Metric to compute linking costs
        LinkScoreRange = [0, 100];  %Valid linking score range
        MaxTrackAge = 2;  %How many frames a track can go before tracking stops
        
        TrackDivision = false;  %If true, division events will be tracked
        DivisionType = '';
        DivisionParameter = 'Centroid';  %Data fieldname used to track division
        DivisionScoreMetric = 'euclidean';  %Metric to compute division likelihood
        DivisionScoreRange = [0, 2];  %Valid division score range
        MinFramesBetweenDiv = 10;  %Minimum number of frames between division events
        
    end
    
    properties (SetAccess = private)
        
        %Data structure for track data
        tracks = TrackArray;
        activeTrackIDs = [];
        
    end
    
    properties (Dependent)
        
        NumTracks  %Number of tracks
        
    end
    
    methods
        
        function obj = LAPLinker(varargin)
            %LAPLINKER  Construct a new LAPLinker object
            %
            %  OBJ = LAPLINKER creates a new LAPLinker object with default
            %  settings.
            %
            %  OBJ = LAPLINKER(S) will load settings in the struct S. S
            %  should be a struct with settings as fieldnames. Any
            %  unrecognized fields will be skipped without warning.
            
            if numel(varargin) == 1
                
                if ~isstruct(varargin{1})
                    error('LAPLinker:InvalidInput', ...
                        'Expected input to be a struct.');                    
                end
                
                inputFields = fieldnames(varargin{1});
                                
                C = metaclass(obj);
                P = C.Properties;
                for k = 1:length(P)
                    if ~P{k}.Dependent && ismember(P{k}.Name, inputFields)
                        obj.(P{k}.Name) = varargin{1}.(P{k}.Name);
                    end
                end
                
            elseif numel(varargin) > 1
                error('LAPLinker:TooManyInputArguments', ...
                    'Too many input arguments. Expected one at most.');                
            end
            
        end
        
        function numtracks = get.NumTracks(obj)
            %Returns number of tracks
            
            numtracks = numel(obj.tracks);
            
        end
        
        function obj = assignToTrack(obj, frame, newData)
            %ASSIGNTOTRACK  Assign data to tracks
            %
            %  OBJ = ASSIGNTOTRACK(OBJ, FRAME, DATA) assigns new data to
            %  tracks using the linear assignment approach. FRAME should be
            %  the current frame number. DATA is a struct array, with each
            %  element being the data from a single new detection. The
            %  properties being tracked should be a field in the struct. An
            %  example of the appropriate structure to use is the output of
            %  'regionprops'. If no tracks currently exist (i.e. this is
            %  the first frame), the function will create new tracks.
            %
            %  The cost of assignments vs creating new tracks are computed
            %  using the data specified in the property 'LinkedBy'.
            %  Currently, only two metrics are supported:
            %     'euclidean' - Distance between new detection and last
            %                   known position of objects (i.e. using
            %                   'Centroid')
            %     'pxintersect' - Number of overlapping pixels (the input
            %                     data should have 'PixelIdxList')
            %
            %  The algorithm specified in the 'Solver' property of the
            %  object is used to perform the assignment. Currently, the two
            %  solvers built into this software are:
            %
            %     'lapjv' - Jonker-Volgenant assignment
            %     'munkres' - Munkres/Hungarian algorithm
            %
            %  You can use your own solver by specifying the name of the
            %  function in the 'Solver' property. Your assignment function
            %  must take only a single input, the cost matrix, and return a
            %  vector that contains the assignment of a row to a column.
            %
            %  See also: regionprops
            
            %If data structure is empty, then create new tracks
            if numel(obj.tracks) == 0
                
                obj = startTrack(obj, frame, newData);
                
            else
                
                %--- Compute cost matrix ---%
                
                %-- Linking costs (top left) --%
                cost_to_link = zeros(numel(obj.activeTrackIDs), numel(newData));
                
                newLinkData = {newData.(obj.LinkedBy)};
                
                for acTr = 1:numel(obj.activeTrackIDs)
                    lastTrackData = obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Data.(obj.LinkedBy){end};
                    cost_to_link(acTr, :) = LAPLinker.computecost(lastTrackData, newLinkData, obj.LinkCostMetric);
                end
                cost_to_link(cost_to_link < min(obj.LinkScoreRange) | cost_to_link > max(obj.LinkScoreRange)) = Inf;
                
                %-- Non-linking cost (top right) --%
                altCost = 1.05 * max(cost_to_link(~isinf(cost_to_link)));
                
                if isempty(altCost)
                    %Likely reason, there were no valid links at all
                    %(registration/segmentation issue?)
                    altCost = 2e8;                    
                end
                
                cost_no_links = inf(numel(obj.activeTrackIDs));
                cost_no_links(1:(size(cost_no_links, 1) + 1):end) = altCost;

                %-- Cost to start new tracks (bottom left) --%
                cost_new_track = inf(numel(newLinkData));
                cost_new_track(1:(size(cost_new_track, 1) + 1):end) = altCost;
                
                %-- Auxiliary (bottom right) --%
                cost_aux = cost_to_link';
                cost_aux(cost_aux < Inf) = min(cost_to_link(cost_to_link < Inf));
                
                %Concatenate matrix
                cost = [cost_to_link, cost_no_links; cost_new_track, cost_aux];
                
                %Solve the assignment
                switch lower(obj.Solver)
                    
                    case {'lapjv', 'jv'}
                        rowsol = LAPLinker.lapjv(cost);
                        
                    case {'munkres', 'hungarian'}
                        rowsol = LAPLinker.munkres(cost);
                    
                    otherwise
                        if exist(obj.Solver, 'file')            
                            %Call external solver
                            eval(['rowsol = ', obj.Solver, ';'])
                        else
                            error('LAPLinker:assignToTrack:UnknownSolver', ...
                                '''%s'' is not a built-in solver and ''%s.m'' could not be found.', ...
                                obj.Solver, obj.Solver);
                        end
                       
                end
                                
                chkStop = [];
                
                %Handle assignments
                for iSol = 1:numel(rowsol)
                    
                    if iSol <= numel(obj.activeTrackIDs)
                        
                        if rowsol(iSol) > 0 && rowsol(iSol) <= numel(newData)
                            %Assign new data to existing track
                            obj.tracks = updateTrack(obj.tracks, obj.activeTrackIDs(iSol), frame, newData(rowsol(iSol)));
                        else
                            %Compute the age and see if it is time to stop
                            %tracking
                            chkStop(end + 1) = obj.activeTrackIDs(iSol);
%                             age = frame - obj.tracks.Tracks(obj.activeTrackIDs(iSol)).Frames(end);
%                             
%                             if age > obj.MaxTrackAge
%                                 
%                                 obj.activeTrackIDs(iSol) = [];
%                                 
%                             end
                        end
                        
                    else
                        
                        if rowsol(iSol) > 0 && rowsol(iSol) <= numel(newData)
                            
                            %Create new track
                            [obj, newTrackID] = startTrack(obj, frame, newData(rowsol(iSol)));


                            
                            %Test for division
                            if obj.TrackDivision
                                
                                %Test if cell divided
                                switch lower(obj.DivisionType)

                                    case 'mitosis'
                                        %TODO

                                        %Determine if cells divided using
                                        %the criteria from eLife paper:
                                        % Look for a nuclei in a region of
                                        % 30 pixels around each unassigned
                                        % nucleus. If there is a nucleus
                                        % with a similar area and
                                        % intensity, and nucleus not
                                        % divided recently, then mitosis.

                                        %Look for objects which exist
                                        %around the newly created object

                                        for acTr = 1:numel(obj.activeTrackIDs)
                                
                                            %Do not check current object
                                            if obj.activeTrackIDs(acTr) == newTrackID
                                                continue;
                                            end

                                            if numel(obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames) < 2
                                                continue;
                                            end
% 
%                                             if newTrackID == 36 && obj.activeTrackIDs(acTr) == 14
%                                                 keyboard
% 
%                                             end



                                            %Check if object exists at the
                                            %current frame
                                            if obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames(end) == frame

                                                %Check if the position is
                                                %within 30 px of current
                                                %nucleus
                                                lastPos = obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Data.(obj.DivisionParameter){end - 1};

                                                if sqrt(sum((newData(rowsol(iSol)).(obj.DivisionParameter) - lastPos).^2)) < 30
                                                    %FOUND A CELL

                                                    %Check if area is
                                                    %similar
                                                    areaDiff = abs(newData(rowsol(iSol)).Area - obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Data.Area{end})/newData(rowsol(iSol)).Area;
                                                    if areaDiff <= 0.3

                                                        %Check if divided
                                                        %recently
                                                        if isnan(obj.tracks.Tracks(obj.activeTrackIDs(acTr)).MotherID) || ...
                                                                (frame - obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames(1)) < obj.MinFramesBetweenDiv

                                                            %Division
                                                            %detected

                                                            %Split the mother track
                                                            [obj, daughterID] = splitTrack(obj, obj.activeTrackIDs(acTr), frame);

                                                            %Update mother
                                                            obj.tracks = setDaughterID(obj.tracks, ...
                                                                obj.activeTrackIDs(acTr), ...
                                                                [newTrackID, daughterID]);

                                                            %Update daughters
                                                            obj.tracks = setMotherID(obj.tracks, ...
                                                                newTrackID, ...
                                                                obj.activeTrackIDs(acTr));

                                                            obj.tracks = setMotherID(obj.tracks, ...
                                                                daughterID, ...
                                                                obj.activeTrackIDs(acTr));

                                                            %Set mother track as inactive
                                                            obj.activeTrackIDs(acTr) = [];
                    
                                                        end

                                                    end



                                                end


                                            end





                                        
                                        end
                                        



                                    otherwise

                                        cost_to_divide = Inf(numel(obj.activeTrackIDs), 1);

                                        %Compute the division cost matrix
                                        for acTr = 1:numel(obj.activeTrackIDs)

                                            if obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames(1) >= frame || ...
                                                    obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames(end) < frame

                                                %Check if the track is a valid
                                                %candidate
                                                cost_to_divide(acTr) = Inf;

                                            elseif ~isnan(obj.tracks.Tracks(obj.activeTrackIDs(acTr)).MotherID) && ...
                                                    (frame - obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Frames(1)) < obj.MinFramesBetweenDiv

                                                %Don't let cells divide too quickly
                                                cost_to_divide(acTr) = Inf;

                                            else

                                                %Check data with previous frame
                                                lastTrackData = obj.tracks.Tracks(obj.activeTrackIDs(acTr)).Data.(obj.DivisionParameter){end - 1};
                                                cost_to_divide(acTr) = LAPLinker.computecost(lastTrackData, {newData(rowsol(iSol)).(obj.DivisionParameter)}, obj.DivisionScoreMetric);

                                            end

                                        end

                                        %Block invalid division events
                                        cost_to_divide(cost_to_divide < min(obj.DivisionScoreRange) | cost_to_divide > max(obj.DivisionScoreRange)) = Inf;

                                        [min_div_cost, min_div_ind] = min(cost_to_divide);

                                        if ~isinf(min_div_cost)

                                            %Split the mother track
                                            [obj, daughterID] = splitTrack(obj, obj.activeTrackIDs(min_div_ind), frame);

                                            %Update mother
                                            obj.tracks = setDaughterID(obj.tracks, ...
                                                obj.activeTrackIDs(min_div_ind), ...
                                                [newTrackID, daughterID]);

                                            %Update daughters
                                            obj.tracks = setMotherID(obj.tracks, ...
                                                newTrackID, ...
                                                obj.activeTrackIDs(min_div_ind));

                                            obj.tracks = setMotherID(obj.tracks, ...
                                                daughterID, ...
                                                obj.activeTrackIDs(min_div_ind));

                                            %Set mother track as inactive
                                            obj.activeTrackIDs(min_div_ind) = [];

                                        end

                                end

                            end
                            
                        else
                            
                            %Do nothing
                            
                        end
                        
                    end
                    
                end
                
                for iChk = 1:numel(chkStop)
                    
                    age = frame - obj.tracks.Tracks(chkStop(iChk)).Frames(end);
                    
                    if age > obj.MaxTrackAge
                        
                        obj.activeTrackIDs(obj.activeTrackIDs == chkStop(iChk)) = [];
                        %obj.activeTrackIDs(iSol) = [];
                        
                    end
                end
            end
            
        end
        
        function [obj, newTrackID] = splitTrack(obj, trackID, frameToSplit)
            
            %Split the tracks
            [obj.tracks, newTrackID] = splitTrack(obj.tracks, trackID, frameToSplit);
            
            %Update the active track list
            obj.activeTrackIDs(end + 1) = newTrackID;
            
        end
        
        function obj = updateMetadata(obj, varargin)
            %UPDATEMETADATA  Update the metadata struct
            %
            %  OBJ = UPDATEMETADATA(OBJ, PARAM1, VALUE1, ... PARAMN,
            %  VALUEN) updates the 'FileMetadata' property of the track
            %  array. PARAM1...N should be strings containing the name of
            %  the metadata field. The corresponding field values should be
            %  provided in VALUE1...N. There should be the same number of
            %  values as parameter names.
            %
            %  The intent is of this function is to allow file specific
            %  metadata to be saved (e.g. filename, pixel size, image size
            %  etc.).
            %
            %  Note: Property names must be allowed by MATLAB, i.e. must
            %  start with a letter and contain no special characters apart
            %  from underscore.
                        
            if rem(numel(varargin), 2) ~= 0
                error('LAPLinker:updateMetadata:UnmatchedParamValuePair', ...
                    'Expected input should be matched parameter/value pairs.');                
            end
            
            obj.tracks = setFileMetadata(obj.tracks, varargin{:});
            
        end
        
        function exportsettings(obj, varargin)
            %EXPORTSETTINGS  Write tracking properties to text file
            %
            %  EXPORTSETTINGS(OBJ) will create a dialog box allowing the
            %  user to select where to save the output file. The settings
            %  of the object are the object properties, except for track
            %  data and file metadata.
            %
            %  As an alternative, EXPORTSETTINGS(OBJ, FILE) will write the
            %  settings to the specified FILE.
            %
            %  See also: LAPLinker/importsettings
            
            if isempty(varargin)
                
                [file, fpath] = uiputfile({'*.txt', '*.txt (Text file)'}, ...
                    'Select output file');
                
                if isequal(file, 0) || isequal(fpath, 0)
                    return;
                end
                
                fileOut = fullfile(fpath, file);
                
            else
                
                fileOut = varargin{1};                
                
            end
                        
            %Get a list of object properties
            props = properties(obj);
            
            %Exclude data properties
            props(ismember(props, {'tracks', 'isTrackActive', 'NumTracks'})) = [];
            
            fid = fopen(fileOut, 'w');
            
            if fid == -1
                error('LAPLinker:exportsettings:CouldNotOpenFileToWrite', ...
                    'Could not open file %s to write.', ...
                    fileout);
            end
            
            fprintf(fid, '%% %s\n', datestr(now));
            
            for iP = 1:numel(props)
                
                switch lower(class(obj.(props{iP})))
                    
                    case 'char'
                
                        settingVal = sprintf('''%s''', obj.(props{iP}));
                        
                    case 'logical'
                        
                        if obj.(props{iP})
                            
                            settingVal = 'true';
                            
                        else
                            
                            settingVal = 'false';
                            
                        end
                        
                    case 'double'
                        
                        settingVal = mat2str(obj.(props{iP}));
                        
                end
                
                fprintf(fid, '%s: %s\n', props{iP}, settingVal);
                
            end
            
            fclose(fid);
            
        end
        
        function obj = importsettings(obj, varargin)
            %IMPORTSETTINGS  Import settings from text file
            %
            %  IMPORTSETTINGS(OBJ) will create a dialog box allowing the
            %  user to select which settings file to read. The settings
            %  of the object are the object properties, except for track
            %  data and file metadata.
            %
            %  As an alternative, IMPORTSETTINGS(OBJ, FILE) will read the
            %  settings from a specified FILE.
            %
            %  See also: LAPLinker/EXPORTSETTINGS
            
            if isempty(varargin)
                
                [file, fpath] = uigetfile({'*.txt', '*.txt (Text file)'}, ...
                    'Select file');
                
                if isequal(file, 0) || isequal(fpath, 0)
                    return;
                end
                
                fileIn = fullfile(fpath, file);
                
            else
                
                if ~exist(varargin{1}, 'file')
                    error('LAPLinker:importsettings:InvalidFile', ...
                        '%s was not found.', ...
                        varargin{1});                    
                end
                
                fileIn = varargin{1};                
                
            end
            
            fid = fopen(fileIn, 'r');
            
            if fid == -1
                error('LAPLinker:importsettings:CouldNotOpenFileToRead', ...
                    'Could not open file %s to read.', ...
                    fileout);
            end
            
            %Get a list of valid object properties
            props = properties(obj);
            
            %Exclude data properties
            props(ismember(props, {'tracks', 'isTrackActive', 'NumTracks'})) = [];
            
            while ~feof(fid)
                
                currLine = fgetl(fid);
                
                if strcmpi(currLine(1), '%')
                    %Skip comments
                    
                    %TODO SKIP NEWLINES
                    
                else
                    
                    input = strsplit(currLine, ':');
                    
                    if ismember(input{1}, props)
                        obj.(input{1}) = eval(input{2});
                        
                    else
                        
                        %Skip
                    
                    end
                    
                end
                
                
                
            end
            
            
            fclose(fid);
            
            
        end
        
        function [obj, newTrackID] = startTrack(obj, frame, dataIn)
            %OBJ = NEWTRACK(OBJ, FIRSTFRAME, DATA) creates a new track
            %entry in the data structure. FIRSTFRAME should be the frame
            %number of the first frame for the track. 
            %
            %DATA should be a struct with fields containing the measured
            %properties for the track (e.g. similar to the output of
            %regionprops). If DATA is a struct array, the number of tracks
            %created will be the same as the number of array elements.
            %
            %The resulting track data is stored as a cell array in the
            %'tracks' property of the object. Tracks will always contain
            %the fields 'Frame', 'MotherInd', and 'DaughterInd'. New tracks
            %cannot have 'Frame' as a data property.
            
            %Create new track
            [obj.tracks, newTrackID] = addTrack(obj.tracks, frame, dataIn);
            
            %Update the active track list
            obj.activeTrackIDs((end + 1):(end + numel(newTrackID))) = newTrackID;
            
        end
        
        function obj = updateTrack(obj, trackInd, frames, dataIn)
            %UPDATETRACK  Modify track data
            %
            %  OBJ = UPDATETRACK(OBJ, TRACK, FRAME, DATA) inserts data into
            %  the tracks struct. The insertion is sorted, i.e. the data is
            %  inserted such that the track's Frame field is sequentially
            %  increasing.
            %
            %  This function is primarily used during track assignment to
            %  add data to existing tracks. However, the function can also
            %  be used if manual correction of specific tracks/frames are
            %  necessary.
            %
            %  Examples:
            %  %Update the 'Centroid' field in frame 3 of track 5 
            %  OBJ = UPDATETRACK(OBJ, 5, 3, struct('Centroid', [10, 3]));
            
            obj.tracks = updateTrack(obj.tracks, trackInd, frames, dataIn);
            
        end
        
        function track = getTrack(obj, trackID)
            
            track = getTrack(obj.tracks, trackID);
            
        end

    end
    
    methods (Access = private, Hidden = true, Static)
        
        function cost = computecost(lastTrackData, newData, method)
            %COMPUTECOST  Compute the cost to link tracks
            %
            %  COMPUTECOST(TRACK, DET, METHOD) computes the cost of
            %  linking new detections DET to existing tracks TRACK.
            %  newData must be a cell. Parameters as columns, observations
            %  as rows
            %
            %  The current METHODs supported are:
            %   'euclidean' - sqrt(sum((A - D).^2))
            %   'pxintersect' - Number of overlapping pixels (the input
            %   data should have 'PixelIdxList')
            
            switch lower(method)
                
                case 'euclidean'
                    
                    %Number of elements in lastTrackData must match number
                    %of columns in newData
                    if numel(newData{1}) ~= numel(lastTrackData)
                        error('LAPLinker:computecost:EuclideanNumParamMismatch', ...
                            'For euclidean distance, the number of parameters for the new data must match the number of parameters of the track.');
                    end
                    
                    %Convert the cell into a matrix
                    newData = cell2mat(newData');
                    
                    cost = sqrt(sum((newData - lastTrackData).^2, 2))';
                    
                case 'pxintersect'
                    
                    cost = 1:numel(newData);
                    for ii = 1:numel(newData)
                        cost(ii) = numel(union(newData{ii}, lastTrackData)) / ...
                            numel(intersect(newData{ii}, lastTrackData));
                    end
                    
                    %cost = cellfun(@(x) numel(union(x, lastTrackData))/numel(intersect(x, lastTrackData)), newData, 'UniformOutput', true);
                    
                otherwise
                    
                    %Call custom function (must be on path)
                    %Function pattern = func(lastTrackData, newData)
                    
                    cost = eval(sprintf('%s(lastTrackData, newData)', method));
                    
            end
                        
        end
        
        function [rowsol, mincost, unassigned_cols] = munkres(costMatrix)
            %MUNKRES  Munkres (Hungarian) linear assignment
            %
            %  [I, C] = MUNKRES(M) returns the column indices I assigned to each row,
            %  and the minimum cost C based on the assignment. The cost of the
            %  assignments are given in matrix M, with workers along the rows and tasks
            %  along the columns. The matrix optimizes the assignment by minimizing the
            %  total cost.
            %
            %  The code can deal with partial assignments, i.e. where M is not a square
            %  matrix. Unassigned rows (workers) will be given a value of 0 in the
            %  output I. [I, C, U] = MUNKRES(M) will give the index of unassigned
            %  columns (tasks) in vector U.
            %
            %  The algorithm attempts to speed up the process in the case where values
            %  of a row or column are all Inf (i.e. impossible link). In that case, the
            %  row or column is excluded from the assignment process; these will be
            %  automatically unassigned in the result.
            %
            %  This code is based on the algorithm described at:
            %  http://csclab.murraystate.edu/bob.pilgrim/445/munkres.html
            
            %Get the size of the matrix
            [nORows, nOCols] = size(costMatrix);
            
            %Check for rows and cols which are all infinity, then remove them
            validRows = ~all(costMatrix == Inf,2);
            validCols = ~all(costMatrix == Inf,1);
            
            nRows = sum(validRows);
            nCols = sum(validCols);
            
            nn = max(nRows,nCols);
            
            if nn == 0
                error('Invalid cost matrix: Cannot be all Inf.')
            elseif any(isnan(costMatrix(:))) || any(costMatrix(:) < 0)
                error('Invalid cost matrix: Expected costs to be all positive numbers.')
            end
            
            %Make a new matrix
            tempCostMatrix = ones(nn) .* (10 * max(max(costMatrix(costMatrix ~= Inf))));
            tempCostMatrix(1:nRows,1:nCols) = costMatrix(validRows,validCols);
            
            tempCostMatrix(tempCostMatrix == Inf) = realmax;
            
            %Get the minimum values of each row
            rowMin = min(tempCostMatrix,[],2);
            
            %Subtract the elements in each row with the corresponding minima
            redMat = bsxfun(@minus,tempCostMatrix,rowMin);
            
            %Mask matrix (0 = not a zero, 1 = starred, 2 = primed)
            mask = zeros(nn);
            
            %Vectors of column and row numbers
            rowNum = 1:nn;
            colNum = rowNum;
            
            %Row and column covers (1 = covered, 0 = uncovered)
            rowCover = zeros(1,nn);
            colCover = rowCover;
            
            %Search for unique zeros (i.e. only one starred zero should exist in each
            %row and column
            for iRow = rowNum(any(redMat,2) == 0)
                for iCol = colNum(any(redMat(iRow,:) == 0))
                    if (redMat(iRow,iCol) == 0 && rowCover(iRow) == 0 && colCover(iCol) == 0)
                        mask(iRow,iCol) = 1;
                        rowCover(iRow) = 1;
                        colCover(iCol) = 1;
                    end
                end
            end
            
            %Clear the row cover
            rowCover(:) = 0;
            
            %The termination condition is when each column has a single starred zero
            while ~all(colCover)
                
                %---Step 4: Prime an uncovered zero---%
                %Find a non-covered zero and prime it.
                %If there is no starred zero in the row containing this primed zero,
                %proceed to step 5.
                %Otherwise, cover this row and uncover the column contianing the
                %starred zero.
                %Continue until there are no uncovered zeros left. Then get the minimum
                %value and proceed to step 6.
                
                stop = false;
                
                %Find an uncovered zero
                for iRow = rowNum( (any(redMat == 0,2))' & (rowCover == 0) )
                    for iCol = colNum(redMat(iRow,:) == 0)
                        
                        if (redMat(iRow,iCol) == 0) && (rowCover(iRow) == 0) && (colCover(iCol) == 0)
                            mask(iRow,iCol) = 2;    %Prime the zero
                            
                            if any(mask(iRow,:) == 1)
                                rowCover(iRow) = 1;
                                colCover(mask(iRow,:) == 1) = 0;
                            else
                                
                                %Step 5: Augment path algorithm
                                currCol = iCol; %Initial search column
                                storePath = [iRow, iCol];
                                
                                %Test if there is a starred zero in the current column
                                while any(mask(:,currCol) == 1)
                                    %Get the (row) index of the starred zero
                                    currRow = find(mask(:,currCol) == 1);
                                    
                                    storePath = [storePath; currRow, currCol];
                                    
                                    %Find the primed zero in this row (there will
                                    %always be one)
                                    currCol = find(mask(currRow,:) == 2);
                                    
                                    storePath = [storePath; currRow, currCol];
                                end
                                
                                %Unstar each starred zero, star each primed zero in the
                                %searched path
                                indMask = sub2ind([nn,nn],storePath(:,1),storePath(:,2));
                                mask(indMask) = mask(indMask) - 1;
                                
                                %Erase all primes
                                mask(mask == 2) = 0;
                                
                                %Uncover all rows
                                rowCover(:) = 0;
                                
                                %Step 3: Cover the columns with stars
                                colCover(:) = any((mask == 1),1);
                                
                                stop = true;
                                break;
                            end
                        end
                        
                        %---Step 6---
                        
                        %Find the minimum uncovered value
                        minUncVal = min(min(redMat(rowCover == 0,colCover== 0)));
                        
                        %Add the value to every element of each covered row
                        redMat(rowCover == 1,:) = redMat(rowCover == 1,:) + minUncVal;
                        
                        %Subtract it from every element of each uncovered column
                        redMat(:,colCover == 0) = redMat(:,colCover == 0) - minUncVal;
                    end
                    
                    if (stop)
                        break;
                    end
                end
                
            end
            
            %Assign the outputs
            rowsol = zeros(nORows,1);
            mincost = 0;
            
            unassigned_cols = 1:nCols;
            
            validRowNum = 1:nORows;
            validRowNum(~validRows) = [];
            
            validColNum = 1:nOCols;
            validColNum(~validCols) = [];
            
            %Only assign valid workers
            for iRow = 1:numel(validRowNum)
                
                assigned_col = colNum(mask(iRow,:) == 1);
                
                %Only assign valid tasks
                if assigned_col > numel(validColNum)
                    %Assign the output
                    rowsol(validRowNum(iRow)) = 0;
                else
                    rowsol(validRowNum(iRow)) = validColNum(assigned_col);
                    
                    %         %Calculate the optimized (minimized) cost
                    mincost = mincost + costMatrix(validRowNum(iRow),validColNum(assigned_col));
                    
                    unassigned_cols(unassigned_cols == assigned_col) = [];
                end
            end
        end
        
        function [rowsol, mincost, v, u, costMat] = lapjv(costMat,resolution)
            % LAPJV  Jonker-Volgenant Algorithm for Linear Assignment Problem.
            %
            % [ROWSOL,COST,v,u,rMat] = LAPJV(COSTMAT, resolution) returns the optimal column indices,
            % ROWSOL, assigned to row in solution, and the minimum COST based on the
            % assignment problem represented by the COSTMAT, where the (i,j)th element
            % represents the cost to assign the jth job to the ith worker.
            % The second optional input can be used to define data resolution to
            % accelerate speed.
            % Other output arguments are:
            % v: dual variables, column reduction numbers.
            % u: dual variables, row reduction numbers.
            % rMat: the reduced cost matrix.
            %
            % For a rectangular (nonsquare) costMat, rowsol is the index vector of the
            % larger dimension assigned to the smaller dimension.
            %
            % [ROWSOL,COST,v,u,rMat] = LAPJV(COSTMAT,resolution) accepts the second
            % input argument as the minimum resolution to differentiate costs between
            % assignments. The default is eps.
            %
            % Known problems: The original algorithm was developed for integer costs.
            % When it is used for real (floating point) costs, sometime the algorithm
            % will take an extreamly long time. In this case, using a reasonable large
            % resolution as the second arguments can significantly increase the
            % solution speed.
            %
            % version 3.0 by Yi Cao at Cranfield University on 10th April 2013
            %
            % This Matlab version is developed based on the orginal C++ version coded
            % by Roy Jonker @ MagicLogic Optimization Inc on 4 September 1996.
            % Reference:
            % R. Jonker and A. Volgenant, "A shortest augmenting path algorithm for
            % dense and spare linear assignment problems", Computing, Vol. 38, pp.
            % 325-340, 1987.
            %
            %
            % Examples
            % Example 1: a 5 x 5 example
            %{
                    [rowsol,cost] = lapjv(magic(5));
                    disp(rowsol); % 3 2 1 5 4
                    disp(cost);   %15
            %}
            % Example 2: 1000 x 1000 random data
            %{
                    n=1000;
                    A=randn(n)./rand(n);
                    tic
                    [a,b]=lapjv(A);
                    toc                 % about 0.5 seconds
            %}
            % Example 3: nonsquare test
            %{
                    n=100;
                    A=1./randn(n);
                    tic
                    [a,b]=lapjv(A);
                    toc % about 0.2 sec
                    A1=[A zeros(n,1)+max(max(A))];
                    tic
                    [a1,b1]=lapjv(A1);
                    toc % about 0.01 sec. The nonsquare one can be done faster!
                    %check results
                    disp(norm(a-a1))
                    disp(b-b)
            %}
            
            if nargin<2
                maxcost=min(1e16,max(max(costMat)));
                resolution=eps(maxcost);
            end
            
            % Prepare working data
            [rdim,cdim] = size(costMat);
            M=min(min(costMat));
            if rdim>cdim
                costMat = costMat';
                [rdim,cdim] = size(costMat);
                swapf=true;
            else
                swapf=false;
            end
            
            dim=cdim;
            costMat = [costMat;2*M+zeros(cdim-rdim,cdim)];
            costMat(costMat~=costMat)=Inf;
            maxcost=max(costMat(costMat<Inf))*dim+1;
            
            if isempty(maxcost)
                maxcost = Inf;
            end
            
            costMat(costMat==Inf)=maxcost;
            % free = zeros(dim,1);      % list of unssigned rows
            % colist = 1:dim;         % list of columns to be scaed in various ways
            % d = zeros(1,dim);       % 'cost-distance' in augmenting path calculation.
            % pred = zeros(dim,1);    % row-predecessor of column in augumenting/alternating path.
            v = zeros(1,dim);         % dual variables, column reduction numbers.
            rowsol = zeros(1,dim)-1;  % column assigned to row in solution
            colsol = zeros(dim,1)-1;  % row assigned to column in solution
            
            numfree=0;
            free = zeros(dim,1);      % list of unssigned rows
            matches = zeros(dim,1);   % counts how many times a row could be assigned.
            
            % The Initilization Phase
            % column reduction
            for j=dim:-1:1 % reverse order gives better results
                % find minimum cost over rows
                [v(j), imin] = min(costMat(:,j));
                if ~matches(imin)
                    % init assignement if minimum row assigned for first time
                    rowsol(imin)=j;
                    colsol(j)=imin;
                elseif v(j)<v(rowsol(imin))
                    j1=rowsol(imin);
                    rowsol(imin)=j;
                    colsol(j)=imin;
                    colsol(j1)=-1;
                else
                    colsol(j)=-1; % row already assigned, column not assigned.
                end
                matches(imin)=matches(imin)+1;
            end
            
            % Reduction transfer from unassigned to assigned rows
            for i=1:dim
                if ~matches(i)      % fill list of unaasigned 'free' rows.
                    numfree=numfree+1;
                    free(numfree)=i;
                else
                    if matches(i) == 1 % transfer reduction from rows that are assigned once.
                        j1 = rowsol(i);
                        x = costMat(i,:)-v;
                        x(j1) = maxcost;
                        v(j1) = v(j1) - min(x);
                    end
                end
            end
            
            % Augmenting reduction of unassigned rows
            loopcnt = 0;
            while loopcnt < 2
                loopcnt = loopcnt + 1;
                % scan all free rows
                % in some cases, a free row may be replaced with another one to be scaed next
                k = 0;
                prvnumfree = numfree;
                numfree = 0;    % start list of rows still free after augmenting row reduction.
                while k < prvnumfree
                    k = k+1;
                    i = free(k);
                    % find minimum and second minimum reduced cost over columns
                    x = costMat(i,:) - v;
                    [umin, j1] = min(x);
                    x(j1) = maxcost;
                    [usubmin, j2] = min(x);
                    i0 = colsol(j1);
                    if usubmin - umin > resolution
                        % change the reduction of the minmum column to increase the
                        % minimum reduced cost in the row to the subminimum.
                        v(j1) = v(j1) - (usubmin - umin);
                    else % minimum and subminimum equal.
                        if i0 > 0 % minimum column j1 is assigned.
                            % swap columns j1 and j2, as j2 may be unassigned.
                            j1 = j2;
                            i0 = colsol(j2);
                        end
                    end
                    % reassign i to j1, possibly de-assigning an i0.
                    rowsol(i) = j1;
                    colsol(j1) = i;
                    if i0 > 0 % ,inimum column j1 assigned easier
                        if usubmin - umin > resolution
                            % put in current k, and go back to that k.
                            % continue augmenting path i - j1 with i0.
                            free(k)=i0;
                            k=k-1;
                        else
                            % no further augmenting reduction possible
                            % store i0 in list of free rows for next phase.
                            numfree = numfree + 1;
                            free(numfree) = i0;
                        end
                    end
                end
            end
            
            % Augmentation Phase
            % augment solution for each free rows
            for f=1:numfree
                freerow = free(f); % start row of augmenting path
                % Dijkstra shortest path algorithm.
                % runs until unassigned column added to shortest path tree.
                d = costMat(freerow,:) - v;
                pred = freerow(1,ones(1,dim));
                collist = 1:dim;
                low = 1; % columns in 1...low-1 are ready, now none.
                up = 1; % columns in low...up-1 are to be scaed for current minimum, now none.
                % columns in up+1...dim are to be considered later to find new minimum,
                % at this stage the list simply contains all columns.
                unassignedfound = false;
                while ~unassignedfound
                    if up == low    % no more columns to be scaned for current minimum.
                        last = low-1;
                        % scan columns for up...dim to find all indices for which new minimum occurs.
                        % store these indices between low+1...up (increasing up).
                        minh = d(collist(up));
                        up = up + 1;
                        for k=up:dim
                            j = collist(k);
                            h = d(j);
                            if h<=minh
                                if h<minh
                                    up = low;
                                    minh = h;
                                end
                                % new index with same minimum, put on index up, and extend list.
                                collist(k) = collist(up);
                                collist(up) = j;
                                up = up +1;
                            end
                        end
                        % check if any of the minimum columns happens to be unassigned.
                        % if so, we have an augmenting path right away.
                        for k=low:up-1
                            if colsol(collist(k)) < 0
                                endofpath = collist(k);
                                unassignedfound = true;
                                break
                            end
                        end
                    end
                    if ~unassignedfound
                        % update 'distances' between freerow and all unscanned columns,
                        % via next scanned column.
                        j1 = collist(low);
                        low=low+1;
                        i = colsol(j1); %line 215
                        x = costMat(i,:)-v;
                        h = x(j1) - minh;
                        xh = x-h;
                        k=up:dim;
                        j=collist(k);
                        vf0 = xh<d;
                        vf = vf0(j);
                        vj = j(vf);
                        vk = k(vf);
                        pred(vj)=i;
                        v2 = xh(vj);
                        d(vj)=v2;
                        vf = v2 == minh; % new column found at same minimum value
                        j2 = vj(vf);
                        k2 = vk(vf);
                        cf = colsol(j2)<0;
                        if any(cf) % unassigned, shortest augmenting path is complete.
                            i2 = find(cf,1);
                            endofpath = j2(i2);
                            unassignedfound = true;
                        else
                            i2 = numel(cf)+1;
                        end
                        % add to list to be scaned right away
                        for k=1:i2-1
                            collist(k2(k)) = collist(up);
                            collist(up) = j2(k);
                            up = up + 1;
                        end
                    end
                end
                % update column prices
                j1=collist(1:last+1);
                v(j1) = v(j1) + d(j1) - minh;
                % reset row and column assignments along the alternating path
                while 1
                    i=pred(endofpath);
                    colsol(endofpath)=i;
                    j1=endofpath;
                    endofpath=rowsol(i);
                    rowsol(i)=j1;
                    if (i==freerow)
                        break
                    end
                end
            end
            
            rowsol = rowsol(1:rdim);
            u=diag(costMat(:,rowsol))-v(rowsol)';
            u=u(1:rdim);
            v=v(1:cdim);
            mincost = sum(u)+sum(v(rowsol));
            costMat=costMat(1:rdim,1:cdim);
            costMat = costMat - u(:,ones(1,cdim)) - v(ones(rdim,1),:);
            
            if swapf
                costMat = costMat';
                t=u';
                u=v';
                v=t;
            end
            
            if mincost>maxcost
                mincost=Inf;
            end
            
        end
        
    end
        
end