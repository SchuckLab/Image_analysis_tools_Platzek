//Macro to measure mean intensities of single whole cells and their corresponding organelle (ER)

//first choose the channel and slice you want to analyze
//the threshold should cover the areas/ features you want to analyse e.g. cytosol or nucleus
//it generates single cells which are measured, then it generates organelle (ER) mask measures 
//it loops through each identified cell and performs a measurement if it meets the criteria
//otherwise a message is displayed in the row: No particle detected


dir = getDirectory("Choose a folder to save the tables");

dialog_channels = newArray("1", "2", "3", "4");
composite_channels = newArray("1000", "0100", "0010", "0001");

Dialog.create("Choices");
Dialog.addCheckbox("I have a cytosolic marker!", false);
Dialog.addMessage("Choose channels for the cell mask");
//Checkbox to generate string later
Dialog.addCheckboxGroup(1, 4, dialog_channels, newArray(false, false, true, false));
Dialog.addMessage("Choose range to generate MaxIntensity projection");
Dialog.addNumber("Z-stack first slice", 2);
Dialog.addNumber("Z-stack last slice", 4);
//Radio buttons for channel selection
Dialog.addMessage("Choose channels for masks and measurements");
Dialog.addRadioButtonGroup("Channel of cell signal", dialog_channels, 1, 4, "1");
Dialog.addRadioButtonGroup("Channel of ER marker", dialog_channels, 1, 4, "1");
Dialog.addRadioButtonGroup("Channel of nucleus marker", dialog_channels, 1, 4, "2");
Dialog.addRadioButtonGroup("Channel for POI 1", dialog_channels, 1, 4, "2");
Dialog.addRadioButtonGroup("Channel for POI 2", dialog_channels, 1, 4, "1"); //no dialog_channels and no List.get etc needed 
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
cell_channel = Dialog.getRadioButton();
ER_channel = Dialog.getRadioButton;
nuc_channel = Dialog.getRadioButton();
measure1_channel = Dialog.getRadioButton;
measure2_channel = Dialog.getRadioButton;

run("Set Measurements...", "area mean median limit display redirect=None decimal=2");
run("Threshold...");
 
//macro now really starts
imagelist = getList("image.titles");
for (l = 0; l < imagelist.length; l++) {
    selectImage(imagelist[l]);
    onoma = getTitle();
    name = onoma.replace("\\s?-?\\s?\\w*\\.\\w+",""); //removes file ending: deconvolved or hyperstack
    print("Image:", name);
//duplicate the original to not change anything
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
	rename(name);
	maxInt = getTitle();
	var mlower; //global variable
	
//first we make the general cell mask, for whole cells without buds
//and define single cells as ROIs
	if (cyt_marker==1){
		mask = Generate_CellMask();
	}
	else {	
		mask = Generate_CellMask_Cellborder();
	};
	setThreshold(1, 255);
	run("Analyze Particles...", "size=7-29 circularity=0.50-1.00 show=Nothing exclude clear include summarize overlay add");
	roiManager("Show All without labels"); 
	waitForUser;
	var ERlower;	
	ER_mask = Generate_ERMask();
	if (name.contains("Gas")) {
		ER_mask = Keep_NE();
	};

// calculate pixel intensities of image in specified ROIs
	ROImeasure1 = ROIs_measure(measure1_channel);
	ROImeasure2 = ROIs_measure(measure2_channel);

//add the thresholding information to the Result file
	setResult("Message", nResults, "Channels for cell mask: "+mask_channels+", cell signal: "+cell_channel+", ER channel: "+ER_channel+", POI channel: "+measure1_channel+", z-slices: "+z_first+"-"+z_last);
	setResult("Message", nResults, "Cell mask threshold: "+mlower+", 65535");
	updateResults();
	close(mask);
	close(ER_mask);
	close(maxInt);
//save everything
	selectWindow("Results");
	saveAs("txt", dir+name+".txt");
	close("Results");
	close(onoma);
};
selectWindow("Summary");
saveAs("txt", dir+"Summary_cellcount_"+name+".txt");
waitForUser("All done! Cancel now.");

---------------------------------------------------------------------------------
//here are all functions defined:

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
//Generate binary mask and segment cells
	selectImage(maxInt);
	Stack.setDisplayMode("Composite");
    resetMinAndMax;	
	Stack.setActiveChannels(mask_channels);
	run("Stack to RGB", "keep");
	run("16-bit");
	run("Gaussian Blur...", "sigma=2");
	run("Threshold...");
	setAutoThreshold("Otsu dark 16-bit");// or Intermodes
	waitForUser;
	getThreshold(mlower, upper);
	run("Convert to Mask", "background=Dark black");
	run("Despeckle");
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
	run("Maximum...", "radius=1");
	run("Variance...", "radius=4");
	setAutoThreshold("Otsu dark 16-bit");
	run("Convert to Mask", "background=Dark black create");	
	rename("Cell border mask");
	cellborder = getTitle();
	run("Options...", "iterations=6 count=4 black do=Close");
	//if thresholding of borders doesn't work well do additional operations
	run("Options...", "iterations=3 count=3 black pad do=Erode");
//whole cells mask
	selectImage(maxInt);	
	Stack.setActiveChannels(composite_channels[cell_channel-1])
	run("Stack to RGB");
	run("16-bit");
	run("Gaussian Blur...", "sigma=2");
	run("Despeckle");
	mlower = CalcThreshold(25); //take xx% pixel coverage
	if (mlower <3) {
		mlower = 3;
	};
	setThreshold(mlower, 65535);
	waitForUser("Choose best threshold to cover most cells and without specles\nclick 'Set'");
	getThreshold(mlower, upper);
	run("Convert to Mask", "background=Dark black create");
	run("Fill Holes");
	run("Options...", "iterations=4 count=1 black pad do=Erode");
	wholecell = getTitle();	
	imageCalculator("Subtract",wholecell, cellborder);
	rename("mask "+name);
	mask = getTitle();
	run("Watershed");
	close(cellborder);
	return mask;	
}; 

function Generate_ERMask() { 
// Generate ER mask based on Sec63 ER marker
	selectImage(maxInt);	
	Stack.setChannel(ER_channel);
	resetMinAndMax;
	run("Enhance Contrast", "saturated=0.1"); // disable for green channel
	Stack.setActiveChannels(composite_channels[ER_channel-1]); //make a composite string
	run("Stack to RGB");
	run("Despeckle");
	run("8-bit");
	run("Auto Local Threshold", "method=Bernsen radius=5 parameter_1=0 parameter_2=0 white");
	run("Options...", "iterations=1 count=4 black pad do=Erode");
	rename("ER mask");
	ER_mask = getTitle();
	return ER_mask;
};

function Keep_NE() { 
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
	rename("nucleus mask");
	nuc_mask = getTitle();	
	imageCalculator("AND", ER_mask, nuc_mask);
	rename("NE mask");
	NE_mask = getTitle();
	close(nuc_mask);
	return NE_mask;
};

function ROIs_measure (mchannel) { 
// Generate organelle ROIs inside the cell ROIs
//and measure "raw" values in these ROIs

	setBatchMode(true); // Disable screen updates	
	setThreshold(1, 65535);
	
	for (p = 0; p < roiManager("count"); p++) { 
		
		startIndex = roiManager("count");
		
		selectImage(maxInt);
		Stack.setChannel(mchannel);
		roiManager("Select", p);
		roiManager("rename", p+1+"_cell channel "+mchannel);
		roiManager("measure"); //measure whole cell intensity
	// define new ROIs of ER mask inside single cell ROI, add to manager
		selectImage(ER_mask);
		roiManager("Select", p);
		run("Analyze Particles...", "size=0 circularity=0 include add");
		endIndex = roiManager("count");
		nNew = endIndex - startIndex;
		if (nNew == 0) { //exclude cells without ER
			setResult("Message", nResults, "No particle detected");
			updateResults();
			print(p+1+": No particle detected");
			continue; 
		};
		
		newIndices = newArray(nNew); // Build an array of new ROI indices
		for (i = 0; i < nNew; i++) {
		    newIndices[i] = startIndex + i;
		}
		selectImage(maxInt);
		roiManager("Select", newIndices);	
		roiManager("Combine");
		roiManager("Add");	
		roiManager("Select", roiManager("count") - 1);
		roiManager("rename", p+1+"_ER channel "+mchannel);
		roiManager("measure"); //measure organelle (ER) intensity inside ER ROIs
	// select and delete all new ROIs
		roiManager("Select", newIndices);
		roiManager("Delete");
		roiManager("Select", roiManager("count") - 1);
		roiManager("Delete");
	};
	setBatchMode(false); // Enable screen updates
	return;
};
