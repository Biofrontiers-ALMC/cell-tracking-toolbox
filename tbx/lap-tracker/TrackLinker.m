classdef TrackLinker
    %TRACKLINKER  Associates tracks using the linear assignment framework
    
    properties  %List of tracking parameters
       
        %Track linking parameters
        LinkedBy = 'Centroid';
        LinkCalculation = 'euclidean';
        LinkingScoreRange = [-Inf, Inf];
        MaxTrackAge = 2;
        
        %Mitosis detection parameters
        TrackMitosis = true;
        MinAgeSinceMitosis = 2;
        MitosisParameter = 'PixelIdxList';          %What property is used for mitosis detection?
        MitosisCalculation = 'pxintersect';
        MitosisScoreRange = [-Inf, Inf];
        MitosisLinkToFrame = -1;                    %What frame to link to/ This should be 0 for centroid/nearest neighbor or -1 for overlap (e.g. check with mother cell)
        
        %LAP solver
        LAPSolver = 'lapjv';
       
    end
   
    properties (SetAccess = private, Hidden)  %Track data
        
        TrackArray = TrackDataArray;
        
        activeTracks = struct('trackIdx',{},...
            'Age',{},...
            'AgeSinceDivision',{});
        
    end
    
    properties (Access = private, Hidden)
        
        reqProperties = {};
        
        %Changes from false to true whenever a track operation is carried.
        %This property is used to determine whether:
        %  * Genealogy has changed and should be re-calculated
        %  * 
        tracksModified = true;
        
        LAPtrackerVersion = '1.0.0';
        reqCelltrackVersion = '1.0.0';
        
    end
    
    properties (Dependent, Hidden)
        
        NumTracks;
        
    end
    
    methods
        
        function obj = TrackLinker(varargin)
            %TRACKLINKER  Constructor function
            %
            %  LinkerObj = TRACKLINKER will create a TrackLinker object.
            %
            %  LinkerObj = TRACKLINKER(1, inputData) will initialize the
            %  new object with input data at frame 1.
            
            if nargin > 0
                
                ip = inputParser;
                ip.addRequired('frameIndex',@(x) isnumeric(x) && isscalar(x));
                ip.addOptional('frameData', '', @(x) isstruct(x));
                ip.KeepUnmatched = true; %For backwards compatibility, also allow parameter/value entries
                ip.parse(varargin{:});
                
                switch isempty(ip.Results.frameData)
                    
                    case true
                        %Check if there is data in the 'Unmatched' field
                        if ~isempty(ip.Unmatched)
                            
                            %Convert the unmatched data to a structure
                            dataFields = fieldnames(ip.Unmatched);
                            for iFields = 1:numel(dataFields)
                                for iElem = 1:size(ip.Unmatched.(dataFields{iFields}),1)
                                    frameData(iElem).(dataFields{iFields}) = ip.Unmatched.(dataFields{iFields})(iElem);
                                end                                
                            end
                        end
                        
                    case false
                        %Input is a struct. Create a new Track for each
                        %entry.
                        frameData = ip.Results.frameData;
                        
                end
                
                obj = obj.CreateNewTrack(ip.Results.frameIndex,...
                    frameData);
                
            end
            
        end
        
        function obj = assignToTrack(obj, frameIndex, newData, varargin)
            %ASSIGNTOTRACK  Assigns newly detected objects to tracks
            %
            %  L = L.ASSIGNTOTRACK(I, D) will assign the new object data D
            %  to existing or new tracks.
            %
            %  L = L.ASSIGNTOTRACK(I, D, 'nonewtracks') will assign the new
            %  object data D to existing tracks only, ignoring new tracks.
                        
            %Check if data is empty. If it is, then do not assign but
            %create new tracks
            if numel(obj.TrackArray) == 0
                
                obj = obj.CreateNewTrack(frameIndex,...
                    newData);
                
            end
            
            %Make the cost matrix
            costMatrix = obj.MakeCostMatrix(newData);
            
            %Solve the assignment problem
            assignments = TrackLinker.lapjv(costMatrix);
            
            %Handle the assignments
            nTracks = numel(obj.activeTracks);
            nNewData = numel(newData);
            
            for iM = 1:nTracks
                if assignments(iM) > 0 && assignments(iM) <= nNewData
                    %If an existing track was assigned to a new detection,
                    %then update its current position
                    obj.TrackArray = obj.TrackArray.updateTrack(obj.activeTracks(iM).trackIdx,...
                        frameIndex, newData(assignments(iM)));
                    obj.activeTracks(iM).Age = 0;
                    
                else
                    %If the track was not assigned to a new detection, then
                    %increase its age
                    obj.activeTracks(iM).Age = obj.activeTracks(iM).Age + 1;
                    
                end
            end
            
            %Remove tracks which have not been updated for a long time
            obj.activeTracks([obj.activeTracks.Age] >= obj.MaxTrackAge) = [];
            
            %Second set of assignments are 'start segments'
            for iN = 1:nNewData
                
                newAssignment = assignments(nTracks + iN);
                
                if  newAssignment > 0 && newAssignment <= nNewData
                    
                    %Test for cell division
                    if obj.TrackMitosis
                        
                        %Calculate the mitosis score. The score is
                        %calculated using the current new detection, and
                        %looking for an existing track that has a cell
                        %nearby
                        mitosisScore = zeros(1, numel(obj.activeTracks));
                        for iCol = 1:numel(obj.activeTracks)
                            if obj.activeTracks(iCol).Age > 0
                                %If the track was not updated this frame, then it
                                %is not a valid mitosis event
                                mitosisScore(iCol) = Inf;
                            else
                                %Get the current active track
                                currTrack = obj.getTrack(obj.activeTracks(iCol).trackIdx);
                                
                                %If the track had a recent division, then it is not
                                %a valid mitosis event
                                if ~isnan(currTrack.MotherIdx) && (frameIndex - currTrack.FirstFrame) < obj.MinAgeSinceMitosis
                                    mitosisScore(iCol) = Inf;
                                else
                                    %Calculate the mitosis score using the
                                    %options set.
                                    if (currTrack.NumFrames + obj.MitosisLinkToFrame) < 1
                                        %Handle the case where there are
                                        %insufficient prior frames
                                        mitosisScore(iCol) = Inf;
                                    else
                                    
                                        try
                                            mitosisScore(iCol) = TrackLinker.computeScore(...
                                                newData(iN).(obj.MitosisParameter),...
                                                currTrack.Data(end + obj.MitosisLinkToFrame).(obj.MitosisParameter),...
                                                obj.MitosisCalculation);
                                        catch
                                            keyboard
                                        end
                                    end
                                end
                            end
                        end
                        
                        %Look for a valid mitosis event
                        validEvents = mitosisScore > obj.MitosisScoreRange(1) & mitosisScore < obj.MitosisScoreRange(2);

                        if ~any(validEvents)
                            isMitosis = false;
                        else
                            %Look for the lowest score - this indicates the
                            %closest match (distance or overlap)
                            closestMatch = find(mitosisScore == min(mitosisScore(validEvents)));
                            
                            %If it is a mitosis event:
                            %  (1) Create two new daughter tracks
                            %  (2) Update the MotherIdx in the daughter tracks
                            %  (3)
                            %  (2) Remove the last entry in the mother track
                            %  (3) Stop tracking the mother track (remove from
                            %     activeTracks)
                            %  (4) Update MotherIdx and daughterIdx for the
                            %  tracks
                            
                            %Get the mother track index
                            motherTrackIdx = obj.activeTracks(closestMatch).trackIdx;
                            motherTrack = obj.getTrack(obj.activeTracks(closestMatch).trackIdx);
                            
                            %Create a new daughter track using data from
                            %the end of the mother track
                            [obj, daughter1Idx] = obj.CreateNewTrack(frameIndex, motherTrack.Data(end));
                            obj.TrackArray = obj.TrackArray.updateMotherTrackIdx(daughter1Idx,motherTrackIdx);
                            
                            %Create a second daughter track with the new
                            %data
                            [obj, daughter2Idx] = obj.CreateNewTrack(frameIndex,newData(newAssignment));
                            obj.TrackArray = obj.TrackArray.updateMotherTrackIdx(daughter2Idx,motherTrackIdx);
                            
                            %Remove the last frame of the mother track
                            obj.TrackArray = obj.TrackArray.deleteFrame(motherTrackIdx,'last');
                            
                            %Update daughterIdx in mother track
                            obj.TrackArray = obj.TrackArray.updateDaughterTrackIdxs(motherTrackIdx,[daughter1Idx,daughter2Idx]);
                            
                            %Remove mother track from activeTracks
                            obj.activeTracks(closestMatch) = [];
                            
                            isMitosis = true;
                        end
                        
                    else
                        isMitosis = false;
                    end
                    
                    if ~isMitosis
                        %If not a mitosis event, create a new track
                        obj = obj.CreateNewTrack(frameIndex,newData(newAssignment));
                    end
                end
            end
            
        end
        
        function trackOut = getTrack(obj,trackIndex)
            %GETTRACK  Get the specified track
            %
            %  T = L.GETTRACK(I) gets track I from the TrackLinker object.
            
            trackOut = obj.TrackArray.getTrack(trackIndex);
            
        end
        
        function obj = setOptions(obj, varargin)
            %SETOPTIONS  Set options for the linker
            %
            %  linkerObj = linkerObj.SETOPTIONS(parameter, value) will set
            %  the parameter to value.
            %
            %  linkerObj = linkerObj.SETOPTIONS(O) where O is a data object
            %  with the same property names as the options will work.
            %
            %  linkerObj = linkerObj.SETOPTIONS(S) where S is a struct
            %  with the same fieldnames as the options will also work.
            %
            %  Non-matching parameter names will be ignored.
            
            if numel(varargin) == 1 && isstruct(varargin{1})
                %Parse a struct as input
                
                inputParameters = fieldnames(varargin{1});
                
                for iParam = 1:numel(inputParameters)
                    if ismember(inputParameters{iParam},properties(obj))
                        obj.(inputParameters{iParam}) = ...
                            varargin{1}.(inputParameters{iParam});
                    else
                        %Just skip unmatched options
                    end
                    
                end
                
            elseif numel(varargin) == 1 && isobject(varargin{1})
                %Parse an object as input
                
                inputParameters = properties(varargin{1});
                
                for iParam = 1:numel(inputParameters)
                    if ismember(inputParameters{iParam},properties(obj))
                        obj.(inputParameters{iParam}) = ...
                            varargin{1}.(inputParameters{iParam});
                    else
                        %Just skip unmatched options
                    end
                    
                end
                
            else
                if rem(numel(varargin),2) ~= 0
                    error('Input must be Property/Value pairs.');
                end
                inputArgs = reshape(varargin,2,[]);
                for iArg = 1:size(inputArgs,2)
                    if ismember(inputArgs{1,iArg},properties(obj))
                        
                        obj.(inputArgs{1,iArg}) = inputArgs{2,iArg};
                    else
                        %Just skip unmatched options
                    end
                end
            end
        end
        
        function obj = importOptions(obj, importFilename)
            %IMPORTOPTIONS  Import settings from file
            %
            %  S = L.IMPORTOPTIONS(filename) will import
            %  settings from the file specified.
            
            if ~exist('importFilename','var')
                
                [filename, pathname] = uigetfile({'*.txt','Text file (*.txt)';...
                    '*.*','All files (*.*)'},...
                    'Select output file location');
                
                importFilename = fullfile(pathname,filename);
                
            end
            
            fid = fopen(importFilename,'r');
            
            if fid == -1
                error('TrackLinker:importOptions:ErrorReadingFile',...
                    'Could not open file %s for reading.',filename);
            end
            
            while ~feof(fid)
                currLine = strtrim(fgetl(fid));
                
                if isempty(currLine)
                    %Empty lines should be skipped
                    
                elseif strcmpi(currLine(1),'%') || strcmpi(currLine(1),'#')
                    %Lines starting with '%' or '#' are comments, so ignore
                    %those
                    
                else
                    %Expect the input to be PARAM_NAME = VALUE
                    parsedLine = strsplit(currLine,'=');
                    
                    %Get parameter name (removing spaces)
                    parameterName = strtrim(parsedLine{1});
                    
                    %Get value name (removing spaces)
                    value = strtrim(parsedLine{2});
                    
                    if isempty(value)
                        %If value is empty, just use the default
                    else
                        obj = obj.setOptions(parameterName,eval(value));
                    end
                    
                end
                
            end
            
            fclose(fid);
        end
        
        function exportOptions(obj, exportFilename)
            %EXPORTOPTIONS  Export tracking options to a file
            %
            %  L.EXPORTOPTIONS(filename) will write the currently set
            %  options to the file specified. The options are written in
            %  plaintext, no matter what the extension of the file is.
            %
            %  L.EXPORTOPTIONS if the filename is not provided, a dialog
            %  box will pop-up asking the user to select a location to save
            %  the file.
                        
            if ~exist('exportFilename','var')
                
                [filename, pathname] = uiputfile({'*.txt','Text file (*.txt)'},...
                    'Select output file location');
                
                exportFilename = fullfile(pathname,filename);
                
            end
            
            fid = fopen(exportFilename,'w');
            
            if fid == -1
                error('FRETtrackerOptions:exportSettings:CouldNotOpenFile',...
                    'Could not open file to write')
            end
            
            propertyList = properties(obj);
            
            %Write output data depending on the datatype of the value
            for ii = 1:numel(propertyList)
                
                if ischar(obj.(propertyList{ii}))
                    fprintf(fid,'%s = ''%s'' \r\n',propertyList{ii}, ...
                        obj.(propertyList{ii}));
                    
                elseif isnumeric(obj.(propertyList{ii}))
                    fprintf(fid,'%s = %s \r\n',propertyList{ii}, ...
                        mat2str(obj.(propertyList{ii})));
                    
                elseif islogical(obj.(propertyList{ii}))
                    
                    if obj.(propertyList{ii})
                        fprintf(fid,'%s = true \r\n',propertyList{ii});
                    else
                        fprintf(fid,'%s = false \r\n',propertyList{ii});
                    end
                    
                end
                
            end
            
            fclose(fid);            
            
        end
       
        function numTracks = get.NumTracks(obj)
            numTracks = numel(obj.TrackArray);
        end
        
        function trackArray = getTrackArray(obj)
            %GETTRACKARRAY  Get track array
            %
            %  A = L.GETTRACKARRAY returns the track array object A
            %  containing the cell tracks.
            
            trackArray = obj.TrackArray;
            
        end
        
        function obj = setTimestampInfo(obj, timeVec, timeUnits)
            %SETTIMESTAMPINFO  Set timestamp information in the track array
            %
            %  L = L.SETTIMESTAMPINFO(T, U) sets the timestamp vector in
            %  the track array to T and the units to U. U should be a
            %  string.
            %
            %  Example:
            %
            %     bfr = BioformatsImage('data.nd2');
            %
            %     L = TrackLinker;
            %
            %     [T, U] = bfr.getTimestamps(1,1);
            %     L = L.SETTIMESTAMPINFO(T, U);
            
            obj.TrackArray = obj.TrackArray.setTimestampInfo(timeVec, timeUnits);
            
        end
        
        function obj = setPxSizeInfo(obj, pxSize, varargin)
            %SEXPXSIZEINFO  Set pixel size information in the track array
            %
            %  L = L.SEXPXSIZEINFO(T, U) sets the pixel size to T and the
            %  units to U. U should be a string, while T should be a 1x2 or
            %  1x1 double.
            %
            %  Example:
            %
            %     bfr = BioformatsImage('data.nd2');
            %
            %     L = TrackLinker;
            %
            %     [T, U] = bfr.pxSize(1,1);
            %     L = L.SETTIMESTAMPINFO(T, U);
            
            obj.TrackArray = obj.TrackArray.setPxSizeInfo(pxSize, varargin{:});
            
        end
        
        function obj = setImgSize(obj, imgSize)
            %SETIMGSIZE  Set image size in the track array
            %
            %  A = A.SETIMGSIZE([H W]) sets the image size property in the
            %  FileMetadata of the track array object.
            
            obj.TrackArray = obj.TrackArray.setImgSize(imgSize);  
            
        end
        
        function obj = setFilename(obj, fn)
            %SETFILENAME  Set the filename property of the TrackDataArray
            %
            %  L = L.SETFILENAME(F) will set the filename property of the
            %  TrackDataArray to F. 
            %
            %  Note: If the filename already exists, you will be prompted
            %  to confirm the change as this could affect data integrity.
            
            obj.TrackArray = obj.TrackArray.setFilename(fn);
            
        end
    end
    
    methods (Hidden)
        
        function [obj, newTrackId] = CreateNewTrack(obj, frameIndex, newTrackData)
            %CREATENEWTRACK  Creates a new track
            %
            %  L = L.CREATENEWTRACK(I, D) will create a new track, with a
            %  start frame at index I and data D. The new track will be
            %  added to the list of actively tracked objects.
            
            for iTrack = 1:numel(newTrackData)
                [obj.TrackArray, newTrackId] = obj.TrackArray.addTrack(frameIndex, newTrackData(iTrack));
                
                %Add to the actively tracked data
                newIdx = numel(obj.activeTracks) + 1;
                obj.activeTracks(newIdx).trackIdx = newTrackId;
                obj.activeTracks(newIdx).Age = 0;
                obj.activeTracks(newIdx).AgeSinceDivision = 0;
            end
            
        end
        
        function obj = StopTrack(obj, trackIndex)
            %STOPTRACK  Stops tracking a track
            %
            %  L = L.STOPTRACK(I) will stop tracking the track I.
           
            obj.activeTracks(trackIndex == [obj.activeTracks.trackIdx]) = [];
            
        end
        
        function costMat = MakeCostMatrix(obj, newTrackData)
            %MAKECOSTMATRIX  Calculates the LAP cost matrix
            %
            %  C = L.MAKECOSTMATRIX calculates the cost matrix C according
            %  to the Linear Assignment Problem (LAP) framework.
            %
            %  C has size (n + m) x (n + m) where n is the number of
            %  objects in frame T and m is the number of objects in frame T
            %  + 1. C can be divided into four quadrants: 
            %
            %  1. (Top-Left) has size n x m and contains the cost of
            %     linking an object in frame t to an object in frame t + 1.
            %  2. (Top-Right) has size n x n and contains the cost to stop
            %     tracking
            %  3. (Bottom-Left) has size m x m and contains the cost to
            %     start a new track
            %  4. (Bottom-Right) has size m x n and contains the auxiliary
            %     matrix
                        
            %Check that the new track data has the required field to link
            if ~ismember(obj.LinkedBy, fieldnames(newTrackData))
                error('TrackLinker:MakeCostMatrix:NewDataMissingLinkField',...
                    'Input data is missing the ''LinkedBy'' parameter: ''%s''',...
                    obj.LinkedBy);
            end
            
            %Calculate linking costs
            costToLink = zeros(numel(obj.activeTracks), numel(newTrackData));
            
            for iRow = 1:numel(obj.activeTracks)
                
                currTrack = obj.getTrack(obj.activeTracks(iRow).trackIdx);
                
                for iCol = 1:numel(newTrackData)
                    
                    costToLink(iRow, iCol) = TrackLinker.computeScore(...
                        currTrack.Data(end).(obj.LinkedBy), ...
                        newTrackData(iCol).(obj.LinkedBy), ...
                        obj.LinkCalculation);
                    
                end
            end
            
            %Assign linking costs which are too high or too low to the
            %blocking value (inf)
            costToLink(costToLink < obj.LinkingScoreRange (1) | costToLink > obj.LinkingScoreRange (2)) = Inf;
            
            maxCostToLink = max(costToLink(costToLink < Inf));
            
            %Costs for stopping
            stopCost = diag(1.05 * maxCostToLink * ones(1,numel(obj.activeTracks)));
            stopCost(stopCost == 0) = Inf;
            
            %Cost to start a new segment
            segStartCost = diag(1.05 * maxCostToLink * ones(1,numel(newTrackData)));
            segStartCost(segStartCost == 0) = Inf;
            
            %Auxiliary matrix
            auxMatrix = costToLink';
            auxMatrix(auxMatrix < Inf) = min(costToLink(costToLink < Inf));
            
            %Assemble the full cost matrix
            costMat = [costToLink, stopCost; segStartCost, auxMatrix];

        end
        
    end
     
    methods (Static)
        
        function score = computeScore(input1, input2, type)
            %COMPUTESCORE  Computes the score between two inputs
            %
            %  S = TrackLinker.COMPUTESCORE(A, B, type) will compute the
            %  score between A and B. The type of computation depends on
            %  the specified parameter.
            %
            %  'Type' can be {'Euclidean', 'PxIntersect'}
            
            switch lower(type)
                
                case 'euclidean'
                    
                    %Note: MATLAB should error out if the vectors are not
                    %the same size etc.
                    score = sqrt(sum((input1 - input2).^2,2));
                    
                case 'pxintersect'
                    %Check that the two inputs are both cell arrays of
                    %numbers
                    if isempty(input2)
%                         keyboard
                        score = Inf;
                        return;
                        
                    end
                    
                    if ~(isvector(input1) && isvector(input2))
                        error('TrackLinker:ComputeScorePxIntersect:InputsNotVector',...
                            'Both inputs must be a vector for ''PxIntersect''.');
                    end
                    
%                     try
                    %Calculate the number of intersecting pixels
                    %Note: the lowest value = 1 (perfect match)
                    score = 1/(nnz(intersect(input1,input2))/nnz(union(input1,input2)));
%                     catch
%                         keyboard
%                     end

                case 'pxintersectunique'
                    %Check that the two inputs are both cell arrays of
                    %numbers
                    if ~(isvector(input1) && isvector(input2))
                        error('TrackLinker:ComputeScorePxIntersect:InputsNotVector',...
                            'Both inputs must be a vector for ''PxIntersect''.');
                    end
                    
                    %Calculate the number of intersecting pixels
                    score = 1/(sum(ismember(input1,input2)) / numel(unique([input1,input2])));
                    
                otherwise 
                    error('TrackLinker:ComputeScore:UnknownType',...
                        '''%s'' is an unknown score type.',type)
            
            end
            
            
        end
        
    end
  
    methods (Access = private, Hidden = true, Static)   %LAP solvers
        
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