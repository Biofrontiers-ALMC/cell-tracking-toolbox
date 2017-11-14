classdef test_TrackDataArray < matlab.unittest.TestCase
   
    methods (TestClassSetup)
        
        function addTbx(obj)
            %ADDTBX  Add the 'tbx' folder and sub-folders to the path
            
            currPath = path;
            obj.addTeardown(@path,currPath);
            addpath(genpath('../tbx/'));
        end
        
    end
    
    methods (Test)
        
        function verify_addTrack(TestCase)
            %VERIFY_ADDTRACK  Check that AddTrack works
            
            trackArrayObj = TrackDataArray;
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',5));
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',10));
            
            TestCase.verifyEqual(numel(trackArrayObj),2)
            TestCase.verifyEqual(trackArrayObj.getTrack(1).Data(1).Area,5);
            TestCase.verifyEqual(trackArrayObj.getTrack(2).Data(1).Area,10);
                    
        end
        
        function verify_deleteTrack(TestCase)
            %VERIFY_DELETETRACK  Check that DeleteTrack works
            
            %Initialize the array and create three tracks
            trackArrayObj = TrackDataArray;
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',5));
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',10));
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',20));
            
            TestCase.assertEqual(numel(trackArrayObj),3)
            
            %Delete track 2
            trackArrayObj = trackArrayObj.deleteTrack(2);
            
            TestCase.verifyEqual(numel(trackArrayObj),2);
            TestCase.verifyEqual(trackArrayObj.getTrack(2).Data(1).Area,20);
                    
        end
               
        function verify_updateTrack(TestCase)
            %Check that the update track method works
            
            %Initialize an track array by adding two tracks
            trackArrayObj = TrackDataArray;
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',5));
            trackArrayObj = trackArrayObj.addTrack(1, struct('Area',3));
            
            %Update the tracks by adding additional frames
            trackArrayObj = trackArrayObj.updateTrack(1, 2, struct('Area',50));
            trackArrayObj = trackArrayObj.updateTrack(2, 2, struct('Area',30));
            
            TestCase.verifyEqual(numel(trackArrayObj),2)
            TestCase.verifyEqual([trackArrayObj.getTrack(1).Data.Area],[5, 50]);
            TestCase.verifyEqual([trackArrayObj.getTrack(2).Data.Area],[3, 30]);
            
        end
        
        
    end
    
end