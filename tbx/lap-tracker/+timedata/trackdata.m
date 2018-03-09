classdef trackdata
    %TRACKDATA  Class for holding timeseries data for a single track
    %
    
    properties
        
        trackID(1, 1) uint32 = 0;
        seriesID(1, 1) uint32 = 0;
        motherTrackID(1, 1) uint32 = 0;
        daughterTrackIDs(1, 2) uint32 = [0 0];
                
    end
    
    properties (SetAccess = private)
       
        frames uint16
        data
        
    end
    
    properties (Dependent)
                
        firstFrame
        lastFrame
        numFrames
        
    end
    
    methods
        
        function obj = trackdata(varargin)
            %TRACKDATA  Constructor function for the trackdata class
            %
            %  T = TRACKDATA creates a (1-by-1) scalar trackdata object
            %  with default properties.
            %
            %  T = TRACKDATA(n) returns a 1-by-n trackdata object array.
            %
            %  T = TRACKDATA(n, property, value) returns a 1-by-n trackdata
            %  object array. The trackdata object properties will be
            %  populated using the property/value pair specified.
            %
            %  Example: 
            %    T = TRACKDATA(5, 'seriesID', 1) will return a 1-by-5
            %    trackdata object array. The 'seriesID' property of each
            %    object will be set to 1.
            
            if nargin ~= 0
                
                %Validate the input(s)
                if ~isnumeric(varargin{1}) || ~isscalar(varargin{1})
                    error('trackdata:InvalidSize', ...
                        'The size parameter must be numeric and scalar.');
                end
                
                %Initialize an empty array
                obj(varargin{1}) = timedata.trackdata;

                %If additional parameters exist, then treat them as
                %property assignments
                for iP = 2:2:(numel(varargin) - 1)
                    for iN = 1:numel(obj)
                        obj(iN).(varargin{iP}) = varargin{iP + 1};
                    end
                end
                
            end
            
            for iN = 1:numel(obj)
                obj(iN).trackID = iN; %#ok<AGROW>
            end
            
        end
        
        function firstFrame = get.firstFrame(obj)
            
            if isempty(obj.frames)
                firstFrame = Inf;
            else
                firstFrame = double(obj.frames(1));
            end            
            
        end
        
        function lastFrame = get.lastFrame(obj)
            
            if isempty(obj.frames)
                lastFrame = -Inf;
            else
                lastFrame = double(obj.frames(end));
            end
        end
        
        function numFrames = get.numFrames(obj)
            
            numFrames = double(obj.lastFrame - obj.firstFrame + 1);
             
        end
        
        function obj = addFrame(obj, tFrame, data, varargin)
            %ADDFRAME  Add data for a frame
            %
            %  T = T.ADDFRAME(f, dataStruct) adds a new frame at index f to
            %  the start or the end of the track. The frame data should be
            %  in a structure, with the fieldnames of the structure
            %  corresponding to the measured data property name.
            %
            %  If the new frame data has a new property that was not
            %  present in the previous frames, the value for the missing
            %  data will be empty ([]).
            %
            %  Example:
            %
            %    T = TrackData(1, struct('Area', 5));
            %
            %    %In frame 2, 'Area' is no longer measured, but 'Centroid'
            %    %is
            %    T = T.ADDFRAME(2, struct('Centroid', [10 20]));
            %
            %    %These are the expected outputs:
            %    T.Data(1).Area = 2
            %    T.Data(1).Centroid = []
            %
            %    T.Data(2).Area = []
            %    T.Data(2).Centroid = [10 20]
            
            %Validate the frame number
            if ~isnumeric(tFrame) || ~isscalar(tFrame)
                error('trackdata:addFrame:InvalidFrameIndex',...
                    'Expected frame index to be numeric and scalar.');
            end
            
            %Validate the input data
            if ~isstruct(data)
                error('trackdata:addFrame:DataNotStruct',...
                    'Expected input data to be a struct.');
            end
            
            %Check if the overwrite option is selected
            overwriteFlag = false;
            if ~isempty(varargin)
                if strcmpi(varargin{1}, 'overwrite')
                    overwriteFlag = true;
                end
            end
                        
            %Add the frame to the track
            if isinf(obj.firstFrame) && isinf(obj.lastFrame)
                %If both start and end frames are infinite, then this
                %is the first frame to be added
                obj.data = data;
                obj.frames = tFrame;
                
            elseif tFrame > obj.lastFrame
                
                    %Calculate the number of frames to add
                    numFramesToAdd = tFrame - obj.lastFrame;
                    
                    %Add the frame to the end of the array
                    obj.data(end + numFramesToAdd) = data;
                    
                    %Update the frame indices
                    obj.frames = obj.firstFrame:tFrame;
                
            elseif tFrame < obj.firstFrame
                
                %Overwrite the Data property with new frame data, then move
                %the old data to the end of the structure.
                oldData = obj.data;         %Save a copy of the old data
                obj.data = data;       %Overwrite the Data property
                
                %Move the old data to the end of the structure
                dataInd = obj.firstFrame - tFrame + 1;
                obj.data(dataInd:dataInd + numel(oldData) - 1) = oldData;
                
                %Update the frame indices
                obj.frames = tFrame:obj.lastFrame;
                
            else %tFrame > obj.firstFrame and tFrame < obj.lastFrame
                
                %If no data currently exists, then overwrite
                dataInd = tFrame - obj.firstFrame + 1;
                
                if all(structfun(@isempty, obj.data(dataInd))) || overwriteFlag
                    obj.data(dataInd) = data;
                else
                    error('trackdata:addFrame:FrameDataExists',...
                        'Data already exists at frame %d. Use the ''overwrite'' option to overwrite this data.',...
                        tFrame);
                end
                
            end
            
        end

        function obj = delFrame(obj, framesToDel)
            %DELFRAME  Deletes the specified frame
            %
            %  OBJ = DELFRAME(OBJ, F) will delete frame F from the
            %  trackdata object. F can be either a vector of frame indices
            %  to delete, or 'first' or 'last' to indicate whether the
            %  first or last frame respectively.
            %
            %  If T is an object array, frame F will be removed from each
            %  object in T. To delete a frame from a specific track,
            %  specify the track by indexing e.g. T(5) = DELFRAME(T(5), F).
            %
            %  The deletion will try to maintain the smallest variable size
            %  possible. For example, if F contains a sequence of numbers
            %  which connect to the first or last frame in the track, the
            %  data structure containing those frames will be shortened. 
            %
            %  Instead, if F specifies frames in the middle of the track,
            %  the data for those frames will be emptied (i.e. the data
            %  array will still exist, but the values are empty). This will
            %  allow these data points to be interpolated if necessary.
            %
            %  Examples:
            %
            %  If OBJ is a track containing data from frames 1 to 10:
            %
            %  OBJ = DELFRAME(OBJ, 1:3) will return a track that starts
            %  from frame 4 (i.e. OBJ.firstFrame = 4).
            %
            %  OBJ = DELFRAME(OBJ, 7:10) will return a track that stops
            %  at frame 6  (i.e. OBJ.lastFrame = 6).
            %
            %  OBJ = DELFRAME(OBJ, 7) will return a track that has the same
            %  length, but frame 7 will be empty.
            %
            
            for iTrack = 1:numel(obj)
                
                %Validate the frames to delete
                if isnumeric(framesToDel)
                    if ~(all(framesToDel >= obj(iTrack).firstFrame & framesToDel <= obj(iTrack).lastFrame))
                        warning('trackdata:delFrame:frameIndexInvalid',...
                                'Frame numbers to be deleted should be between %d (first frame) and %d (last frame).',...
                                obj(iTrack).firstFrame, obj(iTrack).lastFrame);
                        continue;
                    end
                    
                elseif ischar(tFrame)
                    
                    if strcmpi(framesToDel, 'first')
                        framesToDel = obj(iTrack).firstFrame;
                        
                    elseif strcmpi(framesToDel, 'last')
                        framesToDel = obj(iTrack).lastFrame;
                        
                    else
                        error('trackdata:delFrame:InvalidCharInput',...
                            'Expected the input to be ''first'' or ''last''');
                    end
                    
                else
                    error('trackdata:delFrame:InvalidInput',...
                        'Expected the frame index to be numerical,''first'' or ''last''');
                end
                
                %Sort the indices in descending order. This will ensure that
                %when deleting from the end of the array, the data will be
                %deleted sequentially (i.e. delFrame(T, 7:10) will make the new
                %first frame number = 6).
                %
                %A 'while' loop is in place to handle deletion of empty frames
                %when the indices are from the start. The reason I wrote the
                %code this way is to favor faster deletion from the end of the
                %track (which is performed during mitosis detection)
                framesToDel = sort(framesToDel, 'descend');
                
                %Convert the frame index into the index for the data array
                dataInd = framesToDel - obj(iTrack).firstFrame + 1;
                
                %Delete the data
                for iDel = 1:numel(framesToDel)
                    if framesToDel(iDel) == obj(iTrack).firstFrame
                        obj(iTrack).frames(1) = [];
                        obj(iTrack).data(1) = [];
                        
                        %Remove empty frames from the start
                        while all(structfun(@isempty ,obj(iTrack).data(1)))
                            obj(iTrack).frames(1) = [];
                            obj(iTrack).data(1) = [];
                        end
                        
                    elseif framesToDel(iDel) == obj(iTrack).lastFrame
                        obj(iTrack).frames(end) = [];
                        obj(iTrack).data(end) = [];
                        
                    else
                        
                        fn = fieldnames(obj(iTrack).data(dataInd(iDel)))';
                        fn{2, 1} = cell(1);
                        
                        %Make the data empty
                        obj(iTrack).data(dataInd(iDel)) = struct(fn{:});
                        
                    end
                end
            end
        end
        
        function newTrackdata = getFrame(obj, framesToGet)
            %GETFRAMES  Subset of time series samples
            %
            %  ST = GETFRAMES(T, F) returns a new trackdata object
            %  containing data from the specified frames. All other object
            %  properties (e.g. trackID, seriesID...) will be copied from
            %  the original object
            
            %Validate the input
            if isnumeric(framesToGet)
                if ~(all(framesToGet >= obj.firstFrame & framesToGet <= obj.lastFrame))
                    error('trackdata:getFrame:frameIndexInvalid',...
                        'Frame numbers to be deleted should be between %d (first frame) and %d (last frame).',...
                        obj.firstFrame, obj.lastFrame);
                end
                
            elseif ischar(tFrame)
                
                if strcmpi(framesToGet, 'first')
                    framesToGet = obj.firstFrame;
                    
                elseif strcmpi(framesToGet, 'last')
                    framesToGet = obj.lastFrame;
                    
                else
                    error('trackdata:getFrame:InvalidCharInput',...
                        'Expected the input to be ''first'' or ''last''');
                end
                
            else
                error('trackdata:getFrame:InvalidInput',...
                    'Expected the frame index to be numerical,''first'' or ''last''');
            end
            
            %Duplicate the object
            newTrackdata = obj;
            
            %Delete unwanted frames
            framesToDel = obj.firstFrame:obj.lastFrame;
            for iG = framesToGet
                framesToDel(framesToDel == iG) = [];
            end
            
            newTrackdata = delFrame(newTrackdata, framesToDel);
             
        end
        
        function structOut = track2struct(obj)
            %TRACK2STRUCT  Converts the trackdata object(s) into a struct
            %
            %  S = TRACK2STRUCT(OBJ) converts the object or object array
            %  into a MATLAB struct.

            strargs = properties(obj)';
            strargs{2,1} = cell(size(obj)); %Sets struct size
            
            %Initialize empty struct
            structOut = struct(strargs{:});
            
            for iTrack = 1:numel(obj)
                for iP = 1:size(strargs,2)
                    structOut(iTrack).(strargs{1, iP}) = obj(iTrack).(strargs{1, iP});
                end
            end
            
        end
        
        function export(obj, filename, varargin)
            %EXPORT  Export data as a separate data type
            %
            %  EXPORT(OBJ, FILENAME) will export the data in the track(s)
            %  in the data format specified by the filename extension.
            %
            %  EXPORT(OBJ, FILENAME, EXT) is an alternative way to specify
            %  a file format extension than is different than the filename.
            %  For example, EXPORT(OBJ, 'output.txt', 'csv') will write to
            %  output.txt but using the CSV format.
            %
            %  EXPORT(OBJ, FILENAME, 'append') will append the data to the
            %  specified file if it exists. By default, the code will
            %  overwrite a file if FILENAME exists.
            %
            %  EXPORT(OBJ, FILENAME, '-o') will cause the code to
            %  automatically overwrite FILENAME if it exists. By default,
            %  the code will prompt the user to confirm whether the
            %  existing file should be overwritten.
            
            %Set default file permissions to overwrite
            filePerm = 'w';
            
            %Should the user be prompted to overwrite the file?
            overwriteFlag = false;
            
            %Get the file extension from the filename
            [~, ~, fext] = fileparts(filename);
            
            %Parse the variable input
            while ~isempty(varargin)
                
                if strcmpi(varargin{1}, 'append')
                    %Change file permission to append
                    filePerm = 'a';
                elseif strcmpi(varargin{1}, '-o')
                    %Set autoOverwrite to true
                    overwriteFlag = true;                    
                else
                    fext = varargin{1};
                end
                
                varargin(1) = [];
            end
            
            %Check if the file currently exists
            fileExists = exist(filename,'file');
            
            if fileExists && (~overwriteFlag || ~strcmpi(filePerm,'a'))
                owi = input(sprintf('''%s'' already exists. Do you want to overwrite (Y = Yes)? ', filename),'s');
                
                if ~ismember(lower(owi), {'y', 'yes'})
                    error('trackdata:export:FileExists',...
                        'File exists. Please choose a different filename.');
                end
            end           
            
            %Strip any non-word/digits from the file extension
            fext = regexprep(fext, '\W*','');
            
            %Get the list of tracked data
            if ~isempty(obj(1).data)
                trackedData = fieldnames(obj(1).data);
            else
                trackedData = '';
            end
            
            switch lower(fext)
                
                case 'csv'
                    %CSV file definition
                    %
                    %  Headers: trackID, seriesID, motherTrackID,
                    %  daughterTrackIDs, Frame, [Tracked Data]
                    %
                    %  trackID, seriesID, motherTrackID, and
                    %  daughterTrackIDs are only populated for the first
                    %  line of a track.
                    
                    fid = fopen(filename, filePerm);
                    
                    if fid == -1
                        error('trackdata:export:ErrorOpeningFile',...
                            'Could not open ''%s''. Is it open in a different application?',...
                            filename);
                    end
                    
                    %Write the header unless appending to an existing file
                    if ~fileExists || ~strcmpi(filePerm, 'a')
                        fprintf(fid, 'trackID, seriesID, motherTrackID, daughterTrackIDs, Frame');
                        fprintf(fid, ', %s', trackedData{:});  %Write the tracked data fieldnames
                        fprintf(fid, '\n');
                    end
                    
                    for iTrack = 1:numel(obj)
                    
                        fprintf(fid, '%d, %d, %d, [%d %d]', ...
                            obj(iTrack).trackID, ...
                            obj(iTrack).seriesID, ...
                            obj(iTrack).motherTrackID, ...
                            obj(iTrack).daughterTrackIDs(1), obj(iTrack).daughterTrackIDs(end));
                    
                        for iF = 1:obj(iTrack).numFrames
                    
                            if iF > 1
                                %Skip the common track data
                                fprintf(fid, ', , , ');
                            end
                    
                            %Write the frame number
                            fprintf(fid, ', %d', obj(iTrack).frames(iF));
                    
                            %Write the datafields
                            for iP = 1:numel(trackedData)
                                currField = trackedData{iP};
                                
                                if numel(obj(iTrack).data(iF).(currField)) > 1
                                    fprintf(fid, ', [');
                                    fprintf(fid, '%d ', obj(iTrack).data(iF).(currField));
                                    fprintf(fid, ']');                                    
                                else
                                    fprintf(fid, ', %d', obj(iTrack).data(iF).(currField));
                                end
                            end
                            fprintf(fid, '\n');
                            
                        end
                        
                    end
                    
                    fclose(fid);
                                  
                case 'xml'
                    %XML document specification
                    %
                    %  <TrackDataArray>
                    %    <Metadata/>
                    %    <track trackID = ID>
                    %       <motherTrackID>ID<motherTrackID>
                    %       <daughterTrackIDs>ID<daughterTrackIDs>
                    %       <frame frameIndex = 1>
                    %           <data>
                    %           </data>
                    %       </frame>
                    %    </track>
                    %  </TrackDataArray>
                    %
                    
                    %TODO APPEND
                        docNode = com.mathworks.xml.XMLUtils.createDocument('TrackDataArray');
                        
                        %Create top level array
                        docArray = docNode.getDocumentElement;
             
                    
                    %Can fill file metadata in attributes
                    
                    for iTrack = 1:numel(obj)
                        currTrackNode = docNode.createElement('track');
                        currTrackNode.setAttribute('trackID', int2str(obj(iTrack).trackID));
                    
                        mNode = docNode.createElement('motherTrackID');
                        mNode.appendChild(docNode.createTextNode(int2str(obj(iTrack).motherTrackID)));
                        currTrackNode.appendChild(mNode);
                        
                        dNode = docNode.createElement('daughterTrackIDs');
                        dNode.appendChild(docNode.createTextNode(mat2str(obj(iTrack).daughterTrackIDs)));
                        currTrackNode.appendChild(dNode);
                                               
                        for iT = 1:obj(iTrack).numFrames
                    
                            fNode = docNode.createElement('frame');
                            fNode.setAttribute('index', int2str(obj(iTrack).frames(iT)));
                    
                            for iP = 1:numel(trackedData)
                    
                                currP = docNode.createElement(trackedData{iP});
                                currP.appendChild( docNode.createTextNode(mat2str(obj(iTrack).data(iT).(trackedData{iP}))) );
                                fNode.appendChild(currP);
                            end
                            currTrackNode.appendChild(fNode);
                    
                        end
                    
                        docArray.appendChild(currTrackNode);
                    
                    end
                    
                    xmlwrite(filename,docNode);
                    
                case 'json'

                    fid = fopen(filename, filePerm);
                    fprintf(fid, '%s', jsonencode(track2struct(obj)));
                    fclose(fid);
                    
                    
                otherwise 
                    
                    error('trackdata:export:UnsupportedFileFormat',...
                        '%s is not a supported file format.', fext);

            end
            
        end

    end
    
    methods (Static)
       
        function obj = struct2track(dataIn)
            %STRUCT2TRACK  Creates a trackdata object from a struct
            
            if ~isstruct(dataIn)
                error('trackdata:struct2track:InputNotStruct',...
                    'Expected input to be a struct.')                
            end
            
            obj = timedata.trackdata(numel(dataIn));
            
            for iTrack = 1:numel(dataIn)
                obj(iTrack).trackID = dataIn(iTrack).trackID;
                obj(iTrack).seriesID = dataIn(iTrack).seriesID;
                obj(iTrack).motherTrackID = dataIn(iTrack).motherTrackID;
                obj(iTrack).daughterTrackIDs = dataIn(iTrack).daughterTrackIDs;
                
                obj(iTrack).data = dataIn(iTrack).data;
                obj(iTrack).frames = dataIn(iTrack).frames;
            end
            
        end
                
        function obj = import(filename, varargin)
            %IMPORT  Imports data into a trackdata object
            %
            %  OBJ = timedata.trackdata.IMPORT(FILENAME) will import data
            %  from the file specified.
            
            %Validate the filename
            if ~exist(filename,'file')
                error('trackdata:import:FileNotFound', ...
                    'Could not find ''%s'' on the current path.',...
                    filename);                
            end
            
            %Get file extension
            [~, ~, fext] = fileparts(filename);
            
            %Parse variable inputs
            while ~isempty(varargin)
                fext = varargin{1};
                varargin(1) = [];
            end
                        
            %Strip any non-word/digits from the file extension
            fext = regexprep(fext, '\W*','');
            
            switch lower(fext)
                
                case 'json'
                    
                    obj = timedata.trackdata.struct2track(jsondecode(fileread(filename)));
                    
                otherwise
                    error('trackdata:import:UnsupportedFileFormat',...
                        '''%s'' is currently unsupported.', fext);
            
            end
            
            
        end
        
    end
    
end

% % %% Export to HD5
% % 
% % hd5FN = [fn, '.h5'];
% % 
% % if exist(hd5FN, 'file')
% %     delete(hd5FN);    
% % end
% % 
% % for iTrack = 1:numel(trackArray)
% %     
% %     %Create track elememnt
% %     ct = trackArray.getTrack(iTrack);    
% %         
% %     h5create(hd5FN, sprintf('/track%d/ID', ct.ID), [1, 1]);
% %     h5write(hd5FN, sprintf('/track%d/ID', ct.ID), ct.ID);    
% %     
% %     h5create(hd5FN, sprintf('/track%d/MotherIdx', ct.ID), [1, 1]);
% %     h5write(hd5FN, sprintf('/track%d/MotherIdx', ct.ID), ct.MotherIdx);
% %     h5create(hd5FN, sprintf('/track%d/DaughterIdxs', ct.ID), [1, numel(ct.DaughterIdxs)]);
% %     h5write(hd5FN, sprintf('/track%d/DaughterIdxs', ct.ID), ct.DaughterIdxs);
% %     
% %     h5create(hd5FN, sprintf('/track%d/FrameIndex', ct.ID), [1, ct.NumFrames]);
% %     h5write(hd5FN, sprintf('/track%d/FrameIndex', ct.ID), ct.FrameIndex);
% % 
% %     for iP = 1:numel(ct.TrackDataProps)            
% %             
% %             %Skip pixelidxlist and centroid just to keep the file size the
% %             %same
% %             switch ct.TrackDataProps{iP}
% %                 
% %                 case 'PixelIdxList'
% %                     h5create(hd5FN, sprintf('/track%d/%s', ct.ID, ct.TrackDataProps{iP}), [1 2]);
% %                     h5write(hd5FN, sprintf('/track%d/%s',ct.ID, ct.TrackDataProps{iP}), [72 72]);
% %                     
% %                 case 'Centroid'
% %                     h5create(hd5FN, sprintf('/track%d/%s', ct.ID,ct.TrackDataProps{iP}), [1 2]);
% %                     h5write(hd5FN, sprintf('/track%d/%s',ct.ID, ct.TrackDataProps{iP}), [72 72]);
% %                     
% %                 otherwise                   
% %                     try
% %                         
% %                         dataToWrite = cat(1,ct.Data.(ct.TrackDataProps{iP}));
% %                         h5create(hd5FN, sprintf('/track%d/%s',ct.ID, ct.TrackDataProps{iP}), size(dataToWrite));
% %                         h5write(hd5FN, sprintf('/track%d/%s', ct.ID,ct.TrackDataProps{iP}), dataToWrite);
% %                     catch
% %                         keyboard
% %                     end
% %             end
% %     
% %     end
% %         
% % end