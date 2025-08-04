//Macro to generate a single cell mask and cytosolic puncta mask 
//(nuclear and NE puncta are excluded)
//mean pixel intensities are measured


//first choose the channel and slice you want to analyze
//the threshold should cover the areas/ features you want to analyse e.g. cytosol or nucleus
//it generates cell masks which are measured, then it generates nucleus masks 
//it loops through each identified cell and performs a measurement if it meets the criteria
//otherwise a message is displayed in the row: No particle detected

//now you can start the macro

dialog_channels = newArray("1", "2", "3", "4");
composite_channels = newArray("1000", "0100", "0010", "0001");

Dialog.create("Choices");
Dialog.addCheckbox("I have a cytosolic marker or no brightfield!", false);
Dialog.addMessage("Choose channels for the cell mask: brightfield");
//Checkbox to generate string later
Dialog.addCheckboxGroup(1, 4, dialog_channels, newArray(false, false, false, true));
Dialog.addMessage("Choose range to generate MaxIntensity projection");
Dialog.addNumber("Z-stack first slice", 2);
Dialog.addNumber("Z-stack last slice", 5);
//Radio buttons for channel selection
Dialog.addMessage("Choose channels for masks and measurements");
Dialog.addRadioButtonGroup("Channel of ER marker", dialog_channels, 1, 4, "1");
Dialog.addRadioButtonGroup("Channel of nucleus marker", dialog_channels, 1, 4, "2");
Dialog.addRadioButtonGroup("Channel with puncta", dialog_channels, 1, 4, "3");

Dialog.show();
//extract the boolean array to generate the composite channels
cyt_marker = Dialog.getCheckbox();
mask_channels = "";
for (i = 0; i < dialog_channels.length; i++) {
	mask_channels = mask_channels+Dialog.getCheckbox();
};
//extract all other choices
z_first = Dialog.getNumber();
z_last = Dialog.getNumber();
ER_channel = Dialog.getRadioButton;
nuc_channel = Dialog.getRadioButton;
puncta_channel = Dialog.getRadioButton;

dir = getDirectory("Choose a folder to save the tables");

run("Set Measurements...", "area mean median limit display redirect=None decimal=2");
run("Threshold...");

imagelist = getList("image.titles");
for (l = 0; l < imagelist.length; l++) {
    selectImage(imagelist[l]);
    onoma = getTitle();
    name = onoma.replace("\\s?-?\\s?\\w*\\.\\w+","");
    print("Image:", name);
//first we duplicate the original image, either Max projection or duplicate
	Stack.setDisplayMode("Composite");
	Stack.getDimensions(width, height, channels, slices, frames);
	if (slices==1) {
		run("Duplicate...", "duplicate");
		z_first=1;
		z_last=1;
	}
	else {
		run("Z Project...", "start=z_first stop=z_last projection=[Max Intensity]");
	};
	rename(name+" MaxIntensity");
	maxInt = getTitle();
	for (n=0; n<channels; n++) {
		Stack.setChannel(n);
		resetMinAndMax;
	};
	var mlower; //global variable
	
//first we make the general cell mask, for whole cells without buds
//and define single cells as ROIs
	if (cyt_marker==1){
		mask = Generate_CellMask();
	}
	else {	
		mask = Generate_CellMask_Cellborder();
	};
//for whole cells without buds
	run("Analyze Particles...", "size=7-29 circularity=0.50-1.00 show=Nothing exclude clear include summarize overlay add");
	roiManager("Show All without labels"); 

//make mask and ROIs for puncta
	var nlower;
	var plower;
	var actualPercent; 	
	puncta_mask = Generate_PunctaMask_woNE();//to exclude NE signal
	
	cell_masked = Apply_cellmask(puncta_channel);
	setThreshold(1, 255);
//measure intensities to later assign puncta to individual cells,
//the actual values are not important
	roiManager("multi-measure append"); 
	close(mask);
	close(cell_masked);
	
	puncta_masked = Apply_punctamask(puncta_channel);
	close(puncta_mask);
//loop through each cell ROI: measure the thresholded puncta inside of segmented cells	
	setThreshold(1, 255);
	for (p = 0; p < roiManager("count"); p++) { 
		init_results = nResults; //stores the initial number or results
		roiManager("Select", p);
		run("Analyze Particles...", "size=0.01-0.2 circularity=0.00-1.00 show=Nothing display include overlay");
		if (nResults == init_results) { //compares number of results now with inital number, if the numbers match (i.e. no particles were measured) then the message is added
			setResult("Message", init_results, "No particle detected");
			updateResults();
		};
	};

//add the thresholding information to the Result file
	setResult("Message", nResults, "Channels for cell mask: "+mask_channels+"; puncta channel: "+puncta_channel+"; nucleus channel: "+nuc_channel+"; z-slices: "+z_first+"-"+z_last);
	setResult("Message", nResults, "Cell mask threshold: "+mlower+", 255; nucleus mask threshold: "+nlower+", 255");
	setResult("Message", nResults, "Puncta threshold: "+plower+", 255 which covers "+d2s(actualPercent,2)+"% of all pixels");
	updateResults();
	selectWindow("Results");
	saveAs("txt", dir+name+".txt");
	close(puncta_masked);
	close(maxInt);
	close(onoma);
	
};
selectWindow("Summary");
saveAs("txt", dir+"Summary_"+name+".txt");
waitForUser("All done! Cancel now.");

---------------------------------------------------------------------------------
//here all functions defined:
function CalcThreshold(desiredPercent) {	
	getDimensions(width, height, channels, slices, frames);
	totalPixels = width * height;
	
	imageArray = newArray(totalPixels); // Copy pixel values into array
	index = 0;
	for (y = 0; y < height; y++) {
	    for (x = 0; x < width; x++) {
	        imageArray[index] = getPixel(x, y);
	        index++;
	    }
	}
	Array.sort(imageArray); // Sort pixel values
	
// Determine threshold that gives desired % coverage
	targetIndex = floor(totalPixels * (1 - desiredPercent / 100)); //Returns the largest value
	thresholdValue = imageArray[targetIndex];	
// Calculate pixels above my threshold (targetIndex) and the coverage this is
	actualPercent = ((totalPixels-targetIndex) / totalPixels) * 100;
	return thresholdValue;
};

function Generate_CellMask() { 
//for Nups use NE signal and fill holes	
//Generate binary mask and segment cells
	selectImage(maxInt);
	Stack.setActiveChannels(mask_channels)
	run("Stack to RGB", "keep");
	run("16-bit");
	run("Despeckle");
	run("Threshold...");
	mlower = CalcThreshold(15); //take xx% pixel coverage
	if (mlower <=3) {
		mlower = 2;
	};
	setThreshold(mlower, 65535);
	waitForUser;
	run("Convert to Mask", "background=Dark black create");
	run("Fill Holes");
	run("Watershed");
	rename("mask "+name);
	mask = getTitle();
	return mask;
};
	
function Generate_CellMask_Cellborder() { 
//Generate cell border mask (surrounding halo)
	selectImage(maxInt);
	Stack.setActiveChannels(mask_channels);
	resetMinAndMax;
	run("Stack to RGB");
	run("16-bit");
	run("Despeckle");
	run("Maximum...", "radius=1"); //or 2
	run("Variance...", "radius=4");
	mlower = CalcThreshold(1.5); //threshold up to a set xx% pixel coverage
	setThreshold(mlower, 65535);
	waitForUser;
	run("Convert to Mask", "background=Dark black create");	
	rename("Cell border mask");
	cellborder = getTitle();
	run("Options...", "iterations=6 count=4 black do=Close");
	run("Options...", "iterations=6 count=3 black pad do=Erode");
//whole cells mask
	selectImage(maxInt);
	Stack.setChannel(ER_channel);
	run("Enhance Contrast", "saturated=0.5");
	Stack.setActiveChannels(composite_channels[ER_channel-1])
	run("Stack to RGB");
	run("16-bit");
	run("Gaussian Blur...", "sigma=2");
	run("Despeckle");
	mlower = CalcThreshold(15); //threshold up to a set xx% pixel coverage
	if (mlower <3) {
		mlower = 2;
	};
	setThreshold(mlower, 65535);
	waitForUser("Choose best threshold to cover most cells and without specles\nclick 'Set'");
	getThreshold(mlower, upper);
	run("Convert to Mask", "background=Dark black create");	
	run("Fill Holes");
	run("Options...", "iterations=4 count=1 black pad do=Erode");
	wholecell = getTitle();	
//Seperate single cells and segment
	imageCalculator("Subtract",wholecell, cellborder);
	rename("mask "+name);
	mask = getTitle();
	run("Watershed");
	close(cellborder);
	return mask;	
};

function Generate_PunctaMask_woNE() { 
//make mask which finds all puncta and excludes puncta in the nucleus/ NE
//first generate nucleus mask
	selectImage(maxInt);
	Stack.setChannel(nuc_channel);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setActiveChannels(composite_channels[nuc_channel-1]);
	run("Stack to RGB");
	run("16-bit");
	run("Despeckle");
	run("Gaussian Blur...", "sigma=1");
	nlower = CalcThreshold(2); //nucleus mask
	setThreshold(nlower, 65535);
	waitForUser("Choose best threshold to cover most nuclei and without specles\nclick 'Set'");
	getThreshold(nlower, upper);
	run("Convert to Mask", "background=Dark black create");
	run("Options...", "iterations=6 count=4 black pad do=Dilate");
	rename("NE mask");
	NEmask = getTitle();
//isolate NE & puncta
	selectImage(maxInt);
	Stack.setChannel(puncta_channel);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setActiveChannels(composite_channels[puncta_channel-1])
	run("Stack to RGB");
	run("16-bit");
	run("Despeckle");
	plower = CalcThreshold(1); 
	setThreshold(plower, 65535);
	run("Convert to Mask", "background=Dark black create");
	run("Options...", "iterations=4 count=3 black pad do=Dilate");
	run("Options...", "iterations=4 count=4 black pad do=Erode");
	rename("puncta");
	puncta = getTitle();
//generate inital puncta mask
	run("Analyze Particles...", "size=0.01-0.2 circularity=0.00-1.00 show=Masks exclude clear include overlay");
	run("Invert LUT");
	rename("puncta mask");
	puncta_mask = getTitle();
//remove all puncta which are in the nucleus/ NE
	imageCalculator("Subtract", puncta_mask, NEmask);	
	setThreshold(1, 255);
	run("Analyze Particles...", "size=0.01-0.2 circularity=0.00-1.00 exclude clear include summarize overlay"); //this is only for the summary txt file
	close(NEmask);
	close(puncta);
	return puncta_mask;
}; 

function Apply_cellmask(mchannel) { //the channel is defined when calling the function
//now combine mask with the channel you want to measure the intensity
	selectImage(maxInt);
	Stack.setDisplayMode("Color");
	Stack.setChannel(mchannel);	
	resetMinAndMax;
	imageCalculator("AND create", mask, maxInt);
	rename(name+"_cell channel "+mchannel);
	masked = getTitle();
	return masked;
};

function Apply_punctamask(mchannel) { //the channel is defined when calling the function
//now combine mask with the channel you want to measure the intensity
	selectImage(maxInt);
	Stack.setChannel(mchannel);	
	resetMinAndMax;
	imageCalculator("AND create", puncta_mask,maxInt);
	rename(name+"_puncta channel "+mchannel);
	masked = getTitle();
	return masked;
};

