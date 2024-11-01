classdef test_TrackArray < matlab.unittest.TestCase
    
    methods (Test)
        
        function addTrack_singleTrack(testCase)      
            %Add a single track to the array
            %This test defines the expected output structure.
            
            array = TrackArray;
            
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            
            [array, newTrackID] = addTrack(array, 1, testdata);
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 1, ...
                'Data', struct(...            
                'Length', {{10}},...
                'PxIdxList', {{[10, 20 30]}},...
                'Classification', {{'Blue'}}));
            
            testCase.assertEqual(array.Tracks(1), expectedData);
            testCase.assertEqual(newTrackID, 1);
            
        end
       
        function addTrack_multipleTracks(testCase)
            
            array = TrackArray;
            
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            testdata(2).Length = 5;
            testdata(2).PxIdxList = [30 10 5];
            testdata(2).Classification = 'Yellow';
            
            [array, newTrackID] = addTrack(array, 1, testdata);
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 1, ...
                'Data', struct(...            
                'Length', {{10}},...
                'PxIdxList', {{[10, 20 30]}},...
                'Classification', {{'Blue'}}));
            
            expectedData2 = struct(...
                'ID', 2, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 1, ...
                'Data', struct(...
                'Length', {{5}},...
                'PxIdxList', {{[30, 10 5]}},...
                'Classification', {{'Yellow'}}));
            
            
            testCase.assertEqual(array.Tracks(1), expectedData);
            testCase.assertEqual(array.Tracks(2), expectedData2);
            testCase.assertEqual(newTrackID, [1, 2]);
            
        end
        
        function updateTrack_appendToStart(testCase)
            %Update by adding frame to the start
            %This test defines the expected output structure.
            
            array = TrackArray;
            
            %Add some data
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            array = addTrack(array, 3, testdata);
            
            %Update the data
            testdata2 = struct('Length', 100, 'PxIdxList', [30 10], 'Color', 'Yellow');
            array = updateTrack(array, 1, 2, testdata2);
            
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [2 3]);
            expectedData.Data.Length = {100, 10};
            expectedData.Data.PxIdxList = {[30 10], [10, 20 30]};
            expectedData.Data.Classification = {[], 'Blue'};
            expectedData.Data.Color = {'Yellow', []};
                
            testCase.assertEqual(array.Tracks(1), expectedData);
            
        end
        
        function updateTrack_appendToEnd(testCase)
            %Update by adding frame to the end
            %This test defines the expected output structure.
            
            array = TrackArray;
            
            %Add some data
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            array = addTrack(array, 2, testdata);
            
            %Update the data
            testdata2 = struct('Length', 100, 'PxIdxList', [30 10], 'Color', 'Yellow');
            array = updateTrack(array, 1, 3, testdata2);
            
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [2 3]);
            expectedData.Data.Length = {10, 100};
            expectedData.Data.PxIdxList = {[10, 20 30], [30 10]};
            expectedData.Data.Classification = {'Blue', []};
            expectedData.Data.Color = {[], 'Yellow'};
                
            testCase.assertEqual(array.Tracks(1), expectedData);
            
        end  
        
        function updateTrack_motherDaughterIDs(testCase)
            
            array = TrackArray;
            
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            
            [array, newTrackID] = addTrack(array, 1, testdata);
            
            array = setMotherID(array, 1, 5);
            array = setDaughterID(array, 1, [10 11]);
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', 5, ...
                'DaughterID', [10 11], ...
                'Frames', 1, ...
                'Data', struct(...
                'Length', {{10}},...
                'PxIdxList', {{[10, 20 30]}},...
                'Classification', {{'Blue'}}));
            
            testCase.assertEqual(array.Tracks(1), expectedData);
            
            
            
        end
                
        function updateTrack_modifyExisting(testCase)
            %Update by adding frame to the end
            %This test defines the expected output structure.
            
            array = TrackArray;
            
            %Add some data
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            array = addTrack(array, 2, testdata);
            
            %Update the data
            testdata2 = struct('Length', 100, 'PxIdxList', [30 10], 'Color', 'Yellow');
            array = updateTrack(array, 1, 2, testdata2);
            
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 2);
            expectedData.Data.Length = {100};
            expectedData.Data.PxIdxList = {[30 10]};
            expectedData.Data.Classification = {'Blue'};
            expectedData.Data.Color = {'Yellow'};
                
            testCase.assertEqual(array.Tracks(1), expectedData);
            
        end  
        
        function updateTrack_multipleFrames(testCase)

            array = TrackArray;

            %Define input data
            data.Length = 10;
            array = addTrack(array, 1, data);

            data.Length = 20;
            array = updateTrack(array, 1, 2, data);

            data.Length = 30;
            array = updateTrack(array, 1, 3, data);

            %Create new data
            newData.Length = 40;
            newData(2).Length = 50;
            newData(3).Length = 60;

            array = updateTrack(array, 1, [4, 5, 6], newData);

            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [1 2 3 4 5 6]);
            expectedData.Data.Length = {10, 20, 30, 40, 50, 60};

            testCase.assertEqual(array.Tracks(1), expectedData);

        end


        function updateTrack_dataIsCell_append(testCase)
            %Test that cell data (i.e. if multiple PixelIdxList) is added
            %correctly.

            array = TrackArray;

            %Add some data
            testdata.Length = 10;
            testdata.PxIdxList = {[10, 20 30], [40, 50]};
            testdata.Color = 'Blue';

            %Add data to frame 1
            array = addTrack(array, 1, testdata);

            %Add data to frame 2
            testdata2.Length = 100;
            testdata2.PxIdxList = {[30 10], [1 5]};
            testdata2.Color = 'Yellow';

            array = updateTrack(array, 1, 2, testdata2);

            %Expected results
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [1 2]);
            expectedData.Data.Length = {10, 100};
            expectedData.Data.PxIdxList = {{[10, 20 30], [40, 50]}, {[30 10], [1 5]}};
            expectedData.Data.Color = {'Blue', 'Yellow'};

            testCase.assertEqual(array.Tracks(1), expectedData);

        end

        function updateTrack_dataIsCell_prepend(testCase)
            %Test that cell data (i.e. if multiple PixelIdxList) is added
            %correctly if added before a frame

            array = TrackArray;

            %Add some data
            testdata.Length = 10;
            testdata.PxIdxList = {[10, 20 30], [40, 50]};
            testdata.Color = 'Blue';

            %Add data to frame 2
            array = addTrack(array, 2, testdata);

            %Add data to frame 1
            testdata2.Length = 100;
            testdata2.PxIdxList = {[30 10], [1 5]};
            testdata2.Color = 'Yellow';

            array = updateTrack(array, 1, 1, testdata2);

            %Expected results
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [1 2]);
            expectedData.Data.Length = {100, 10};
            expectedData.Data.PxIdxList = {{[30 10], [1 5]}, {[10, 20 30], [40, 50]}};
            expectedData.Data.Color = {'Yellow', 'Blue'};

            testCase.assertEqual(array.Tracks(1), expectedData);

        end

        function updateTrack_dataIsCell_update(testCase)
            %Test that cell data (i.e. if multiple PixelIdxList) is added
            %correctly if updating an existing frame

            array = TrackArray;

            %Add some data
            testdata.Length = 10;
            testdata.PxIdxList = {[10, 20 30], [40, 50]};
            testdata.Color = 'Blue';

            %Add data to frame 2
            array = addTrack(array, 2, testdata);

            %Update data in frame 2
            testdata2.Length = 100;
            testdata2.PxIdxList = {[30 10], [1 5]};
            testdata2.Color = 'Yellow';

            array = updateTrack(array, 1, 2, testdata2);

            %Expected results
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 2);
            expectedData.Data.Length = {100};
            expectedData.Data.PxIdxList = {{[30 10], [1 5]}};
            expectedData.Data.Color = {'Yellow'};

            testCase.assertEqual(array.Tracks(1), expectedData);

        end


        function deleteTrack_deleteExisting(testCase)
            
            array = TrackArray;
            
            %Add a track
            testdata = struct('Length', 10);
            array = addTrack(array, 3, testdata);
            
            %Add a second track
            testdata2 = struct('Length', 100);
            array = addTrack(array, 1, testdata2);
            
            %Delete the first track
            array = deleteTrack(array, 1);
            
            %Check second track data
            expected.ID = 2;
            expected.Frames = 1;
            expected.MotherID = NaN;
            expected.DaughterID = NaN;
            expected.Data.Length = {100};
            
            testCase.assertEqual(array.Tracks, expected);
            
            
        end
        
        function deleteFrame_singleFrame(testCase)
            %Create a new track with multiple frames
                        
            array = TrackArray;
            
            %Add a new track
            testdata = struct('Length', 10);
            array = addTrack(array, 4, testdata);
            
            %Add a new frame
            testdata2 = struct('Length', 20);
            array = updateTrack(array, 1, 5, testdata2);
            
            %Add a third frame
            testdata3 = struct('Length', 30);
            array = updateTrack(array, 1, 6, testdata3);
            
            %Delete frame 5
            array = deleteFrame(array, 1, 5);
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [4, 6]);
            expectedData.Data.Length = {10, 30};
            
            testCase.assertEqual(array.Tracks(1), expectedData);
            
            
        end
        
        function getTrack_singleTrack(testCase)

            array = TrackArray;
            
            %Define input data
            data.Length = 10;
            data.PxIdxList = [10, 30, 50];
            data.Centroid = [5, 2];
            array = addTrack(array, 1, data);
                
            data2.PxIdxList = [10, 20];
            data2.Centroid = [6, 7];
            array = updateTrack(array, 1, 2, data2);
            
            data3.Length = 40;
            data3.PxIdxList = [80, 90];
            data3.Centroid = [8, 10];
            array = updateTrack(array, 1, 3, data3);
            
            output = getTrack(array, 1);
            
            expected.ID = 1;
            expected.MotherID = NaN;
            expected.DaughterID = NaN;
            expected.Frames = [1, 2, 3];
            expected.Length = [10; NaN; 40];
            expected.PxIdxList = {[10, 30, 50], [10, 20], [80, 90]};
            expected.Centroid = [5, 2; 6, 7; 8, 10];
            
            testCase.assertEqual(output, expected);
            
        end
      
        function getTrack_singleTrack_singleFrame(testCase)

            array = TrackArray;
            
            %Define input data
            data.Length = 10;
            data.PxIdxList = [10, 30, 50];
            data.Centroid = [5, 2];
            array = addTrack(array, 1, data);
                
            data2.PxIdxList = [10, 20];
            data2.Centroid = [6, 7];
            data2.Color = 'White';
            array = updateTrack(array, 1, 2, data2);
            
            data3.Length = 40;
            data3.PxIdxList = [80, 90];
            data3.Centroid = [8, 10];
            array = updateTrack(array, 1, 3, data3);
            
            output = getTrack(array, 1, 2);
            
            expected.ID = 1;
            expected.MotherID = NaN;
            expected.DaughterID = NaN;
            expected.Frames = 2;
            expected.Length = NaN;
            expected.PxIdxList = [10, 20];
            expected.Centroid = [6, 7];
            expected.Color = 'White';
            
            testCase.assertEqual(output, expected);
            
        end
        
        function splitTrack(testCase)
            
            %Update by adding frame to the end
            %This test defines the expected output structure.
            
            array = TrackArray;
            
            %Add some data
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Color', 'Blue');
            array = addTrack(array, 1, testdata);
            
            %Update the data
            testdata2 = struct('Length', 100, 'PxIdxList', [30 10], 'Color', 'Yellow');
            array = updateTrack(array, 1, 2, testdata2);
            
            testdata3 = struct('Length', 200, 'PxIdxList', [15 20], 'Color', 'Green');
            array = updateTrack(array, 1, 3, testdata3);
            
            
            %Split the track at frame 3
            array = splitTrack(array, 1, 3);
            
            %Generate expected data
            expectedData.ID = 1;
            expectedData.MotherID = NaN;
            expectedData.DaughterID = NaN;
            expectedData.Frames = [1 2];
            
            expectedData.Data.Length = {10, 100};
            expectedData.Data.PxIdxList = {[10, 20 30], [30 10]};
            expectedData.Data.Color = {'Blue', 'Yellow'};
            
            
            
            expectedData(2).ID = 2;
            expectedData(2).MotherID = NaN;
            expectedData(2).DaughterID = NaN;
            expectedData(2).Frames = 3;
            
            expectedData(2).Data.Length = {200};
            expectedData(2).Data.PxIdxList = {[15, 20]};
            expectedData(2).Data.Color = {'Green'};
                        
            %Test original track
            testCase.assertEqual(array.Tracks, expectedData);
           
            
        end
        
        function saveandload(testCase)
            
            array = TrackArray;
            
            testdata = struct('Length', 10, 'PxIdxList', [10, 20 30], 'Classification', 'Blue');
            testdata(2).Length = 5;
            testdata(2).PxIdxList = [30 10 5];
            testdata(2).Classification = 'Yellow';
            
            [array, newTrackID] = addTrack(array, 1, testdata);
            
            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 1, ...
                'Data', struct(...
                'Length', {{10}},...
                'PxIdxList', {{[10, 20 30]}},...
                'Classification', {{'Blue'}}));
            
            expectedData2 = struct(...
                'ID', 2, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', 1, ...
                'Data', struct(...
                'Length', {{5}},...
                'PxIdxList', {{[30, 10 5]}},...
                'Classification', {{'Yellow'}}));
            
            save('tmptest.mat', 'array');
            
            clearvars array
            
            load('tmptest.mat', 'array');
            
            testCase.assertEqual(array.Tracks(1), expectedData);
            testCase.assertEqual(array.Tracks(2), expectedData2);
            testCase.assertEqual(newTrackID, [1, 2]);
            
            delete('tmptest.mat');
            
        end
        
        function setFileMetadata(testCase)
            
            array = TrackArray;
            
            array = setFileMetadata(array, ...
                'Filename', 'test.nd2', ...
                'PxSize', [10, 10], ...
                'PxSizeUnits', 'seconds');
            
            expectedData.Filename = 'test.nd2';
            expectedData.PxSize = [10 10];
            expectedData.PxSizeUnits = 'seconds';
            
            testCase.assertEqual(array.FileMetadata, expectedData);
            
            
        end
        
        function traversal_levelorder(testCase)
            % Example tree:
            %
            %               1
            %             /   \
            %            2     3
            %           /  \
            %          4    5
            %
            
            array = TrackArray;
            
            data.Length = 1;
            
            %Create the tree
            array = addTrack(array, 1, data);
            array = setDaughterID(array, 1, [2, 3]);
            
            array = addTrack(array, 2, data);
            array = addTrack(array, 3, data);
            
            array = setMotherID(array, 2, 1);
            array = setMotherID(array, 3, 1);
            array = setDaughterID(array, 2, [4, 5]);
            
            array = addTrack(array, 4, data);
            array = addTrack(array, 5, data);
            array = setMotherID(array, 4, 2);
            array = setMotherID(array, 5, 2);
            
            IDout = traverse(array, 1, 'level');
            
            testCase.assertEqual(IDout, [1, 2, 3, 4, 5]);
            
            
        end
        
        function traversal_preorder(testCase)
            % Example tree:
            %
            %               1
            %             /   \
            %            2     3
            %           /  \
            %          4    5
            %
            
            array = TrackArray;
            
            data.Length = 1;
            
            %Create the tree
            array = addTrack(array, 1, data);
            array = setDaughterID(array, 1, [2, 3]);
            
            array = addTrack(array, 2, data);
            array = addTrack(array, 3, data);
            
            array = setMotherID(array, 2, 1);
            array = setMotherID(array, 3, 1);
            array = setDaughterID(array, 2, [4, 5]);
            
            array = addTrack(array, 4, data);
            array = addTrack(array, 5, data);
            array = setMotherID(array, 4, 2);
            array = setMotherID(array, 5, 2);
            
            %Add non-connected track to check that output ID lengths are
            %correct
            array = addTrack(array, 6, data);
            
            IDout = traverse(array, 1, 'preorder');
            
            testCase.assertEqual(IDout, [1, 2, 4, 5, 3]);
            
            
        end
        
        function joinTrack (testCase)

            array = TrackArray;

            %Define input data
            data.Length = 10;
            array = addTrack(array, 1, data);
                
            data.Length = 20;
            array = updateTrack(array, 1, 2, data);
            
            data.Length = 30;
            array = updateTrack(array, 1, 3, data);

            %Define input data
            data.Length = 40;
            array = addTrack(array, 4, data);

            data.Length = 50;
            array = updateTrack(array, 2, 5, data);

            data.Length = 60;
            array = updateTrack(array, 2, 6, data);

            array = joinTrack(array, 1, 2);

            expectedData = struct(...
                'ID', 1, ...
                'MotherID', NaN, ...
                'DaughterID', NaN, ...
                'Frames', [1 2 3 4 5 6]);
            expectedData.Data.Length = {10, 20, 30, 40, 50, 60};

            testCase.assertEqual(array.Tracks(1), expectedData);
            testCase.assertEqual(numel(array.Tracks), 1);



        end
        
        
        
    end
end