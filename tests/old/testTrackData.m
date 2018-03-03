classdef testTrackData < matlab.unittest.TestCase
   
    methods (TestClassSetup)
        
        function addTbx(obj)
            %ADDTBX  Add the 'tbx' folder and sub-folders to the path
            
            currPath = path;
            obj.addTeardown(@path,currPath);
            addpath(genpath('../tbx/'));
        end
        
    end
    
    methods (Test)
        
        function verifyErrors_addFrame(TestCase)
            %VERIFYERRORS_ADDFRAME  Tests for input validation for addFrame
            
            sampleData = struct('Area', 5);
            
            trackObj = TrackData(5, sampleData);
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            
            TestCase.verifyError(@() trackObj.addFrame('s', sampleData),...
                'TrackData:addFrame:frameIndexNotNumeric');
            
            TestCase.verifyError(@() trackObj.addFrame([6 7], sampleData),...
                'TrackData:addFrame:frameIndexNotScalar');
            
            TestCase.verifyError(@() trackObj.addFrame(5, sampleData),...
                'TrackData:addFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.addFrame(6, {'Area', 20}),...
                'TrackData:addFrame:dataNotStruct');
            
        end
        
        function verify_addFrame_addToEnd(TestCase)
            %VERIFY_ADDFRAME_ADDTOEND  Verify addFrame works correctly when
            %adding to the end
            
            %Insert 2 consecutive frames
            trackObj = TrackData(3, struct('Area',5'));
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,2);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[5, 10]);
            TestCase.verifyEqual([trackObj.FrameIndex],[3, 4]);
        end
        
        function verify_addFrame_addToEndWithSkip(TestCase)
            %VERIFY_ADDFRAME_ADDTOENDWITHSKIP Verify addFrame works
            %correctly when adding to the end with a skip
            
            %Insert 2 consecutive frames
            trackObj = TrackData(3, struct('Area',5'));
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            %Skip frame 5
            trackObj = trackObj.addFrame(6, struct('Area',30'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,4);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[5, 10, 30]);
            TestCase.verifyEqual([trackObj.FrameIndex],[3, 4, 5, 6]);
        end
        
        function verify_addFrame_addToStart(TestCase)
            %VERIFY_ADDFRAME_ADDTOSTART  Verify addFrame works correctly
            %when adding to the start
            
            %Insert 3 consecutive frames
            trackObj = TrackData(5, struct('Area',5'));
            trackObj = trackObj.addFrame(6, struct('Area',30'));
            trackObj = trackObj.addFrame(7, struct('Area',40'));
            
            %Insert a frame at the start
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,4);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 5, 30, 40]);
            TestCase.verifyEqual([trackObj.FrameIndex],[4, 5, 6, 7]);
            
        end
        
        function verifyErrors_deleteFrame(TestCase)
            %VERIFYERRORS_ADDFRAME  Tests for input validation for addFrame
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
           
            TestCase.verifyError(@() trackObj.deleteFrame('s'),...
                'TrackData:deleteFrame:frameIndexCharInvalid');
            
            TestCase.verifyError(@() trackObj.deleteFrame([5, 8, 9]),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.deleteFrame(1),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.deleteFrame(9),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
        end
        
        function verifyErrors_deleteFrame_logical(TestCase)
            %Test case when frame index is a logical array but of the wrong
            %size
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            TestCase.assertEqual(trackObj.LastFrame, 8);
            TestCase.assertEqual(trackObj.NumFrames, 4);
            
            %Delete first frame and check that the start frame index is
            %reduced
            TestCase.verifyError(@() trackObj.deleteFrame(true),...
                'TrackData:deleteFrame:frameIndexInvalidSize');
            
            TestCase.verifyError(@() trackObj.deleteFrame(true(4,2)),...
                'TrackData:deleteFrame:frameIndexInvalidSize');
            
        end
        
        function verify_deleteFrame_singleFrames(TestCase)
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            trackObj = trackObj.addFrame(9, struct('Area', 80));
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            TestCase.assertEqual(trackObj.LastFrame, 9);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame(5);
            
            TestCase.verifyEqual(trackObj.NumFrames,4)
            TestCase.verifyEqual(trackObj.FirstFrame,6)
            
            %Delete last frame and check that the end frame index is
            %reduced
            trackObj = trackObj.deleteFrame(9);
            
            TestCase.verifyEqual(trackObj.NumFrames,3)
            TestCase.verifyEqual(trackObj.LastFrame,8)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 20, 40]);
            
            %Delete frame 7 (in the middle). The expected result is that
            %frame 7 is removed and the frame numbers are renumbered.
            trackObj = trackObj.deleteFrame(7);
            
            TestCase.verifyEqual(trackObj.NumFrames,2)
            TestCase.verifyEqual(trackObj.LastFrame,7)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 40]);
            
        end
        
        function verify_deleteFrame_end(TestCase)
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            trackObj = trackObj.addFrame(9, struct('Area', 80));
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            TestCase.assertEqual(trackObj.LastFrame, 9);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame('end');
            
            TestCase.verifyEqual(trackObj.NumFrames,4)
            TestCase.verifyEqual(trackObj.LastFrame,8)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[5, 10, 20, 40]);
            
        end
        
        function verify_deleteFrame_multiFrames(TestCase)
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            trackObj = trackObj.addFrame(9, struct('Area', 40));
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            TestCase.assertEqual(trackObj.LastFrame, 9);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame([5, 6, 8]);
            
            TestCase.verifyEqual(trackObj.NumFrames,2)
            TestCase.verifyEqual(trackObj.FirstFrame,7)
            TestCase.verifyEqual(trackObj.LastFrame,8)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[20, 40]);
            
            %Test note: Deleting two consecutive frames should change the
            %start frame index correctly.
        end
        
        function verify_deleteFrame_logical(TestCase)
            %Test case when frame index is a logical array
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            trackObj = trackObj.addFrame(9, struct('Area', 80));
            
            TestCase.assertEqual(trackObj.FirstFrame, 5);
            TestCase.assertEqual(trackObj.LastFrame, 9);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame(logical([1, 0, 0, 1, 1]));
            
            TestCase.verifyEqual(trackObj.NumFrames,2)
            TestCase.verifyEqual(trackObj.FirstFrame,6)
            TestCase.verifyEqual(trackObj.LastFrame,7)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 20]);
        end
        
        function renameField(TestCase)
           
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            trackObj = trackObj.addFrame(9, struct('Area', 80));
            
            TestCase.verifyTrue(ismember(trackObj.TrackDataProps,'Area'))
            
            trackObj = trackObj.renameField('Area','NewField');
            
            TestCase.verifyTrue(ismember(trackObj.TrackDataProps,'NewField'))
            TestCase.verifyTrue(~ismember(trackObj.TrackDataProps,'Area'))
            TestCase.verifyEqual(trackObj.Data(5).NewField, 80)
                  
        end
       
    end
    
end