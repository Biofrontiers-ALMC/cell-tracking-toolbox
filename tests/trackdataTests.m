classdef trackdataTests < matlab.unittest.TestCase
    
    methods (Test)
        
        function construct_initializeEmpty_haveSequentialtrackIDs(TestObj)
            
            AA = timedata.trackdata(10);
            
            TestObj.verifyEqual(numel(AA), 10);
            TestObj.verifyEqual(size(AA), [1, 10]);
            
            TestObj.verifyEqual([AA.trackID], uint32(1:10));
            
        end
        
        function construct_initializeSeriesIDandMotherTrackID(TestObj)
            
            AA = timedata.trackdata(10, 'seriesID', 2, 'motherTrackID', 8);
            
            TestObj.verifyEqual(numel(AA), 10);
            TestObj.verifyEqual(size(AA), [1, 10]);
            
            for nn = 1:numel(AA)
                TestObj.assertEqual(AA(nn).seriesID , uint32(2));                
                TestObj.assertEqual(AA(nn).motherTrackID , uint32(8));     
            end
            
        end
        
        function constructMultiDim_ThrowsException(TestObj)
            
            TestObj.verifyError(@() timedata.trackdata([8, 10]), 'trackdata:InvalidSize')
                        
        end
        
        function addFrame_addFramesSequentiallyAfter_EqualsTestData(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG,1);
            
            AA = timedata.trackdata;
            
            for ii = 1:numel(testData.frames)
                AA = AA.addFrame(testData.frames(ii), testData.data(ii));
            end
            
            TestObj.verifyEqual(numel(AA), 1);
            TestObj.verifyEqual(AA.numFrames, numel(testData.frames));
            TestObj.assertEqual(AA.data, testData.data);
            
        end
        
        function addFrame_add1FrameBefore_EqualsTestDataHasEmptyStruct(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 50;
            testDataPost50 = TDG.generateTracks(1);
            
            TDG.firstFrame = 10;
            TDG.numFrames = 1;
            testDataPre50 = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add data post frame 50
            for ii = 1:numel(testDataPost50.frames)
                AA = AA.addFrame(testDataPost50.frames(ii), testDataPost50.data(ii));
            end
            
            TestObj.verifyEqual(AA.numFrames, numel(testDataPost50.frames));
            TestObj.assertEqual(AA.firstFrame, 50);
                        
            %Add data pre frame 50
            for ii = 1:numel(testDataPre50.frames)
                AA = AA.addFrame(testDataPre50.frames(ii), testDataPre50.data(ii));
            end
            
            TestObj.verifyEqual(AA.numFrames, testDataPost50.frames(end) - 10 + 1);
            TestObj.assertEqual(AA.firstFrame, 10);
            
            %---Check data---
            
            %Empty data
            emptyData.Area = [];
            emptyData.Centroid = [];
            emptyData.Intensity = [];
            
            for iF = 1:numel(AA.data)
                if iF == 1
                    TestObj.assertEqual(AA.data(iF), testDataPre50.data);
                elseif iF < 50 - 10 + 1
                    TestObj.assertEqual(AA.data(iF), emptyData);
                else
                    TestObj.assertEqual(AA.data(iF), testDataPost50.data(iF - (50 - 10 + 1) + 1));
                end
            end
            
        end
        
        function addFrame_addFramesBefore_EqualsTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 50;
            testDataPost50 = TDG.generateTracks(1);
            
            TDG.firstFrame = 1;
            TDG.numFrames = 49;
            testDataPre50 = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add data post frame 50
            for ii = 1:numel(testDataPost50.frames)
                AA = AA.addFrame(testDataPost50.frames(ii), testDataPost50.data(ii));
            end
            
            TestObj.verifyEqual(AA.numFrames, numel(testDataPost50.frames));
            TestObj.assertEqual(AA.firstFrame, 50);
            
            %Add data pre frame 50
            for ii = 1:numel(testDataPre50.frames)
                AA = AA.addFrame(testDataPre50.frames(ii), testDataPre50.data(ii));
            end
            
            TestObj.assertEqual(AA.firstFrame, 1);
            
            %---Check data---
            TestObj.assertEqual(AA.data(1:49), testDataPre50.data);
            TestObj.assertEqual(AA.data(50:end), testDataPost50.data);
        end
        
        function addFrame_addFramesWithOverwrite_EqualsOverwrittenTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(2);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Overwrite the data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(2).data(ii),'overwrite');
            end
            
            %Check data matches second dataset
            TestObj.assertEqual(AA.data, testData(2).data);
          
        end
        
        function addFrame_addFramesWithoutOverwrite_ThrowsException(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(2);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Verify error
            TestObj.verifyError(@() AA.addFrame(1, testData(2).data(1)),'trackdata:addFrame:FrameDataExists');
            
        end
        
        function delFrame_delFramesAtStart_EqualsDeletedTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Delete the first 4 frames
            AA = AA.delFrame(1:4);
            
            TestObj.verifyEqual(AA.firstFrame, 5);
            TestObj.verifyEqual(AA.numFrames, 6);
            
            TestObj.assertEqual(AA.data, testData.data(5:end));
            TestObj.assertEqual(AA.frames, uint16(5:10));
        end
        
        function delFrame_delFramesInMiddleFirstFrame1_DeletedFramesAreEmpty(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Delete the first 4 frames
            AA = AA.delFrame(3:5);
            
            TestObj.verifyEqual(AA.firstFrame, 1);
            TestObj.verifyEqual(AA.lastFrame, 10);
            TestObj.verifyEqual(AA.numFrames, 10);
            
            %Make an empty struct
            fn = fieldnames(testData.data(1))';
            fn{2, 1} = cell(1,3);
            emptyData = struct(fn{:});
            
            TestObj.assertEqual(AA.data(1:2), testData.data(1:2));
            TestObj.assertEqual(AA.data(3:5), emptyData);
            TestObj.assertEqual(AA.data(6:end), testData.data(6:end));
           
            TestObj.assertEqual(AA.frames, uint16(1:10));
            
        end
        
        function delFrame_delFramesInMiddleFirstFrameNot1_DeletedFramesAreEmpty(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 5;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(5 + ii - 1, testData(1).data(ii));
            end
            
            %Delete frames 8:10 [5 6 7 8 9 10 11 12 13 14]
            AA = AA.delFrame(8:10);
            
            TestObj.verifyEqual(AA.firstFrame, 5);
            TestObj.verifyEqual(AA.lastFrame, 14);
            TestObj.verifyEqual(AA.numFrames, 10);
            
            %Make an empty struct
            fn = fieldnames(testData.data(1))';
            fn{2, 1} = cell(1,3);
            emptyData = struct(fn{:});
            
            TestObj.assertEqual(AA.data(1:3), testData.data(1:3));
            TestObj.assertEqual(AA.data(4:6), emptyData);
            TestObj.assertEqual(AA.data(7:end), testData.data(7:end));
           
            TestObj.assertEqual(AA.frames, uint16(5:14));
        end
        
        function delFrame_delFramesFromEnd_EqualsDeletedTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Delete the last 4 frames
            AA = AA.delFrame(7:10);
            
            TestObj.verifyEqual(AA.lastFrame, 6);
            TestObj.verifyEqual(AA.numFrames, 6);
            
            TestObj.assertEqual(AA.data, testData.data(1:6));
            TestObj.assertEqual(AA.frames, uint16(1:6));
        end
        
        function getFrame_getFramesAnywhere_EqualsSubsetOfTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).data(ii));
            end
            
            %Subset the data
            BB = getFrame(AA, 7:10);
            TestObj.assertEqual(BB.data, testData.data(7:10));
            TestObj.assertEqual(BB.frames, uint16(7:10));
            
            BB = getFrame(AA, 1:3);
            TestObj.assertEqual(BB.data, testData.data(1:3));
            TestObj.assertEqual(BB.frames, uint16(1:3));
            
            BB = getFrame(AA, 3:6);
            TestObj.assertEqual(BB.data, testData.data(3:6));
            TestObj.assertEqual(BB.frames, uint16(3:6));
            
        end
        
        function track2struct_exportToStruct_StructDataEqualsTestData(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG,10);
            
            %Initialize a trackdata array
            AA = timedata.trackdata.struct2track(testData);
            
            %Export the data into a struct
            testOutput = track2struct(AA);
            
            %Verify the data in each track
            for iTrack = 1:10
                TestObj.assertEqual(testOutput(iTrack).data, testData(iTrack).data);
                TestObj.assertEqual(testOutput(iTrack).frames, uint16(testData((iTrack)).frames));
            end
        end
        
        function struct2track_fromStruct_newTrackdataEqualsTestData(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            AA = timedata.trackdata.struct2track(testData);
            
            TestObj.assertClass(AA, 'timedata.trackdata');
            TestObj.assertEqual(numel(AA), 10);
            
            %Check the data
            for iTrack = 1:numel(AA)
                TestObj.assertEqual(AA(iTrack).trackID, uint32(testData(iTrack).trackID));
               
                TestObj.assertEqual(AA(iTrack).seriesID, uint32(testData(iTrack).seriesID));
                TestObj.assertEqual(AA(iTrack).motherTrackID, uint32(testData(iTrack).motherTrackID));
                TestObj.assertEqual(AA(iTrack).daughterTrackIDs, uint32(testData(iTrack).daughterTrackIDs));
                
                TestObj.assertEqual(AA(iTrack).data, testData(iTrack).data);
                TestObj.assertEqual(AA(iTrack).frames, uint16(testData(iTrack).frames));
            end            
            
        end
        
    end
    
end