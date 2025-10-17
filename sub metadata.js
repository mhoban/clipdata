(() => {

  var app = Application.currentApplication();
  app.includeStandardAdditions = true;

  function file_exists(strPath) {
    var error = $();
    return $.NSFileManager.defaultManager
      .attributesOfItemAtPathError($(strPath)
      .stringByStandardizingPath, error), error.code === undefined;
  }

function write_file(text, file) {
  // source: https://stackoverflow.com/a/44293869/11616368
  var nsStr       = $.NSString.alloc.initWithUTF8String(text)
  var nsPath      = $(file).stringByStandardizingPath
  var successBool  = nsStr.writeToFileAtomicallyEncodingError(nsPath, false, $.NSUTF8StringEncoding, null)
  if (!successBool) {
    throw new Error("function writeFile ERROR:\nWrite to File FAILED for:\n" + file)
  }
  return successBool
}

  function read_file(strPath) {
    var error = $();
    str = ObjC.unwrap(
      $.NSString.stringWithContentsOfFileEncodingError($(strPath)
      .stringByStandardizingPath, $.NSUTF8StringEncoding, error)
    ),
      blnValid = typeof error.code !== 'string';
    return {
      nothing: !blnValid,
      text: blnValid ? str : undefined,
      error: blnValid ? '' : error.code
    };
  }

  function read_json(file) {
    var f = read_file(file);
    if (!f.nothing) {
      return JSON.parse(f.text);
    } else {
      return undefined;
    }
  }

  function die(msg) {
    app.displayAlert("Error",{ message: msg, as: "critical" });
    const e = new Error("User canceled.");
    e.errorNumber = -128;
    throw e;
  }

  if (!file_exists("~/Documents/clipdata/clipdata.R")) {
    die("Unable to find clipdata script.\nMake sure the clipdata R script is installed in ~/Documents/clipdata");
  }

  var config = read_json("~/Documents/clipdata/clipdata.json");
  if (!config) {
    die("Unable to read clipdata config file.\nMake sure to populate ~/Documents/clipdata/clipdata.json.");
  }

  if (!config.configured) {
    config.configured = true;
    var rsc = config.rscript;
    try {
      app.doShellScript('which Rscript');
    } catch(e) {}

    config.rscript = app.displayDialog(
      'Verify path to Rscript executable', {
        defaultAnswer: rsc != "" ? rsc : config.rscript,
        hiddenAnswer: false,
        buttons: ["Ok"],
        defaultButton: "Ok",
        withTitle: 'Rscript executable path',
      }
    ).textReturned;
    if (!file_exists(config.rscript)) {
      die(`The file ${config.rscript} does not exist.`)
    }

    var ext = config.exiftool;
    try {
      app.doShellScript('which exiftool');
    } catch(e) {}
    config.exiftool = app.displayDialog(
      'Verify path to exiftool executable', {
        defaultAnswer: ext != "" ? ext : config.exiftool,
        hiddenAnswer: false,
        buttons: ["Ok"],
        defaultButton: "Ok",
        withTitle: 'exiftool executable path',
      }
    ).textReturned;
    if (!file_exists(config.exiftool)) {
      die(`The file ${config.exiftool} does not exist.`)
    }

    config.timezone = app.displayDialog(
      "Enter the timezone where sub dives took place\n(Ex: Pacific/Funafuti. Leave blank for current local timezone)", {
        defaultAnswer: config.timezone,
        hiddenAnswer: false,
        buttons: ["Ok"],
        defaultButton: "Ok",
        withTitle: 'Local timezone',
      }
    ).textReturned;
    var json = JSON.stringify(config,null,"  ");
    write_file(json,"~/Documents/clipdata/clipdata.json");
  }

  var qinsy = app.chooseFile({
    withPrompt: "Select your qinsy file",
    multipleSelectionsAllowed: false
  });

  var vids = app.chooseFolder({
    withPrompt: "Select the folder containing your video files"
  });

  var qinsy_offset = app.displayDialog(
    'Enter a time offset for the qinsy file times in [+/-]hh:mm:ss format', {
      defaultAnswer: '00:00:00',
      hiddenAnswer: false,
      buttons: ["Ok","Cancel"],
      defaultButton: "Ok",
      cancelButton: 2,
      withTitle: "Qinsy file time offset",
    }
  ).textReturned;

  if (!/[+-]?[0-9]+:[0-9]+:[0-9]+/.test(qinsy_offset)) {
    die("Qinsy time offset must be in [+/-]hh:mm:ss format (e.g., \"02:00:00\")");
  }

  var video_offset = app.displayDialog(
    'Enter a time offset for the video file times in [+/-]hh:mm:ss format', {
      defaultAnswer: '00:00:00',
      hiddenAnswer: false,
      buttons: ["Ok","Cancel"],
      defaultButton: "Ok",
      cancelButton: 2,
      withTitle: "Video file time offset",
    }
  ).textReturned;

  if (!/[+-]?[0-9]+:[0-9]+:[0-9]+/.test(video_offset)) {
    die("Video time offset must be in [+/-]hh:mm:ss format (e.g., \"02:00:00\")");
  }

  var output = "video_metadata.csv";
  // var video_glob = `'${vids}'/*.MOV`;
  var timezone = config.timezone;
  var exiftool = config.exiftool;
  var rscript = config.rscript;
  var cmd_dir = "~/Documents/clipdata/";
  var cmd = `'${rscript}' clipdata.R`;
  cmd += ` --output '${output}' --qinsy-offset '${qinsy_offset}' --video-offset '${video_offset}'`;
  cmd += ` --timezone '${timezone}' --save-profile --exiftool '${exiftool}' '${qinsy}' ${vids}`;
  // cmd += ` --save-profile --exiftool '${exiftool}' '${qinsy}' ${video_glob}`;

  Progress.totalUnitCount = 50;
  Progress.completedUnitCount = 25;
  Progress.description = 'Processing video metadata...';


  app.doShellScript(`cd ${cmd_dir} && ${cmd}`);

  Progress.completedUnitCount = 50;

  var msg = `Metadata and dive profiles saved to ${vids.toString()}`;
  //app.displayAlert("Finished",{message: msg, as: "informational"});

  app.doShellScript(`open '${vids}'`);
})();
