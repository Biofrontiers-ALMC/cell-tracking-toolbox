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
        
        
        function addTrack_addNewTracks_trackIDandDataValid(TestObj)
            
            TA = timedata.trackarray;
            
            TA = TA.addTrack;
            TestObj.assertEqual(TA.numTracks, 1);
            
            TA = TA.addTrack;
            TestObj.assertEqual(TA.numTracks, 2);

            TestObj.assertEqual([TA.tracks.trackID], uint32(1:2));
        end
        
        function delTrackByID_deleteTrack(TestObj)
            %When track is deleted, the trackID should be removed
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            del = [1 2 5 7 8 10];
            
            TA = TA.delTrack(del);
            
            TestObj.assertEqual(TA.numTracks, 4)
            TestObj.assertEqual([TA.tracks.trackID], uint32([3 4 6 9]))
        end
        
        function delTrack_trackIndex(TestObj)
            
            
        end
        
        function delTrack_logicalTrackIndex_deleteTrack(TestObj)
            
            %Generate test data
            TDG = trackDataGenerator;
            testData = generateTracks(TDG, 10);
            
            TA = timedata.trackarray(testData);
            
            del = logical([1 0 1 1 0 0 1 1 0 1]);
            
            TA = TA.delTrack(del);
            
            TestObj.assertEqual(TA.numTracks, nnz(del))
            TestObj.assertEqual([TA.tracks.trackID], uint32(find(del)))
            
        end
        
        function addTrack_addAfterDeletion_trackIDisIncreased(TestObj)
            %Initial track IDs are 1, 2, 3, 4, 5
            % Delete track ~= 5, new track ID should be 6
            % Delete track 5, new track ID should be 5
            
            
        end
        
        
    end
    
end