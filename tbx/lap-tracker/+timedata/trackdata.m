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
            %  delFrame(T, F) will delete frame F from the trackdata
            %  object. If F is the first or last frame, the frame index
            %  will be updated accordingly. Otherwise, the frame data is
            %  emptied, but the frame index is kept the same.
            
            %Validate the input
            if isnumeric(framesToDel)
                if ~(all(framesToDel >= obj.firstFrame & framesToDel <= obj.lastFrame))
                    error('trackdata:delFrame:frameIndexInvalid',...
                        'Frame numbers to be deleted should be between %d (first frame) and %d (last frame).',...
                        obj.firstFrame, obj.lastFrame);
                end
                
            elseif ischar(tFrame)
                
                if strcmpi(framesToDel, 'first')
                    framesToDel = obj.firstFrame;
                    
                elseif strcmpi(framesToDel, 'last')
                    framesToDel = obj.lastFrame;
                    
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
            dataInd = framesToDel - obj.firstFrame + 1;
            
            %Delete the data
            for iDel = 1:numel(framesToDel)
                if framesToDel(iDel) == obj.firstFrame
                    obj.frames(1) = [];
                    obj.data(1) = [];
                    
                    %Remove empty frames from the start
                    while all(structfun(@isempty ,obj.data(1)))
                        obj.frames(1) = [];
                        obj.data(1) = [];
                    end
                    
                elseif framesToDel(iDel) == obj.lastFrame
                    obj.frames(end) = [];
                    obj.data(end) = [];
                    
                else
                    
                    fn = fieldnames(obj.data(dataInd(iDel)))';
                    fn{2, 1} = cell(1);
                    
                    %Make the data empty
                    obj.data(dataInd(iDel)) = struct(fn{:});

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
            %  a file format extension than is different than the filename
            %
            %  Example: EXPORT(OBJ, 'output.txt', 'csv') will write to
            %  output.txt but using the CSV format.
            
            %Parse the variable input            
            if isempty(varargin)
                [~, ~, fext] = fileparts(filename);
            else
                fext = varargin{1};
            end
                        
            %Strip any non-word/digits
            fext = regexprep(fext, '\W*','');
            
            %Set the file permissions
            filePerm = 'w'; %Overwrite file if it exists
            
            if numel(varargin) == 2
                if strcmpi(varargin{2}, 'append')
                    filePerm = 'a'; %Append to file if it exists
                end
            end
            
            switch lower(fext)
                
                case 'csv'
                    
                    fid = fopen(filename, filePerm);
                    
                    trackedData = fieldnames(obj(1).data);
                    
                    %Write the header
                    fprintf(fid, 'trackID, seriesID, motherTrackID, daughterTrackIDs, Frame');
                    fprintf(fid, ', %s', trackedData{:});  %Write the tracked data fieldnames
                    fprintf(fid, '\n');
                    
                    for iTrack = 1:numel(obj)
                    
                        fprintf(fid, '%d, %d, %d, %d %d', ...
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
                        fprintf(fid, '\n');
                        
                    end
                    
                    fclose(fid);
                                    
                otherwise 
                    
                    error('trackdata:export:UnsupportedFileFormat',...
                        '%s is not a supported file format.', fext);

            end
            
        end
        

    end
    
    methods (Static)
       
        function obj = import(varargin)
            %IMPORT  Imports data into a trackdata object
            %
            %  OBJ = timedata.trackdata.IMPORT(S) will import data from a
            %  struct into a trackdata object. If S has multiple tracks,
            %  OBJ will be an array of trackdata objects.
            
            obj = timedata.trackdata(numel(varargin{1}));
            
            for iTrack = 1:numel(varargin{1})
                obj(iTrack).trackID = varargin{1}(iTrack).trackID;
                obj(iTrack).seriesID = varargin{1}(iTrack).seriesID;
                obj(iTrack).motherTrackID = varargin{1}(iTrack).motherTrackID;
                obj(iTrack).daughterTrackIDs = varargin{1}(iTrack).daughterTrackIDs;
                
                obj(iTrack).data = varargin{1}(iTrack).data;
                obj(iTrack).frames = varargin{1}(iTrack).frames;
            end
            
        end
        
    end
    
end


% % fn = 'seq0000_xy4_crop_2_series1.mat';
% % 
% % load(fn);
% % 
% % fn = fn(1:end-4);
% % 
% % %% Export to CSV
% % 
% % fid = fopen([fn,'.csv'], 'w');
% % 
% % fprintf(fid, 'TID, MotherIdx, DaughterIdx1, DaughterIdx2, Frame, ');
% % 
% % fprintf(fid,'%s ,', trackArray.TrackedDataFields{1:end-1});
% % fprintf(fid,'%s \n', trackArray.TrackedDataFields{end});
% %         
% % for iTrack = 1:numel(trackArray)
% %     
% %     ct = trackArray.getTrack(iTrack);
% %     
% %     fprintf(fid, '%d, %d, %d, %d', ct.ID, ct.MotherIdx, ct.DaughterIdxs(1), ct.DaughterIdxs(end));
% %     
% %     for iF = 1:ct.NumFrames
% %         
% %         if iF > 1
% %             fprintf(fid, ', , , ');
% %         end
% %         
% %         fprintf(fid, ', %d', ct.FrameIndex(iF));
% %         
% %         for iP = 1:numel(trackArray.TrackedDataFields)
% %             
% %                 if numel(ct.Data(iF).(trackArray.TrackedDataFields{iP})) > 1
% %                     fprintf(fid, ', %%');
% %                     
% %                 else
% %                     fprintf(fid, ', %d', ct.Data(iF).(trackArray.TrackedDataFields{iP}));
% %                     
% %                 end
% %         end
% %         fprintf(fid, '\n');
% %     end
% %     fprintf(fid, '\n');
% %     
% % end
% % 
% % fclose(fid);
% % 
% % %% Export to XML
% % 
% % docNode = com.mathworks.xml.XMLUtils.createDocument('TrackArray');
% % 
% % %Create top level array
% % docArray = docNode.getDocumentElement;
% % 
% % %Can fill file metadata in attributes
% % 
% % for iTrack = 1:numel(trackArray)
% %     
% %     %Create track elememnt
% %     ct = trackArray.getTrack(iTrack);
% %     
% %     currTrackNode = docNode.createElement('track');
% %     currTrackNode.setAttribute('ID', int2str(ct.ID));
% %     
% %     mNode = docNode.createElement('MotherIdx');
% %     mNode.appendChild(docNode.createTextNode(int2str(ct.MotherIdx)));
% %     
% %     dNode = docNode.createElement('DaughterIdxs');
% %     dNode.appendChild(docNode.createTextNode(mat2str(ct.DaughterIdxs)));
% %     
% %     currTrackNode.appendChild(mNode);  
% %     currTrackNode.appendChild(dNode);  
% %         
% %     for iT = 1:ct.NumFrames
% %         
% %         fNode = docNode.createElement('Frame');
% %         fNode.setAttribute('Index', int2str(ct.FrameIndex(iT)));
% %             
% %         for iP = 1:numel(ct.TrackDataProps)
% %             
% %             currP = docNode.createElement(ct.TrackDataProps{iP});
% %             
% %             %Skip pixelidxlist and centroid just to keep the file size the
% %             %same
% %             switch ct.TrackDataProps{iP}
% %                 
% %                 case 'PixelIdxList'
% %                     currP.appendChild( docNode.createTextNode('%%') );
% %                     
% %                 case 'Centroid'
% %                     currP.appendChild( docNode.createTextNode('%%') );
% %                     
% %                 otherwise                   
% %                     
% %                     currP.appendChild( docNode.createTextNode(mat2str(ct.Data(iT).(ct.TrackDataProps{iP}))) );
% %             
% %             end
% %             fNode.appendChild(currP);            
% %         end
% %         currTrackNode.appendChild(fNode);
% %         
% %     end
% %             
% %     docArray.appendChild(currTrackNode);
% %         
% % end 
% % 
% % xmlwrite([fn,'.xml'],docNode);
% % 
% % %% Export to JSON
% % 
% % %Convert to struct
% % tempStruct = struct;
% % 
% % for iTrack = 1:numel(trackArray)
% %     
% %     ct = trackArray.getTrack(iTrack);
% %     
% %     tempStruct(iTrack).ID = ct.ID;
% %     tempStruct(iTrack).MotherIdx = ct.MotherIdx;
% %     tempStruct(iTrack).DaughterIdx = ct.DaughterIdxs;
% %         
% %     tempStruct(iTrack).FrameIdx = ct.FrameIndex;
% %     
% %     for iP = 1:numel(trackArray.TrackedDataFields)
% %         
% %         switch ct.TrackDataProps{iP}
% %             
% %             case 'PixelIdxList'
% %                 tempStruct(iTrack).PixelIdxList = '%%';
% %                 
% %             case 'Centroid'
% %                 tempStruct(iTrack).Centroid = '%%';
% %             
% %             otherwise
% %                 tempStruct(iTrack).(ct.TrackDataProps{iP}) = cat(1,ct.Data.(ct.TrackDataProps{iP}));
% %         end
% %     end
% %     
% % end
% % 
% % fid = fopen([fn, '.json'], 'w');
% % fprintf(fid, '%s', jsonencode(tempStruct));
% % fclose(fid);
% % 
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