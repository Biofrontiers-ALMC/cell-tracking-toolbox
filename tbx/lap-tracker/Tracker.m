classdef Tracker < handle
    %TRACKER  Object handling segmentation and tracking
    %
    %  TRACKER is an object for setting up tracking and segmentation for
    %  cells.
    %
    %  This object requires the BioformatsImage toolbox and the LAP tracker
    %  to be installed.    %
    %
    %  Copyright 2018 CU Boulder
    %  Author: Jian Wei Tay
    
    properties
        
        %Image options
        FrameRange = Inf;
        SeriesRange = Inf;
        OutputMovie = true;
        
        UseMasks = false;
        InputMaskDir = 0;
        
        %Export options
        ExportMasks = false;
                
        %Segmentation options
        ChannelToSegment = '';
        ThresholdLevel = 1.4;
        
        SpotChannel = '';
        SpotThreshold = 2.5;
        
        %Track linking parameters
        LinkedBy = 'PixelIdxList';
        LinkCalculation = 'pxintersect';
        LinkingScoreRange = [1, 4.1];
        MaxTrackAge = 2;
        
        %Mitosis detection parameters
        TrackMitosis = true;
        MinAgeSinceMitosis = 2;
        MitosisParameter = 'PixelIdxList';          %What property is used for mitosis detection?
        MitosisCalculation = 'pxintersect';
        MitosisScoreRange = [1, 4];
        MitosisLinkToFrame = -1;                    %What frame to link to/ This should be 0 for centroid/nearest neighbor or -1 for overlap (e.g. check with mother cell)
        LAPSolver = 'lapjv';
        
        %Parallel processing options
        EnableParallel = false;
        MaxWorkers = Inf;
        
    end
        
    methods
        
        function obj = Tracker(varargin)
            %TRACKER  Object to track and segment cyanobacteria cells
            %
            %  This is the constructor function for the CyTracker object.
            %  Its purpose is to check that the required toolboxes are
            %  installed correctly.
            %
            %  Required toolboxes/m-files:
            %    * BioformatImage
            %    * LAPtracker
            
            
            
            
        end
        
        function process(obj, varargin)
            %PROCESS  Run segmentation and tracking on ND2 files
            %
            %  PROCESS(OBJ) will run the segmentation and tracking
            %  operations using the current settings in CObj. A dialog box
            %  will appear prompting the user to select ND2 file(s) to
            %  process, as well as the output directory.
            %
            %  PROCESS(OBJ, FILE1, ..., FILEN, OUTPUTDIR) will run the
            %  processing on the file(s) specified. Note that the files do
            %  not need to be in the same directory. The output files will
            %  be written to OUTPUTDIR.

            %--- Validate file inputs---%
            if isempty(varargin)
                %If input is empty, prompt user to select file(s) and
                %output directory
                
                [fname, fpath] = uigetfile({'*.nd2','ND2 file (*.nd2)'},...
                    'Select a file','multiSelect','on');
                
                if isequal(fname,0) || isequal(fpath,0)
                    %User pressed cancel
                    return;
                end
                
                %Append the full path to the selected file(s)
                if iscell(fname)
                    for ii = 1:numel(fname)
                        fname{ii} = fullfile(fpath,fname{ii});
                    end
                else
                    fname = {fullfile(fpath,fname)};
                end
               
                %Prompt for mask directory
                if obj.UseMasks && isempty(obj.InputMaskDir)
                    obj.InputMaskDir = uigetdir(fileparts(fname{1}), 'Select mask directory');
                    
                    if isequal(obj.InputMaskDir,0)
                        return;
                    end
                end                
                
                %Get output directory
                outputDir = uigetdir(fileparts(fname{1}), 'Select output directory');
                
                if isequal(outputDir,0)
                    return;
                end
                
            elseif numel(varargin) >= 2
                
                %Check that the last argument is not a file (i.e. has no
                %.ext)
                [~, ~, lastFext] = fileparts(varargin{end});
                if ~isempty(lastFext)                    
                    error('CyTracker:OutputDirNeeded', ...
                        'An output directory must be specified.')
                end
                
                %Check that the InputMaskDir property is set if masks are
                %present
                if obj.UseMasks && isequal(obj.InputMaskDir, 0)
                    error('CyTracker:InputMaskDirNotSet', ...
                        'The InputMaskDir property must be set to the mask path.')
                end
                                
                fname = varargin(1:end - 1);
                
                outputDir = varargin{end};
                
                if ~exist(outputDir, 'dir')
                    mkdir(outputDir);                    
                end
                                
            else
                error('CyTracker:InsufficientInputs', ...
                    'Expected number of inputs to be zero or a minimum of 2.')
            end

            %Compile the options into a struct
            options = obj.getOptions;           

            %Process the files
            if obj.EnableParallel
                
                parfor (iF = 1:numel(fname), obj.MaxWorkers)
                    try
                        fprintf('%s %s: Starting processing.\n', datestr(now), fname{iF});
                        CyTracker.trackFile(fname{iF}, outputDir, options);
                        fprintf('%s %s: Completed.\n', datestr(now), fname{iF});
                    catch ME
                        fprintf('%s %s: An error occured:\n', datestr(now), fname{iF});
                        fprintf('%s \n',getReport(ME,'extended','hyperlinks','off'));
                    end
                end
                
            else
                
                for iF = 1:numel(fname)
                    try
                        fprintf('%s %s: Starting processing.\n', datestr(now), fname{iF});
                        CyTracker.trackFile(fname{iF}, outputDir, options);
                        fprintf('%s %s: Completed.\n', datestr(now), fname{iF});
                    catch ME
                        fprintf('%s %s: An error occured:\n', datestr(now), fname{iF});
                        fprintf('%s \n',getReport(ME,'extended','hyperlinks','off'));
                    end
                end
                
            end
            
            %Save the settings file
            obj.exportOptions(fullfile(outputDir,'settings.txt'));
            
        end
       
        function importOptions(obj, varargin)
            %IMPORTOPTIONS  Import options from file
            %
            %  IMPORTOPTIONS(OBJ, FILENAME) will load the options from the
            %  file specified.
            %
            %  IMPORTOPTIONS(OBJ) will open a dialog box for the user to
            %  select the option file.
            
            %Get the options file
            if isempty(varargin)                
                [fname, fpath] = uigetfile({'*.txt','Text file (*.txt)';...
                    '*.*','All files (*.*)'},...
                    'Select settings file');
                
                optionsFile = fullfile(fpath,fname);
                
            elseif numel(varargin) == 1
                optionsFile = varargin{1};
                
            else
                error('CyTracker:TooManyInputs', 'Too many input arguments.');
                
            end
            
            fid = fopen(optionsFile,'r');
            
            if isequal(fid,-1)
                error('CyTracker:ErrorReadingFile',...
                    'Could not open file %s for reading.',fname);
            end
            
            ctrLine = 0;
            while ~feof(fid)
                currLine = strtrim(fgetl(fid));
                ctrLine = ctrLine + 1;
                
                if isempty(currLine) || strcmpi(currLine(1),'%') || strcmpi(currLine(1),'#')
                    %Empty lines should be skipped
                    %Lines starting with '%' or '#' are comments, so ignore
                    %those
                    
                else
                    
                    parsedLine = strsplit(currLine,'=');
                    
                    %Check for errors in the options file
                    if numel(parsedLine) < 2 
                        error('CyTracker:ErrorReadingOption',...
                            'Error reading <a href="matlab:opentoline(''%s'', %d)">file %s (line %d)</a>',...
                            optionsFile, ctrLine, optionsFile, ctrLine);
                    elseif isempty(parsedLine{2})
                        error('CyTracker:ErrorReadingOption',...
                            'Missing value in <a href="matlab:opentoline(''%s'', %d)">file %s (line %d)</a>',...
                            optionsFile, ctrLine, optionsFile, ctrLine);
                    end
                    
                    %Get parameter name (removing spaces)
                    parameterName = strtrim(parsedLine{1});
                    
                    %Get value name (removing spaces)
                    value = strtrim(parsedLine{2});
                    
                    if isempty(value)
                        %If value is empty, just use the default
                    else
                        obj.(parameterName) = eval(value);
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
        
        function exportMasks(obj, varargin)
            %EXPORTMASKS  Segment and export cell masks
            %
            %  EXPORTMASKS(PT) will export the cell masks of the selected
            %  images to the output directory specified. Both images and
            %  output directory can be selected using a dialog box pop up.
            %
            %  EXPORTMASKS(PT, fileList, outputDir) where fileList is a
            %  cell array of strings containing paths to the file, and
            %  outputDir is the path to save the masks to.           
            
            %Validate the inputs
            if isempty(varargin)
                [fname, fpath] = uigetfile({'*.nd2','ND2 file (*.nd2)'},...
                    'Select a file','multiSelect','on');
                
                if ~iscell(fname) && ~ischar(fname)
                    %Stop running the script
                    return;
                end
                
                if iscell(fname)
                    filename = cell(1, numel(fname));
                    for ii = 1:numel(fname)
                        filename{ii} = fullfile(fpath,fname{ii});
                    end
                else
                    filename = {fullfile(fpath,fname)};
                end
                
            else
                if exist(varargin{1},'file')
                    filename = varargin{1};
                else
                    error('PolyploidyTracker:processFiles:FileDoesNotExist',...
                        'Could not find file %s.',varargin{1});
                end
            end
            
            %Prompt user for a directory to save output files to
            if numel(varargin) < 2
                
                startPath = fileparts(filename{1});
                
                outputDir = uigetdir(startPath, 'Select output directory');
                
                if outputDir == 0
                    %Processing cancelled
                    return;
                end
                
            else
                outputDir = varargin{2};
                if ~exist(outputDir,'dir')
                    mkdir(outputDir)
                end
            end
            
            for iFile = 1:numel(filename)                
                
                [~, currFN] = fileparts(filename{iFile});
                bfr = BioformatsImage(filename{iFile});
                
                %Get frame range
                if isinf(obj.FrameRange)
                    frameRange = 1:bfr.sizeT;
                else
                    frameRange = obj.FrameRange;
                end
                
                %Get series range
                if isinf(obj.SeriesRange)
                    seriesRange = 1:bfr.seriesCount;
                else
                    seriesRange = obj.SeriesRange;
                end
                
                for iSeries = seriesRange
                    
                    bfr.series = iSeries;
                    
                    for iT = frameRange
                        
                        %Segment the cells
                        currCellMask = PolyploidyTracker.getCellLabels(bfr.getPlane(1, obj.ChannelToSegment, iT), obj.ThresholdLevel);
                        
                        %Normalize the mask
                        outputMask = currCellMask > 0;
                        %outputMask = uint8(outputMask) .* 255;
                        
                        %Normalize the image and convert to uint8
                        imgToExport = bfr.getPlane(1, 'Cy5', iT);
                        outputImg = uint8(double(imgToExport)./double(max(imgToExport(:))) .* 255);
                                                
                        %Write to TIFF stack
                        maskOutputFN = fullfile(outputDir, sprintf('%s_series%d_masks.tif', currFN, iSeries));
                        imageOutputFN = fullfile(outputDir, sprintf('%s_series%d_cy5.tif', currFN, iSeries));
                    
                        if iT == frameRange(1)
                            imwrite(outputMask, maskOutputFN, 'compression', 'none');
                            imwrite(outputImg, imageOutputFN, 'compression', 'none');
                        else
                            imwrite(outputMask, maskOutputFN,'writeMode','append', 'compression', 'none');
                            imwrite(outputImg, imageOutputFN, 'compression', 'none', 'writeMode','append');
                        end
                        
                        
                    end
                end
            end
            
            
        end
        
    end
    
    methods (Static)
        
        function trackFile(filename, outputDir, opts)
            %TRACKFILE  Run segmentation and tracking for a selected file
            %
            %  TRACKFILE(FILENAME, OUTPUTDIR, OPTS) will run the processing
            %  for the FILENAME specified. OUTPUTDIR should be the path to
            %  the output directory, and OPTS should be a struct containing
            %  the settings for segmentation and tracking.
            %
            %  The OPTS struct can be constructed from a CYTRACKER object
            %  by using the (private) getOptions function.
            
            %Get a reader object for the image
            bfReader = BioformatsImage(filename);
            
            %Set the frame range to process
            if isinf(opts.FrameRange)
                frameRange = 1:bfReader.sizeT;
            else
                frameRange = opts.FrameRange;
            end
            
            %Set the series range to process
            if isinf(opts.SeriesRange)
                seriesRange = 1:bfReader.seriesCount;
            else
                seriesRange = opts.SeriesRange;
            end
            
            %--- Start processing ---%
            
            for iSeries = seriesRange
                
                %Generate the common output filename (no extension)
                [~, fname] = fileparts(filename);
                saveFN = fullfile(outputDir, sprintf('%s_series%d',fname, iSeries));
                
                %Set the image series number
                bfReader.series = iSeries;
                
                %--- Start tracking ---%
                
                for iT = frameRange
                    
                    %-- v2.0 TODO: Move these functions out --%
                    %Segment the cells
                    imgToSegment = bfReader.getPlane(1, opts.ChannelToSegment, iT);
                    
                    if isempty(opts.InputMaskDir)
                        %Segment the cells
                        cellLabels = CyTracker.getCellLabels(imgToSegment, opts.ThresholdLevel);
                    else
                        %Load the masks
                        mask = imread(fullfile(opts.InputMaskDir, sprintf('%s_series%d_masks.tif',fname, iSeries)),'Index', iT);
                        cellLabels = labelmatrix(bwconncomp(mask(:,:,1)));
                    end
                    
                    %Run spot detection if the SpotChannel property is set
                    if ~isempty(opts.SpotChannel)
                        dotImg = bfReader.getPlane(1, opts.SpotChannel, iT);
                        dotLabels = CyTracker.segmentSpots(dotImg, cellLabels, opts.SpotThreshold);
                    else 
                        dotLabels = [];
                    end
                    
                    %Run the measurement script
                    cellData = CyTracker.measure(cellLabels, dotLabels, bfReader, iT);
                    
                    %-- END v2.0 TODO: Move these functions out --%
                    
                    if numel(cellData) == 0
                        warning('CyTracker:NoCellsFound', '%s (frame %d): Cell mask was empty.',saveFN, iT);
                    else
                        %Link cells
                        if iT == frameRange(1)
                            %Initialize a TrackLinker object
                            trackLinker = TrackLinker(iT, cellData);
                            
                            %Write file metadata
                            trackLinker = trackLinker.setOptions(opts);
                            trackLinker = trackLinker.setFilename(bfReader.filename);
                            trackLinker = trackLinker.setPxSizeInfo(bfReader.pxSize(1),bfReader.pxUnits);
                            trackLinker = trackLinker.setImgSize([bfReader.height, bfReader.width]);
                            
                        else
                            try
                                %Link data to existing tracks
                                trackLinker = trackLinker.assignToTrack(iT, cellData);
                            catch
                                saveData = input('There was an error linking tracks. Would you like to save the tracked data generated so far (y = yes)?\n','s');
                                if strcmpi(saveData,'y')
                                    trackArray = trackLinker.getTrackArray; %#ok<NASGU>
                                    save([saveFN, '.mat'], 'trackArray');
                                end
                                clear trackArray
                                return;
                            end
                        end
                        
                        %Write movie file (if OutputMovie was set)
                        if opts.OutputMovie
                            
                            if ~exist('vidObj','var') && numel(frameRange) > 1
                                vidObj = VideoWriter([saveFN, '.avi']); %#ok<TNMLP>
                                vidObj.FrameRate = 10;
                                vidObj.Quality = 100;
                                open(vidObj);
                                
                                if ~isempty(opts.SpotChannel)
                                    spotVidObj = VideoWriter([saveFN, 'spots.avi']); %#ok<TNMLP>
                                    spotVidObj.FrameRate = 10;
                                    spotVidObj.Quality = 100;
                                    open(spotVidObj);
                                end
                            end
                            
                            cellImgOut = CyTracker.makeAnnotatedImage(iT, imgToSegment, cellLabels, trackLinker);
                            if numel(frameRange) > 1
                                vidObj.writeVideo(cellImgOut);
                            else
                                imwrite(cellImgOut,[saveFN, '.png']);
                            end
                            
                            if ~isempty(opts.SpotChannel)
                                spotImgOut = CyTracker.makeAnnotatedImage(iT, dotImg, imdilate(dotLabels, strel('diamond', 3)), trackLinker, 'notracks');
                                
                                if numel(frameRange) > 1
                                    spotVidObj.writeVideo(spotImgOut);
                                else
                                    imwrite(spotImgOut,[saveFN, 'spots.png']);
                                end
                            end
                            
                        end
                    end
                end
                
                %--- END tracking ---%
                
                %Close video objects
                if exist('vidObj','var')
                    close(vidObj);
                    clear vidObj
                    
                    if ~isempty(opts.SpotChannel)
                        close(spotVidObj);
                        clear spotVidObj
                    end
                end
                
                %Save the track array
                
                %Add timestamp information to the track array
                trackArray = trackLinker.getTrackArray;
                
                %Add timestamp information
                [ts, tsunit] = bfReader.getTimestamps(1,1);

                trackArray = trackArray.setTimestampInfo(ts,tsunit); %#ok<NASGU>
                
                save([saveFN, '.mat'], 'trackArray');
                clear trackArray
            end
            
        end
        
        function cellData = measure(cellLabels, spotLabels, bfReader, iT)
            %measure  Get cell data
            %
            %  
            
            %Get standard data
            cellData = regionprops(cellLabels, ...
                'Area','Centroid','PixelIdxList','MajorAxisLength', 'MinorAxisLength');
            
            %Remove non-existing data
            cellData([cellData.Area] ==  0) = [];
            
            %Get intensity data. Names: PropertyChanName
            for iC = 1:bfReader.sizeC
                currImage = bfReader.getPlane(1, iC, iT);
                
                for iCell = 1:numel(cellData)
                    cellData(iCell).(['TotalInt',regexprep(bfReader.channelNames{iC},'[^\w\d]*','')]) = ...
                        sum(currImage(cellData(iCell).PixelIdxList));
                    
                    if ~isempty(spotLabels)
                        cellData(iCell).NumSpots = nnz(spotLabels(cellData(iCell).PixelIdxList));
                    end
                end
            end
            
        end
        
        function cellLabels = getCellLabels(cellImage, thFactor)
            %GETCELLLABELS  Segment and label individual cells
            %
            %  L = CyTracker.GETCELLLABELS(I) will segment the cells in image
            %  I, returning a labelled image L. Each value in L should
            %  correspond to an individual cell.
            %
            %  L = CyTracker.GETCELLLABELS(I, M) will use image M to mark
            %  cells. M should be a fluroescent image (e.g. YFP, GFP) that
            %  fully fills the cells.
            
            %Normalize the cellImage
            cellImage = CyTracker.normalizeimg(cellImage);
            cellImage = imsharpen(cellImage,'Amount', 2);           
            
            %Get a threshold
            [nCnts, binEdges] = histcounts(cellImage(:),150);
            binCenters = diff(binEdges) + binEdges(1:end-1);
            
            %Determine the background intensity level
            [~,locs] = findpeaks(nCnts,'Npeaks',1,'sortStr','descend');
            
            gf = fit(binCenters', nCnts', 'Gauss1', 'StartPoint', [nCnts(locs), binCenters(locs), 10000]);
            
            thLvl = gf.b1 + thFactor * gf.c1;            
            mask = cellImage > thLvl;
            
            mask = imopen(mask,strel('disk',2));
            mask = imclearborder(mask);
            
            mask = activecontour(cellImage,mask);
            
            mask = bwareaopen(mask,100);
            mask = imopen(mask,strel('disk',2));
            
            mask = imfill(mask,'holes');
                        
            %Try to mark the image
            markerImg = medfilt2(cellImage,[10 10]);
            markerImg = imregionalmax(markerImg,8);
            markerImg(~mask) = 0;
            markerImg = imdilate(markerImg,strel('disk', 6));
            markerImg = imerode(markerImg,strel('disk', 3));
            
            %Remove regions which are too dark
            rptemp = regionprops(markerImg, cellImage,'MeanIntensity','PixelIdxList');
            markerTh = median([rptemp.MeanIntensity]) - 0.2 * median([rptemp.MeanIntensity]);
            
            idxToDelete = 1:numel(rptemp);
            idxToDelete([rptemp.MeanIntensity] > markerTh) = [];
            
            for ii = idxToDelete
                markerImg(rptemp(ii).PixelIdxList) = 0;                
            end
                        
            dd = imcomplement(medfilt2(cellImage,[4 4]));
            dd = imimposemin(dd, ~mask | markerImg);
                        
            cellLabels = watershed(dd);
            cellLabels = imclearborder(cellLabels);
            
            cellLabels = imopen(cellLabels, strel('disk',6));
            
            if ~any(cellLabels(:))
                warning('No cells detected');              
            end
            
        end
        
        function dotLabels = segmentSpots(imgIn, cellLabels, spotThreshold)
            %SEGMENTSPOTS  Finds spots
            
            %Convert the carboxysome image to double
            imgIn = double(imgIn);
            
            %Apply a median filter to smooth the image
            imgIn = medfilt2(imgIn,[2 2]);
            
            %Find local maxima in the image using dilation
            dilCbxImage = imdilate(imgIn,strel('disk',2));
            dotMask = dilCbxImage == imgIn;
            
            dotLabels = false(size(imgIn));
            %Refine the dots by cell intensity
            for iCell = 1:max(cellLabels(:))
                
                currCellMask = cellLabels == iCell;
                
                cellBgInt = mean(imgIn(currCellMask));
                
                currDotMask = dotMask & currCellMask;
                currDotMask(imgIn < spotThreshold * cellBgInt) = 0;
                
                dotLabels = dotLabels | currDotMask;
            end
            
            %             keyboard
            %dotLabels = imdilate(dotLabels,[0 1 0; 1 1 1; 0 1 0]);
            
        end
        
        function varargout = showoverlay(img, mask, varargin)
            %SHOWOVERLAY  Overlays a mask on to a base image
            %
            %  SHOWOVERLAY(I, M) will overlay mask M over the image I,
            %  displaying it in a figure window.
            %
            %  C = SHOWOVERLAY(I, M) will return the composited image as a
            %  matrix C. This allows multiple masks to be composited over
            %  the same image. C should be of the same class as the input
            %  image I. However, if the input image I is a double, the
            %  output image C will be normalized to between 0 and 1.
            %
            %  Optional parameters can be supplied to the function to
            %  modify both the color and the transparency of the masks:
            %
            %     'Color' - 1x3 vector specifying the color of the overlay
            %               in normalized RGB coordinates (e.g. [0 0 1] =
            %               blue)
            %
            %     'Opacity' - Value between 0 - 100 specifying the alpha
            %                 level of the overlay. 0 = completely 
            %                 transparent, 100 = completely opaque
            %
            %  Examples:
            %
            %    %Load a test image testImg = imread('cameraman.tif');
            %
            %    %Generate a masked region maskIn = false(size(testImg));
            %    maskIn(50:70,50:200) = true;
            %
            %    %Store the image to a new variable imgOut =
            %    SHOWOVERLAY(testImg, maskIn);
            %
            %    %Generate a second mask maskIn2 = false(size(testImg));
            %    maskIn2(100:180, 50:100) = true;
            %
            %    %Composite and display the second mask onto the same image
            %    %as a magenta layer with 50% opacity
            %    SHOWOVERLAY(imgOut, maskIn2, 'Color', [1 0 1], 'Opacity', 50);
            
            ip = inputParser;
            ip.addParameter('Color',[0 1 0]);
            ip.addParameter('Opacity',100);
            ip.parse(varargin{:});
            
            alpha = ip.Results.Opacity / 100;
            
            %Get the original image class
            imageClass = class(img);
            imageIsInteger = isinteger(img);
            
            %Process the input image
            img = double(img);
            img = img ./ max(img(:));
            
            if size(img,3) == 1
                %Convert into an RGB image
                img = repmat(img, 1, 1, 3);
            elseif size(img,3) == 3
                %Do nothing
            else
                error('showoverlay:InvalidInputImage',...
                    'Expected input to be either a grayscale or RGB image.');
            end
            
            %Process the mask
            mask = double(mask);
            mask = mask ./ max(mask(:));
            
            if size(mask,3) == 1
                %Convert mask into an RGB image
                mask = repmat(mask, 1, 1, 3);
                
                for iC = 1:3
                    mask(:,:,iC) = mask(:,:,iC) .* ip.Results.Color(iC);
                end
            elseif size(mask,3) == 3
                %Do nothing
            else
                error('showoverlay:InvalidMask',...
                    'Expected mask to be either a logical or RGB image.');
            end
            
            %Make the composite image
            replacePx = mask ~= 0;
            img(replacePx) = img(replacePx) .* (1 - alpha) + mask(replacePx) .* alpha;
            
            %Recast the image into the original image class
            if imageIsInteger
                multFactor = double(intmax(imageClass));
            else
                multFactor = 1;
            end
            
            img = img .* multFactor;
            img = cast(img, imageClass);
            
            %Produce the desired outputs
            if nargout == 0
                imshow(img,[])
            else
                varargout = {img};
            end
            
        end
        
        function imageOut = normalizeimg(imageIn,varargin)
            %NORMALIZEIMG   Linear dynamic range expansion for contrast enhancement
            %   N = NORMALIZEIMG(I) expands the dynamic range (or contrast) of image I
            %   linearly to maximize the range of values within the image.
            %
            %   This operation is useful when enhancing the contrast of an image. For
            %   example, if I is an image with uint8 format, with values ranging from
            %   30 to 100. Normalizing the image will expand the values so that they
            %   fill the full dynamic range of the format, i.e. from 0 to 255.
            %
            %   The format of the output image N depends on the format of the input
            %   image I. If I is a matrix with an integer classs (i.e. uint8, int16), N
            %   will returned in the same format. If I is a double, N will be
            %   normalized to the range [0 1] by default.
            %
            %   N = NORMALIZEIMG(I,[min max]) can also be used to specify a desired
            %   output range. For example, N = normalizeimg(I,[10,20]) will normalize
            %   image I to have values between 10 and 20. In this case, N will be
            %   returned in double format regardless of the format of I.
            %
            %   In situations where most of the interesting image features are
            %   contained within a narrower band of values, it could be useful to
            %   normalize the image to the 5 and 95 percentile values.
            %
            %   Example:
            %       I = imread('cameraman.tif');
            %
            %       %Calculate the values corresponding to the 5 and 95 percentile of
            %       %values within the image
            %       PRC5 = prctile(I(:),5);
            %       PRC95 = prctile(I(:),95);
            %
            %       %Threshold the image values to the 5 and 95 percentiles
            %       I(I<PRC5) = PRC5;
            %       I(I>PRC95) = PRC95;
            %
            %       %Normalize the image
            %       N = normalizeimg(I);%
            %
            %       %Display the normalized image
            %       imshow(N)
            
            %Define default output value range
            outputMin = 0;
            outputMax = 1;
            
            %Check if the desired output range is set. If it is, make sure it contains
            %the right number of values and format, then update the output minimum and
            %maximum values accordingly.
            if nargin >= 2
                if numel(varargin{1}) ~= 2
                    error('The input parameter should be [min max]')
                end
                
                outputMin = varargin{1}(1);
                outputMax = varargin{1}(2);
            else
                %If the desired output range is not set, then check if the image is an
                %integer class. If it is, then set the minimum and maximum values
                %to match the range of the class type.
                if isinteger(imageIn)
                    inputClass = class(imageIn);
                    
                    outputMin = 0;
                    outputMax = double(intmax(inputClass)); %Get the maximum value of the class
                    
                end
            end
            
            %Convert the image to double for the following operations
            imageIn = double(imageIn);
            
            %Calculate the output range
            outputRange = outputMax - outputMin;
            
            %Get the maximum and minimum input values from the image
            inputMin = min(imageIn(:));
            inputMax = max(imageIn(:));
            inputRange = inputMax - inputMin;
            
            %Normalize the image values to fit within the desired output range
            imageOut = (imageIn - inputMin) .* (outputRange/inputRange) + outputMin;
            
            %If the input was an integer before, make the output image the same class
            %type
            if exist('inputClass','var')
                eval(['imageOut = ',inputClass,'(imageOut);']);
            end
            
        end
        
        function imgOut = makeAnnotatedImage(iT, baseImage, cellMasks, trackData, varargin)
            %MAKEANNOTATEDIMAGE  Make annotated images
            
            showTracks = true;
            if ~isempty(varargin)
                if strcmpi(varargin{1}, 'notracks')
                    showTracks = false;
                end
            end           
            
            %Normalize the base image
            baseImage = double(baseImage);
            baseImage = baseImage ./ max(baseImage(:));
            
            imgOut = CyTracker.showoverlay(baseImage,...
                bwperim(cellMasks), 'Opacity', 100);
            
            %Write frame number on top right
            imgOut = insertText(imgOut,[size(baseImage,2), 1],iT,...
                'BoxOpacity',0,'TextColor','white','AnchorPoint','RightTop');
            
            if showTracks
                for iTrack = 1:trackData.NumTracks
                    
                    currTrack = trackData.getTrack(iTrack);
                    
                    if iT >= currTrack.FirstFrame && iT <= currTrack.LastFrame
                        
                        trackCentroid = cat(2,currTrack.Data.Centroid);
                        
                        imgOut = insertText(imgOut, currTrack.Data(end).Centroid, iTrack,...
                            'BoxOpacity', 0,'TextColor','yellow');
                        
                        if iT > currTrack.FirstFrame
                            imgOut = insertShape(imgOut, 'line', trackCentroid, 'color','white');
                        end
                    end
                    
                end
            end
        end
        
    end
    
    methods (Access = private)
        
        function sOut = getOptions(obj)
            %GETOPTIONS  Converts the object properties to a struct
            
            propList = properties(obj);
            for iP = 1:numel(propList)
                sOut.(propList{iP}) = obj.(propList{iP});
            end
        end
        
    end
    
end