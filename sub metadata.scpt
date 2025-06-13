JsOsaDAS1.001.00bplist00�Vscript_�(() => {

	var app = Application.currentApplication();
	app.includeStandardAdditions = true;

	function file_exists(strPath) {
		var error = $();
  	return $.NSFileManager.defaultManager
  		.attributesOfItemAtPathError($(strPath)
    	.stringByStandardizingPath, error), error.code === undefined;
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
		die("Qinsy time offset must be in hh:mm:ss format (e.g., \"02:00:00\")");
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
		die("Video time offset must be in hh:mm:ss format (e.g., \"02:00:00\")");
	}

	
	var output = vids + "/video_metadata.csv";
	var video_glob = `'${vids}'/*.MOV`;
	var exiftool = config.exiftool;
	var rscript = config.rscript;
	var cmd_dir = "~/Documents/clipdata/";
	var cmd = `'${rscript}' clipdata.R`;
	cmd += ` --output '${output}' --qinsy-offset '${qinsy_offset}' --video-offset '${video_offset}'`;
	cmd += ` --save-profile --exiftool '${exiftool}' '${qinsy}' ${video_glob}`;
	
	Progress.totalUnitCount = 50;
  Progress.completedUnitCount = 25;
  Progress.description = 'Processing video metadata...';

	
	app.doShellScript(`cd ${cmd_dir} && ${cmd}`);
	
	Progress.completedUnitCount = 50;
	
	var msg = `Metadata and dive profiles saved to ${vids.toString()}`;
	//app.displayAlert("Finished",{message: msg, as: "informational"});
	
	app.doShellScript(`open '${vids}'`);
})();                              � jscr  ��ޭ