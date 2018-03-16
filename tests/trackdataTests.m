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
                
        function addFrame_insertFramesWithOverwrite_EqualsOverwrittenTestData(TestObj)
            
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
        
        function addFrame_insertFramesWithoutOverwrite_ThrowsException(TestObj)
            
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
        
        function addFrame_toTrackObjectArray_ThrowsException(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 5);
            
            %Make an object array
            AA = timedata.trackdata.struct2track(testData(1:2));
            
            TestObj.assertError(@() addFrame(AA, 900, testData(3).data(1)), 'trackdata:addFrame:CannotAddToArray');            
            
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
        
        function delFrame_deleteAllFrames_ObjectIsEmpty(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(1);
            
            AA = timedata.trackdata.struct2track(testData);            
            
            %Delete all the frames
            AA = AA.delFrame(1:10);
            
            TestObj.verifyEqual(AA.numFrames, 0);
            
            TestObj.assertEmpty(AA.data);
            TestObj.assertEmpty(AA.frames);
            
        end
        
        function delFrame_trackisObjArray_FramesDeletedFromTrack(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(5);
            
            AA = timedata.trackdata.struct2track(testData);
            
            AA = delFrame(AA, 1:3);
            
            TestObj.assertTrue(all([AA.firstFrame] == 4));
            
            for iTrack = 1:numel(AA)
                TestObj.assertEqual(AA(iTrack).data, testData(iTrack).data(4:end));
            end
                 
        end
        
        function delFrame_trackIsObjArrayWithDifferentNumFrames_FramesDeleted(TestObj)
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 5;
            track1 = timedata.trackdata.struct2track(TDG.generateTracks(1));
            
            TDG.numFrames = 10;
            track2 = timedata.trackdata.struct2track(TDG.generateTracks(1));
            
            %Make an empty struct
            fn = fieldnames(track1.data(1))';
            fn{2, 1} = cell(1,1);
            emptyData = struct(fn{:});
                        
            AA = [track1; track2];
            
            AA = delFrame(AA, 4:7);
            
            TestObj.assertEqual(AA(1).lastFrame, 3)
            
            TestObj.assertEqual(AA(2).data(4), emptyData);   
            
        end
        
        function delFrame_trackIsObjArray_FramesNotInTrackRange_FramesDeleted(TestObj)
            %Track 1 has frames 1 : 5
            %Track 2 has frames 1 : 10
            % delFrame(A, 6:10) on this array should only affect track 2.
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 5;
            t1Data = TDG.generateTracks(1);
            track1 = timedata.trackdata.struct2track(t1Data);
            
            TDG.numFrames = 10;
            t2Data = TDG.generateTracks(1);
            track2 = timedata.trackdata.struct2track(t2Data);
            
            %Make an empty struct
            fn = fieldnames(t1Data.data(1))';
            fn{2, 1} = cell(1,1);
            emptyData = struct(fn{:});
            
            AA = [track1; track2];
            
            AA = delFrame(AA, 6:10);
            
            TestObj.assertEqual(AA(1).data, t1Data.data)
            TestObj.assertEqual(AA(2).data, t2Data.data(1:5));
            TestObj.assertEqual(AA(2).lastFrame, 5);
            
        end
        
        function delFrame_trackIsEmpty_WarningFree(TestObj)
            
            AA = timedata.trackdata;
            
            TestObj.verifyWarningFree(@() delFrame(AA, 5));
            
        end
        
        
        function delFrameByIndex_IndexOutOfRange_ExceptionThrown(TestObj)
            
            AA = timedata.trackdata;
            
            TestObj.verifyError(@() delFrameByIndex(AA, 5), 'trackdata:IndexOutOfRange');
            
        end
        
        
        
        function updateProperty(TestObj)
            
            %Change track property e.g. intensity values
            
            error('Not implemented.')
            
            
        end
        
        
        function getFrame_getFrameRange_EqualsSubsetOfTestData(TestObj)
            
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
        
        function getFrame_trackIsObjArray_objArrayOutEqualsSubsetOfTestData(TestObj)
            %If the object is an array, taking the subset should return all
            %the specified frames for each track. The output should also be
            %a track array.
            
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = TDG.generateTracks(10);
            
            AA = timedata.trackdata.struct2track(testData);
            
            BB = getFrame(AA, 3:7);
            
            for iTrack = 1:numel(BB)
                TestObj.assertEqual(BB(iTrack).data, AA(iTrack).data(3:7));
            end
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
        
        function struct2track_structMissingFields_ExceptionThrown(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 1);
            
            %Try to create a track with only the data struct
            TestObj.assertError(@() timedata.trackdata.struct2track(testData.data),'trackdata:struct2track:MissingFields');            
            
        end
        
        function struct2track_FrameNumAndDataMismatch_ExceptionThrown(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 1);
            
            %Delete some data points
            testData.data(7:end) = [];
            
            %Try to create a track
            TestObj.assertError(@() timedata.trackdata.struct2track(testData),'trackdata:struct2track:NumDataMismatch');
            
        end
        
        function modifyTrackID_trackIDLargerThanUInt32_ExceptionThrown(TestObj)
            %TrackIDs are uint32s. If a new track is created with a larger
            %ID, an exception should be thrown
            
            TDG = trackDataGenerator;
            
            testTrack = timedata.trackdata.struct2track(generateTracks(TDG, 1));
            
            maxID = intmax('uint32');
            
            %Modify the trackID
            try
                testTrack.trackID = maxID + 100;
            catch ME
                TestObj.assertEqual(ME.identifer, 'trackdata:NumTooLarge');
            end
        end
        
        
        function horzcatTracks_catTracks_addsTracksToEnd(TestObj)
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 1);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1 track2];
            TestObj.assertEqual(size(TA), [1 2]);
            
        end
        
        function horzcatTracks_catTracksDifferentSizes_addsTracksToEnd(TestObj)
            %Joining tracks where one track is already an array
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 5);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1 track2];
            TestObj.assertEqual(size(TA), [1 6]);
            
        end
        
        function horzcatTracks_catMultipleTracks(TestObj)
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 1);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1 track2 track1 track2];
            TestObj.assertEqual(size(TA), [1 4]);
            
            TestObj.assertEqual(TA(1).data, track1data.data);
            TestObj.assertEqual(TA(2).data, track2data.data);
            TestObj.assertEqual(TA(3).data, track1data.data);
            TestObj.assertEqual(TA(4).data, track2data.data);
                        
        end
        
        
        function vertcatTracks_catTracksDifferentSizes_performsHorzcat(TestObj)
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 5);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1; track2];
            
            TestObj.assertEqual(size(TA), [1 6]);
        end
        
        function vertcatTracks_catMultipleTracks(TestObj)
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 5);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1; track2; track1; track2];
            
            TestObj.assertEqual(size(TA), [1 12]);
        end
        
        
        function renumberTracks_NewtrackIDsAreConsecutive(TestObj)
            
            TDG = trackDataGenerator;
            track1data = generateTracks(TDG, 1);
            track1 = timedata.trackdata.struct2track(track1data);
            
            track2data = generateTracks(TDG, 1);
            track2 = timedata.trackdata.struct2track(track2data);
            
            TA = [track1 track2 track1 track2];
            TA = renumberTracks(TA);
            
            TestObj.assertEqual([TA.trackID], uint32(1:4))
            
        end
        
        function reorderTracks_TracksAreOrderedByID(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 5);
            
            %Create the tracks in a random order
            trackOrder = randperm(numel(testData));
            
            AA = timedata.trackdata(numel(testData));
            for iTrack = 1:numel(testData)
                AA(iTrack) = timedata.trackdata.struct2track(testData(trackOrder(iTrack)));
            end
            
            TestObj.assertEqual([AA.trackID], uint32(trackOrder));
            
            AA = reorderTracks(AA);
            TestObj.assertEqual([AA.trackID], uint32(1:numel(testData)));
            
            %Check that data has been reordered
            for ii = 1:numel(AA)
                TestObj.assertEqual(AA(ii).data, testData(ii).data);
            end
            
        end
        
    end
    
end