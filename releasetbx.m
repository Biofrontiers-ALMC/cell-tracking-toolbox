function releasetbx(varargin)
%RELEASETBX  Runs release code for the toolbox
%
%  RELEASETBX will run the following operations to generate a released
%  version of the toolbox:
%    * Run all unit tests in the 'tests\' folder and check that they are
%      all passed
%    * Produce a test report as an HTML file

import matlab.unittest.TestRunner;
import matlab.unittest.TestSuite;
import matlab.unittest.plugins.TestReportPlugin;

%Generate a test suite from all the tests in folder 'tests\'
suite = testsuite('tests\');

%Generate a non-verbose test runner, with the HTML plugin
runner = TestRunner.withNoPlugins;
plugin = TestReportPlugin.producingHTML('tests\results','Verbosity',4);
runner.addPlugin(plugin);
result = runner.run(suite);

if ~all([result.Passed])
    error('There are failed unit tests. See <a href="tests\results\index.html">test report</a> for details.');
end

end