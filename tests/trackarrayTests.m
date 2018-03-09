classdef trackarrayTests < matlab.unittest.TestCase

    methods (Test)
        
        function construct_initializeEmptyArray_correctNumTracksCreated(TestObj)
            
            TA = timedata.trackarray(10);
            TestObj.assertEqual(TA.numTracks, 10);
            
            TestObj.assertEqual([TA.tracks.trackID], uint32(1:10));
            
        end
        
        function addTrack_addNewTracks_trackIDandDataValid(TestObj)
            
            TA = timedata.trackarray;
            
            TA = TA.addTrack;
            TestObj.assertEqual(TA.numTracks, 1);
            
            TA = TA.addTrack;
            TestObj.assertEqual(TA.numTracks, 2);

            TestObj.assertEqual([TA.tracks.trackID], uint32(1:2));
        end
        
    end
    
end