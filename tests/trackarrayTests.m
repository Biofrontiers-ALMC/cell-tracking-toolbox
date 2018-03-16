classdef trackarrayTests < matlab.unittest.TestCase

    methods (Test)
        
        function construct_initializeEmptyArray_correctNumTracksCreated(TestObj)
            
            TA = timedata.trackarray(10);
            TestObj.assertEqual(TA.numTracks, 10);
            
            TestObj.assertEqual([TA.tracks.trackID], uint32(1:10));
            
        end
        
        function construct_initializeFromStruct_correctNumTracksCreated(TestObj)
            
            %Generate some tracks
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TestObj.assertEqual(TA.numTracks, 10);            
            
            for iTrack = 1:TA.numTracks
                TestObj.assertEqual(TA.tracks(iTrack).data, testData(iTrack).data);
            end
        end
        
        function construct_inputTrackData_createObjFromTracks(TestObj)
            
            %Generate some tracks
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            tracks = timedata.trackdata.struct2track(testData);
            
            TA = timedata.trackarray(tracks);
            
            for ii = 1:numel(TA.numTracks)
                TestObj.assertEqual(TA.tracks(ii).data, tracks(ii).data);
            end           
            
        end
        
        function construct_inputNotScalarStructOrTrackdata_exceptionThrown(TestObj)
            
            TestObj.verifyError(@() timedata.trackarray([1 2 3 4 5]),'trackarray:InvalidInputType');
            
        end
        
        
        function addTrack_addEmptyTracks_trackIDandDataValid(TestObj)
            
            TA = timedata.trackarray;
            
            TA = addTrack(TA,5);
            TestObj.assertEqual(TA.numTracks, 5);
            
            TA = addTrack(TA,3);
            TestObj.assertEqual(TA.numTracks, 8);

            TestObj.assertEqual([TA.tracks.trackID], uint32(1:8));
        end
        
        function addTrack_addTrackObjects_objectsAdded(TestObj)
            
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            trackArray = timedata.trackdata.struct2track(testData);
            
            TA = timedata.trackarray;
            for ii = 1:numel(trackArray)
                TA = addTrack(TA, trackArray(ii));                
            end
            
            for ii = 1:TA.numTracks
                TestObj.assertEqual(TA.tracks(ii).data, testData(ii).data);
            end
            
        end
        
        function addTrack_deleteMiddleTracks_newTrackIDconsecutive(TestObj)
            %Initial track IDs are 1, 2, 3, 4, 5
            % Delete track ~= 5, new track ID should be 6
            % Delete track 5, new track ID should be 5
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TA = TA.delTrackByID([2 4]);
            
            newTrack = timedata.trackdata.struct2track(generateTracks(TDG, 1));
            
            [TA, newTrackInd] = TA.addTrack(newTrack);
                                  
            TestObj.assertEqual(TA.tracks(newTrackInd).trackID, uint32(11));
            
        end
        
        function addTrack_deleteEndTrack_newTrackIDconsecutive(TestObj)
            %Initial track IDs are 1, 2, 3, 4, 5
            % Delete track 5, new track ID should be 5
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TA = TA.delTrackByID(10);
            
            newTrack = timedata.trackdata.struct2track(generateTracks(TDG, 1));
            [TA, newTrackID] = TA.addTrack(newTrack);
            
            TestObj.assertEqual(TA.tracks(newTrackID).trackID, uint32(10));
            
        end
        
        function addTrack_addFromStruct_objectsAdded(TestObj)
            %Add regionprops like data
            
            TDG = trackDataGenerator;
            TDG.numFrames = 20; %equiv to 20 new tracks
            testData = generateTracks(TDG,1);
            
            testData = testData.data;
            
            TA = timedata.trackarray;
            TA = addTrack(TA, 5, testData);
            
            TestObj.assertEqual(TA.numTracks, 20);
            TestObj.assertTrue(all([TA.tracks.firstFrame] == 5));
            for ii = 1:20
                TestObj.assertEqual(TA.tracks(ii).data, testData(ii))                
            end
            
        end       
        
        
        function delTrackByID_selectedIDs_deletesCorrectTracks(TestObj)
            %When track is deleted, the trackID should be removed
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            delIDs = [1 2 5 7 8 10];
            
            TA = TA.delTrackByID(delIDs);
            
            TestObj.assertEqual(TA.numTracks, 4)
            TestObj.assertEqual([TA.tracks.trackID], uint32([3 4 6 9]))
        end
        
        function delTrack_selectedIndices_deletesCorrectTracks(TestObj)
            %Deleting track by index rather than trackID
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            delIndices = [1 2];
            
            TA = TA.delTrack(delIndices);
            
            TestObj.assertEqual(TA.numTracks, 8)
            TestObj.assertEqual([TA.tracks.trackID], uint32(3:10))
            
            TA = TA.delTrack(delIndices);
            
            TestObj.assertEqual(TA.numTracks, 6)
            TestObj.assertEqual([TA.tracks.trackID], uint32(5:10))
            
        end
        
        function delTrack_logicalTrackIndex_deleteTrack(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            del = logical([1 0 1 1 0 0 1 1 0 1]);
            
            TA = TA.delTrack(del);
            
            TestObj.assertEqual(TA.numTracks, nnz(~del))
            TestObj.assertEqual([TA.tracks.trackID], uint32(find(~del)))
            
        end
        
        function delTrackByID_deleteLastTrack_tracksPropertyIsEmpty(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TA = delTrackByID(TA, 1:10);
            
            TestObj.assertEqual(TA.numTracks, 0);
            TestObj.assertTrue(isempty(TA.tracks));
            
        end
        
        
        function delTrackByID_ArrayOfArrays_deletesAllMatchingTracks(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData1 = generateTracks(TDG, 10);
            testData2 = generateTracks(TDG, 10);
            
            TA1 = timedata.trackarray(testData1);
            TA2 = timedata.trackarray(testData2);
            
            TA = [TA1; TA2];
            
            TA = delTrackByID(TA, [1 2 5 7 8 10]);
            
            TestObj.assertEqual([TA(1).tracks.trackID], uint32([3 4 6 9]))
            TestObj.assertEqual([TA(2).tracks.trackID], uint32([3 4 6 9]))
        end
        
        
        function delFrame_deletesSpecifiedFrames_FromAllTracks(TestObj)
            %Generate test data
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TA = delFrame(TA, 6:10);
            for iTrack = 1:TA.numTracks
                TestObj.assertEqual(TA.tracks(iTrack).data, testData(iTrack).data(1:5));                
            end
            
        end
        
        function delFrame_deletesSpecifiedFrames_FromSpecifiedTracks(TestObj)
            %Generate test data
            TDG = trackDataGenerator;
            TDG.firstFrame = 1;
            TDG.numFrames = 10;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            TA = delFrame(TA, 6:10, 6:10);
            for iTrack = 1:5
                TestObj.assertEqual(TA.tracks(iTrack).data, testData(iTrack).data);
            end
            
            for iTrack = 6:10
                TestObj.assertEqual(TA.tracks(iTrack).data, testData(iTrack).data(1:5));
            end
            
        end
        
        
        function concatenate_joinsTrackarraysIntoObjectArray(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            %Join these together
            vertcatTA = [TA; TA];
            
            TestObj.assertEqual(size(vertcatTA), [2, 1]);
            
            horzcatTA = [TA TA];
            
            TestObj.assertEqual(size(horzcatTA), [1, 2])
        end
        
        
        function setMetadata_metadataValuesSetCorrectly(TestObj)
            
            TA = timedata.trackarray;
            TA = setMetadata(TA, 'filename', 'New Filename', ...
                'pixelsize', 0.53,...
                'welllocation', 'A12');
            
            TestObj.assertMatches(TA.metadata.filename, 'New Filename');
            TestObj.assertEqual(TA.metadata.pixelsize, 0.53);
            TestObj.assertMatches(TA.metadata.userdata.welllocation, 'A12');
            
        end
        
        function getMetadata_metadataValuesCorrect_CaseInsensitive(TestObj)
            
            TA = timedata.trackarray;
            TA = setMetadata(TA, 'filename', 'New Filename', ...
                'pixelsize', 0.53,...
                'welllocation', 'A12');
            
            TestObj.assertMatches(getMetadata(TA, 'FILENAME'), 'New Filename');
            TestObj.assertEqual(getMetadata(TA, 'pixelsize'), 0.53);
            TestObj.assertMatches(getMetadata(TA, 'welllocation'), 'A12');
            
        end
        
        
        function overwriteTrack(TestObj)
            
        end
        
        
        
        function import_importFromCSV(TestObj)
            
            
        end
        
        function import_importFromJSON(TestObj)
            
            
        end
        
        function import_importFromXML(TestObj)
            
            
        end
        
        
    end
    
end