# Linear Assignment Tracking

The Linear Assignment Tracking toolbox implements MATLAB classes to track moving cells in microscope images and analyze resulting data.

## Downloading and using the toolbox

The latest releases can be found [here](https://github.com/Biofrontiers-ALMC/cell-tracking-toolbox/releases).

Full instructions on how to download, install, and use the toolbox is on the [Project Wiki](https://github.com/Biofrontiers-ALMC/cell-tracking-toolbox/wiki).

## Downloading the source code

**:warning: You do not need the source code unless you are planning to contribute to this project.**

The ``master`` branch contains the latest stable code, while the ``dev`` branch contains daily builds. You should only use the dev branch if you know what you are doing.

### Using the Gitlab interface

To download the source code using Gitlab:

1. Click on the **Repository** tab above.
2. Click on the **Download icon** and select the desired format. It is recommended that you download the "master" branch as it contains the latest stable code.

### Cloning using Git

*If this is your first time using the biof-git repository, you must [add an SSH key to your profile](#adding-an-ssh-key).*

To clone the repository using [Git](https://git-scm.com/):

1. Click on the **Project** tab above.
2. Look for the SSH box (you might need to maximize your browser window if the box is missing). Copy the SSH URL to the clipboard. The URL should look like: ``git@biof-git.colorado.edu:<groupname>/<projectname>.git``
3. **Windows:** Start the Git bash application and navigate to a folder of your choice.
   **Linux/Mac:** Start the Terminal application and navigate to a folder of your choice.
4. Enter the following command:

```
  git clone <SSH URL>
```

If you have any issues, please email the developer or bit-help@colorado.edu for help.

## Developer's Guide

### Directory structure

The directory of the Git repository is arranged according to the best practices described in [this MathWorks blog post](https://blogs.mathworks.com/developer/2017/01/13/matlab-toolbox-best-practices/). The following table describes the folders in this repository:

|  Folder name        |  Description                                                                          |
|---------------------|---------------------------------------------------------------------------------------|
| ``tbx\lap-tracker`` |  Main toolbox code                                                                    |
| ``tbx\docs``        |  Examples and MATLAB user documentation                                               |
| ``build``           |  Files for building the toolbox (typically a MATLAB project (.prj) file and an icon)  |
| ``tests``           |  Unit tests                                                                           |
### Contributing to the code

#### Reporting bugs and issues

Please report bugs and issues using the [Issues Tracker](https://github.com/Biofrontiers-ALMC/cell-tracking-toolbox/issues).

#### Merge/Pull requests

To contribute code directly, please submit a [Pull Request](https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request).

Note: In general, your code will have to pass the unit tests listed in the `tests` folder. You can check that they do by using the [`runtests` function in MATLAB](https://www.mathworks.com/help/matlab/ref/runtests.html).

References
----------

K. Jaqaman, et al. "Robust single particle tracking in live cell time-lapse sequences" Nature Methods 5, 695-702 (2008)

