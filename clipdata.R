#!/usr/local/env Rscript

# if you're running this in Rstudio and it's the first time, uncomment and run the next line:
# renv::restore()

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(fs))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(janitor))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(optparse))

# make an error function that doesn't show code
bail <- function(...) stop(...,call. = FALSE)

# quieten things down a bit
options(
  readr.show_col_types = FALSE,
  dplyr.summarise.inform = FALSE
)

# convert weird lat/long format to decimal degrees
ddeg <- function(str) {
  # 175;42.3345358E
  # 11;38.4471749S
  dm <- parse_number(str_split_1(str,";"))
  dir <- last(str_split_1(str,"[0-9]+"))
  mult <- switch(str_to_lower(dir),e = 1, w = -1, n = 1, s = -1)
  deg <- (dm[1] + dm[2] / 60) * mult
  return(deg)
}

# format a time period object as hh:mm:ss, for an arbitrary number of hours
fmt_period <- function(pd) {
  h <- pd %/% hours(1) 
  m <- pd %/% minutes(1) %% 60
  s <- pd %/% seconds(1) %% 60
  str_glue('{h}:{m}:{s}')
}

# help message formatter
nice_formatter <- function(object) {
    cat(object@usage, fill = TRUE)
    cat(object@description, fill = TRUE)
    cat("Options:", sep = "\n")

    options_list <- object@options
    for (ii in seq_along(options_list)) {
        option <- options_list[[ii]]
        cat("  ")
        if (!is.na(option@short_flag)) {
            cat(option@short_flag)
            if (optparse:::option_needs_argument(option)) {
                cat(" ", toupper(option@metavar), sep = "")
            }
            cat(", ")
        }
        if (!is.null(option@long_flag)) {
            cat(option@long_flag)
            if (optparse:::option_needs_argument(option)) {
                cat("=", toupper(option@metavar), sep = "")
            }
        }
        cat("\n    ")
        cat(sub("%default", optparse:::as_string(option@default), option@help))
        cat("\n\n")
    }
    cat(object@epilogue, fill = TRUE)
    return(invisible(NULL))
}

# make command line option list
option_list <- list(
  make_option(c("-q", "--qinsy-offset"), action="store", default="00:00:00", type='character', help="Offset ([+/-]hh:mm:ss) to modify dive time [default: %default]"),
  make_option(c("-v", "--video-offset"), action="store", default="00:00:00", type='character', help="Offset ([+/-]hh:mm:ss) to modify video time [default: %default]"),
  make_option(c("-g", "--video-glob"), action="store", default="*.mov", type='character', help="Glob (wildcard) to specify video files (must be quoted if passing in the shell)"),
  make_option(c("-t", "--timezone"), action="store", default="", type='character', help="Timezone of video/qinsy times (in Olson/tz format), blank is computer's local timezone"),
  make_option(c("-x", "--exiftool"), action="store", default="exiftool", type='character', help="Path to exiftool executable [default: %default]"),
  make_option(c("-r", "--rename"), action="store_true", default=FALSE, type='logical', help="Rename video files [default: %default]"),
  make_option(c("-p", "--save-profile"), action="store_true", default=FALSE, type='logical', help="Save dive profile data for each video file [default: %default]"),
  make_option(c("-F", "--rename-format"), action="store", default="%f_%d", type='character', help="Video file renaming format string [default: %default]"),
  make_option(c("-o", "--output"), action="store", default="video_metadata.csv", type='character', help="Output filename [default: %default]")
)

# if you're running this from within Rstudio, uncomment the following lines
# and fill in the option values with whatever values you want to use:
#   script_args <- c(
#   # this is the offset for times in the qinsy file
#   '--qinsy-offset','00:00:00',
#   # this is the offset for the video creation time
#   '--video-offset','00:00:00',
#   # this is the path to the exiftool executable
#   '--exiftool', '/opt/homebrew/bin/exiftool',
#   # this is the timezone where the sub dives took place
#   # (leave blank for the local timezone of this computer)
#   '--timezone','',
#   # uncomment the following lines if you want to rename video files
#   ## this will rename video files
#   # '--rename',
#   ## this sets the video file renaming format (by default it's <original filename>_depth.mov)
#   # '--rename-format','%f_%d',
#   # save individual dive profiles
#   '--save-profile',
#   # main metadata filename (will go in the directory shared by video files)
#   '--output','video_metadata.csv',
#   # glob to specify which video files are checked
#   '--video-glob','*.mov',
#   # qinsy file
#   '/Volumes/SSD-TUVsub2/TUV-2025-sub/TUV-2025-sub-006/Qinsy/Dive number 137 - 13May25.txt',
#   # directory containing video files (*.mov assumed)
#   '/Volumes/SSD-TUVsub2/TUV-2025-sub/TUV-2025-sub-006/Videos'
# )

# use the above arguments if we have 'em
if (exists('script_args')) {
    opt_args <- script_args
} else {
    opt_args <- commandArgs(TRUE)
}

# parse command-line options
opt <- parse_args2(
    OptionParser(
        option_list=option_list,
        formatter=nice_formatter,
        prog="clipdata.R",
        usage="%prog [options] <qinsy_file> <video_dir>"
    ),
    args = opt_args
)

# get video/qinsy time offsets
qinsy_offset = hms(opt$options$qinsy_offset)
video_offset = hms(opt$options$video_offset)

# bail if offsets didn't parse properly
if (is.na(qinsy_offset)) {
  bail("--qinsy-offset must be in (+/-)hh:mm:ss format")
}
if (is.na(video_offset)) {
  bail("--video-offset must be in (+/-)hh:mm:ss format")
}

# read qinsy file
# ignore headers because sometimes they have to shut off recording
# and start it again and you get another header showing up in the file
# partway through
suppressMessages(
  qinsy <- read_csv(
    opt$args[1],
    col_select = c(dive=1,date=2,time=3,lat=10,lon=11,temp=12,depth=15),
    col_types = "nccccnn",
    comment='Job Number',
    col_names=FALSE
  ) %>%
  mutate(
    timestamp = as.POSIXct(paste(date,time),format="%m/%d/%Y %H:%M:%S", tz=opt$options$timezone) + qinsy_offset
  )
)

# figure out video files and directory
video_files <- opt$args[-1]
if (length(video_files) == 1 & is_dir(video_files)) {
  video_dir <- video_files
  video_files <- dir_ls(video_files,glob=opt$options$video_glob,ignore.case=TRUE)
} else {
  video_dir <- unique(path_dir(video_files))
  if (length(video_dir) > 1) { 
    bail("Video files must all be in the same directory.")
  }
}

# setup command line arguments for exiftool
xt_cmd <- c(
  opt$options$exiftool,
  "-TrackCreateDate",
  "-TrackDuration",
  "-csv",
  str_glue('"{video_files}"')
)

# run exiftool and capture its output
exif_table <- system(str_c(xt_cmd,collapse=" "),intern=TRUE,ignore.stderr = TRUE)

# read exiftool csv output into table
video_data <- read_csv(
  I(exif_table),
  col_select = c(file=1,start_time=2,duration=3)
) %>%
  mutate(
    # first try to parse duration as hh:mm:ss
    # then parse it as a time period, e.g., something like "16S"
    la = suppressWarnings(hms(duration)),
    lb = suppressWarnings(as.period(duration)),
    # smash them together
    duration = coalesce(la,lb)
  ) %>%
  select(-c(la,lb)) %>%
  mutate(
    path = file, # get the whole path
    file = path_file(path), # get just the filename
    start = as.POSIXct(start_time,format="%Y:%m:%d %H:%M:%S", tz=opt$options$timezone) + video_offset, # convert to a datetime object
    end = start+duration # get the end time
  )

# join the video clips to the qinsy data by start and end times
clipdata <- qinsy %>%
  inner_join(video_data %>% select(file,path,start,end), by = join_by(x$timestamp >= y$start , x$timestamp <= y$end))

# if none of them joined, we have a problem
if (all(is.na(clipdata$file))) {
  msg <- c(
    "No video files had creation times within the range of the supplied qinsy file.",
    "Times can be adjusted with the --qinsy-offset and/or --video-offset options."
  )
  bail(str_c(msg,collapse="\n"))
}

# summarize the clip data by file
clip_summary <- clipdata %>%
  group_by(file,path) %>%
  summarise(
    dive = unique(dive),
    start = first(timestamp),
    end = last(timestamp),
    duration = as.period(end-start),
    avg_temp = round(mean(temp),1),
    start_depth = first(depth),
    end_depth = last(depth),
    avg_depth = round(mean(depth),2),
    start_lat = round(ddeg(first(lat)),5),
    start_lon = round(ddeg(first(lon)),5),
    end_lat = round(ddeg(last(lat)),5),
    end_lon = round(ddeg(last(lon)),5)
  ) %>%
  ungroup() %>%
  mutate(duration = fmt_period(duration)) %>% 
  select(dive,file,ends_with("depth"),start_lat,start_lon,end_lat,end_lon,avg_temp,start,end,duration)

output_file <- opt$options$output
# if no directory is specified, put it alongside the videos
if (path_file(output_file) == output_file) {
  output_file <- path(video_dir,output_file)
}

# decide how to save the file
writer <- switch(
  path_ext(output_file),
  csv = write_csv,
  tsv = write_tsv,
  \(a,b) bail(str_glue("Unable to determine the file format of `{b}`."))
)


writer(clip_summary,output_file)
cat(str_glue("Saved video metadata to {output_file}\n"))

if (opt$options$rename) {
  dirs <- path_dir(clip_summary$path)
  files <- clip_summary$file
  basenames <- path_ext_remove(files)
  extensions <- path_ext(files)
  depths <- round(clip_summary$avg_depth)
  temps <- clip_summary$avg_temp
  fmt <- rep(opt$options$rename_format,length(files))
  fmt <- str_replace_all(fmt,fixed("%f"),basenames)
  fmt <- str_replace_all(fmt,fixed("%d"),depths)
  fmt <- str_replace_all(fmt,fixed("%t"),temps)
  fmt <- path_ext_set(fmt,extensions)
}

if (opt$options$save_profile) {
  clipdata %>%
    group_by(path) %>%
    group_walk(\(data,grp) {
      f <- path_ext_set(grp$path,"profile.csv")
      data %>%
        mutate(file = path_file(grp$path),lat = round(map_dbl(lat,ddeg),5), lon = round(map_dbl(lon,ddeg),5)) %>%
        select(file,dive,time=timestamp,depth,temp,lat,lon) %>%
        write_csv(f)
    })
}
