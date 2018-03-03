classdef trackdataTests < matlab.unittest.TestCase
    
    methods (Test)
        
        function construct_initializeEmpty(TestObj)
            
            AA = timedata.trackdata(10);
            
            TestObj.verifyEqual(numel(AA), 10);
            TestObj.verifyEqual(size(AA), [1, 10]);
            
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
            
            for ii = 1:numel(testData.Frames)
                AA = AA.addFrame(testData.Frames(ii), testData.Data(ii));
            end
            
            TestObj.verifyEqual(numel(AA), 1);
            TestObj.verifyEqual(AA.NumFrames, numel(testData.Frames));
            
            TestObj.assertEqual(AA.data, testData.Data);
            
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
            for ii = 1:numel(testDataPost50.Frames)
                AA = AA.addFrame(testDataPost50.Frames(ii), testDataPost50.Data(ii));
            end
            
            TestObj.verifyEqual(AA.NumFrames, numel(testDataPost50.Frames));
            TestObj.assertEqual(AA.FirstFrame, 50);
                        
            %Add data pre frame 50
            for ii = 1:numel(testDataPre50.Frames)
                AA = AA.addFrame(testDataPre50.Frames(ii), testDataPre50.Data(ii));
            end
            
            TestObj.verifyEqual(AA.NumFrames, testDataPost50.Frames(end) - 10 + 1);
            TestObj.assertEqual(AA.FirstFrame, 10);
            
            %---Check data---
            
            %Empty data
            emptyData.Area = [];
            emptyData.Centroid = [];
            emptyData.Intensity = [];
            
            for iF = 1:numel(AA.data)
                if iF == 1
                    TestObj.assertEqual(AA.data(iF), testDataPre50.Data);
                elseif iF < 50 - 10 + 1
                    TestObj.assertEqual(AA.data(iF), emptyData);
                else
                    TestObj.assertEqual(AA.data(iF), testDataPost50.Data(iF - (50 - 10 + 1) + 1));
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
            for ii = 1:numel(testDataPost50.Frames)
                AA = AA.addFrame(testDataPost50.Frames(ii), testDataPost50.Data(ii));
            end
            
            TestObj.verifyEqual(AA.NumFrames, numel(testDataPost50.Frames));
            TestObj.assertEqual(AA.FirstFrame, 50);
            
            %Add data pre frame 50
            for ii = 1:numel(testDataPre50.Frames)
                AA = AA.addFrame(testDataPre50.Frames(ii), testDataPre50.Data(ii));
            end
            
            TestObj.assertEqual(AA.FirstFrame, 1);
            
            %---Check data---
            TestObj.assertEqual(AA.data(1:49), testDataPre50.Data);
            TestObj.assertEqual(AA.data(50:end), testDataPost50.Data);
        end
        
        function addFrame_addFramesWithOverwrite_EqualsOverwrittenTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(2);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Overwrite the data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(2).Data(ii),'overwrite');
            end
            
            %Check data matches second dataset
            TestObj.assertEqual(AA.data, testData(2).Data);
          
        end
        
        function addFrame_addFramesWithoutOverwrite_ThrowsException(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(2);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Verify error
            TestObj.verifyError(@() AA.addFrame(1, testData(2).Data(1)),'trackdata:addFrame:FrameDataExists');
            
        end
        
        function delFrame_delFramesAtStart_EqualsDeletedTestData(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata;
            
            %Add original data
            for ii = 1:10
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Delete the first 4 frames
            AA = AA.delFrame(1:4);
            
            TestObj.verifyEqual(AA.FirstFrame, 5);
            TestObj.verifyEqual(AA.NumFrames, 6);
            
            TestObj.assertEqual(AA.data, testData.Data(5:end));
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
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Delete the first 4 frames
            AA = AA.delFrame(3:5);
            
            TestObj.verifyEqual(AA.FirstFrame, 1);
            TestObj.verifyEqual(AA.LastFrame, 10);
            TestObj.verifyEqual(AA.NumFrames, 10);
            
            %Make an empty struct
            fn = fieldnames(testData.Data(1))';
            fn{2, 1} = cell(1,3);
            emptyData = struct(fn{:});
            
            TestObj.assertEqual(AA.data(1:2), testData.Data(1:2));
            TestObj.assertEqual(AA.data(3:5), emptyData);
            TestObj.assertEqual(AA.data(6:end), testData.Data(6:end));
           
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
                AA = AA.addFrame(5 + ii - 1, testData(1).Data(ii));
            end
            
            %Delete frames 8:10 [5 6 7 8 9 10 11 12 13 14]
            AA = AA.delFrame(8:10);
            
            TestObj.verifyEqual(AA.FirstFrame, 5);
            TestObj.verifyEqual(AA.LastFrame, 14);
            TestObj.verifyEqual(AA.NumFrames, 10);
            
            %Make an empty struct
            fn = fieldnames(testData.Data(1))';
            fn{2, 1} = cell(1,3);
            emptyData = struct(fn{:});
            
            TestObj.assertEqual(AA.data(1:3), testData.Data(1:3));
            TestObj.assertEqual(AA.data(4:6), emptyData);
            TestObj.assertEqual(AA.data(7:end), testData.Data(7:end));
           
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
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Delete the last 4 frames
            AA = AA.delFrame(7:10);
            
            TestObj.verifyEqual(AA.LastFrame, 6);
            TestObj.verifyEqual(AA.NumFrames, 6);
            
            TestObj.assertEqual(AA.data, testData.Data(1:6));
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
                AA = AA.addFrame(ii, testData(1).Data(ii));
            end
            
            %Subset the data
            BB = getFrame(AA, 7:10);
            TestObj.assertEqual(BB.data, testData.Data(7:10));
            TestObj.assertEqual(BB.frames, uint16(7:10));
            
            BB = getFrame(AA, 1:3);
            TestObj.assertEqual(BB.data, testData.Data(1:3));
            TestObj.assertEqual(BB.frames, uint16(1:3));
            
            BB = getFrame(AA, 3:6);
            TestObj.assertEqual(BB.data, testData.Data(3:6));
            TestObj.assertEqual(BB.frames, uint16(3:6));
            
        end
        
    end
    
end