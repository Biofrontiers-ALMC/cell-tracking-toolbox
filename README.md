# Linear Assignment Tracking

The aim of this project is to develop code that can perform object tracking using the Linear Assignment framework, proposed by Jaqaman et al.

## Downloading and using the toolbox

Full instructions on how to download, install, and use the toolbox is on the [Project Wiki](https://biof-git.colorado.edu/core-code/lap-cell-tracker/wikis//home).

## Downloading the source code

The source code is available on the [biof-git repository](https://biof-git.colorado.edu/core-code/lap-cell-tracker). The ``master`` branch contains the latest stable code, while the ``development`` branch contains daily builds (note: these may not be working).

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

#### Adding an SSH key

You must have an account on Gitlab to be able to perform the following actions. Please email bit-help@colorado.edu for more information.

You can check if you have an SSH key by going to [your settings -> SSH Keys](https://biof-git.colorado.edu/profile/keys).

If you do not have an SSH key added, please generate a key following ([these instructions](https://biof-git.colorado.edu/help/ssh/README.md)).

## Developer's Guide

### Directory structure

The directory of the Git repository is arranged according to the best practices described in [this MathWorks blog post](https://blogs.mathworks.com/developer/2017/01/13/matlab-toolbox-best-practices/). The following table describes the folders in this repository:

|  Folder name        |  Description                                                                          |
|---------------------|---------------------------------------------------------------------------------------|
| ``tbx\lap-tracker`` |  Main toolbox code                                                                    |
| ``tbx\docs``        |  Examples and MATLAB user documentation                                               |
| ``build``           |  Files for building the toolbox (typically a MATLAB project (.prj) file and an icon)  |
| ``scripts``         |  Examples of scripts for running the code                                             |
| ``tests``           |  Unit tests                                                                           |
