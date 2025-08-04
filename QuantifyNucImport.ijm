//Macro to measure mean intensities of single cells and the nucleus

//first choose the channel and slice you want to analyze
//the threshold should cover the areas/ features you want to analyse e.g. cytosol or nucleus
//it generates cell masks which are measured, then it generates nucleus masks 
//it loops through each identified cell and performs a measurement if it meets the criteria
//otherwise a message is displayed in the row: No particle detected

//now you can start the macro

//dir = getDirectory("Choose a folder to save the tables");


dialog_channels = newArray("1", "2", "3", "4");
composite_channels = newArray("1000", "0100", "0010", "0001");

Dialog.create("Choose:");
Dialog.addMessage("Choose channels for the cell mask");
//Checkbox to generate cell string later
Dialog.addCheckboxGroup(1, 4, dialog_channels, newArray(false, false, true, true));
Dialog.addRadioButtonGroup("Channel for nucleus mask", dialog_channels, 1, 4, "2");
Dialog.addRadioButtonGroup("Channel for measuring:", dialog_channels, 1, 4, "1");
Dialog.show();
//use dialog.choice as key to retrieve the matching value from the list
cell_channel = "";
for (i = 0; i < dialog_channels.length; i++) {
	cell_channel = cell_channel+Dialog.getCheckbox();
};
nuc_channel = Dialog.getRadioButton();
measure_channel = Dialog.getRadioButton();

run("Set Measurements...", "area mean median limit display redirect=None decimal=2");

imagelist = getList("image.titles");
for (l = 0; l < imagelist.length; l++) {
    selectImage(imagelist[l]);
    onoma = getTitle();

    print("Image:", onoma);
// first we make the general cell mask
	var CellThr_value;

    cell_img = Generate_CellMask();
    print(CellThr_value);
	
	setThreshold(1, 255, "raw");
	run("Analyze Particles...", "size=9-27 circularity=0.50-1.00 show=Nothing display exclude clear include overlay add");
	roiManager("Show All without labels");
//now we make the Nucleus mask	
	var NucThr_value;
	nuc_mask = Generate_NucMask();
	print(NucThr_value);

//combine first measured image with nucleus mask
	selectImage(cell_img);
	imageCalculator("AND create", nuc_mask,cell_img);
	nuc_img = getTitle();
	close(nuc_mask);
	setThreshold(1, 255, "raw");
//loop through each ROI: measure the thresholded area inside of the previous determined cells 	 
	for (i = 0; i < roiManager("count"); i++) { 
		init_results = nResults; //stores the initial number or results
		roiManager("Select", i);
		run("Analyze Particles...", "size=1.1-7 circularity=0.10-1.00 show=Nothing display include overlay");
		if (nResults == init_results) { //compares number of results now with inital number, if the numbers match (i.e. no particles were measured) then the message is added
			setResult("Message", init_results, "No particle found");
			updateResults();
		};
	};
	setResult("Message", nResults, "CellThreshold: "+CellThr_value);	
	setResult("Message", nResults, "Nucleus Threshold: "+NucThr_value);
	updateResults();
	name = replace(onoma, "\\.\\w*$",".txt");
	selectWindow("Results");
	saveAs("results", dir+name);
	close(cell_img);
	close(nuc_img);
	close(onoma);
};

---------------------------------------------------------------------------------
//here are all functions defined:

function Generate_CellMask() {
//Generate binary mask and segment cells
	selectImage(onoma);
    Stack.setActiveChannels(cell_channel); //Choose active channel to create the mask (e.g. cytosol signal + DIA)
    resetMinAndMax;
    run("Enhance Contrast", "saturated=0.35");
	run("Stack to RGB", "keep");
	run("16-bit");	
    run("Gaussian Blur...", "sigma=1");
    run("Threshold...");
    setAutoThreshold("Moments dark");
    getThreshold(lower, upper);
    if (lower <= 140 || lower >=160) {
    	setAutoThreshold("Huang dark");
    	getThreshold(lower, upper);
    };
    waitForUser("Choose the threshold so it covers the cell area,\nClick 'set' and 'okay'.");
    getThreshold(lower, upper);
	CellThr_value = toString(lower)+"-"+toString(upper);
    setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Despeckle");
	run("Remove Outliers...", "radius=20 threshold=50 which=Bright");
//segment single cells
	run("Watershed");
	run("Fill Holes");
	cell_mask = getTitle();
//now combine cell mask with the channel you want to measure the intensity
	selectImage(onoma);
	Stack.setChannel(measure_channel);
//set the maximum brightness 
//since otherwise the pixel values will be changed forever and not comparible anymore
	setMinAndMax(0, 24000);
	imageCalculator("AND create", cell_mask,onoma);
	rename("cell mask: "+onoma);
	cell_img = getTitle();
	close(cell_mask);
	return cell_img;
}

function Generate_NucMask() {
//Generate binary mask and segment cells
	selectImage(onoma);
	Stack.setActiveChannels(composite_channels[nuc_channel-1]); //Nucleus channel
	run("Stack to RGB", "keep");
	run("16-bit");
    run("Gaussian Blur...", "sigma=2");
    setAutoThreshold("Moments dark");
    waitForUser;
	getThreshold(lower, upper);
	if (lower <= 30 || lower >= 60) {
		waitForUser("Adjust Nucleus treshold manually");
		getThreshold(lower, upper);
	};
	NucThr_value = toString(lower)+"-"+toString(upper);
    setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Gray Morphology", "radius=1 type=circle operator=erode");
	rename("Nucleus mask");
	nuc_mask = getTitle();
	return nuc_mask;
}
	
