# Pristine Seas submersible video clip metadata widget

This tool allows you to quickly extract and associate dive metadata (times, depths, GPS points, etc.) with video clips taken from the Argonauta's primary camera. It uses the Qinsy-formatted data file and video creation times to generate data sheets, allowing you to easily place video clips within the context of a given dive.

# Installation and setup

## Installing

As-written, this tool is current only supported on Mac, which is great when you're on the Argo since the main data management computer is a Mac. If you're not on the Argo and you have a Mac, you'll be fine. If you don't have a Mac (whether or not you're on the Argo), this tool currently won't work for you. I'm sorry.

### Dependencies

This tool requires two things to run: an [R](https://www.r-project.org/) installation, and [exiftool](https://exiftool.org/). Both tools can be installed via the links provided. To configure the sub metadata tool, you'll need to know the locations of the `Rscript` and `exiftool` executables (typically something like `/usr/local/bin/Rscript` and `/usr/local/bin/exiftool`, depending on how you installed them).

To install the tool, clone this repository to your machine, and make sure it's located in the `Documents` directory inside your home directory (`~/Documents/clipdata`). You can do this by opening a terminal window and running the following commands:

```console
$ cd ~/Documents
$ git clone https://github.com/mhoban/clipdata.git
```

If you've installed `R` and `exiftool`, you should be able to get their executable locations like this:

```console
$ which Rscript
/usr/local/bin/Rscript
$ which exiftool
/opt/homebrew/bin/exiftool
```

Make sure you note these locations.

### Initial configuration

There's one annoying thing you'll have to do right after installing this tool, but you'll only have to do it once. Pop open a terminal window and do the following (assuming you've already done the `git clone` operation above):

```console
$ cd ~/Documents/clipdata
$ R

R version 4.4.1 (2024-06-14) -- "Race for Your Life"
Copyright (C) 2024 The R Foundation for Statistical Computing
Platform: aarch64-apple-darwin20

R is free software and comes with ABSOLUTELY NO WARRANTY.
You are welcome to redistribute it under certain conditions.
Type 'license()' or 'licence()' for distribution details.

  Natural language support but running in an English locale

R is a collaborative project with many contributors.
Type 'contributors()' for more information and
'citation()' on how to cite R or R packages in publications.

Type 'demo()' for some demos, 'help()' for on-line help, or
'help.start()' for an HTML browser interface to help.
Type 'q()' to quit R.

- Project '~/Documents/clipdata' loaded. [renv 1.0.7]
>
```