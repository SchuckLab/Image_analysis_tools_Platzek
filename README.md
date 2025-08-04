# Image_analysis_tools_Platzek
This is a collection of Fiji and Python scripts used for image analysis in the paper "Dynamic Organellar Mapping in yeast reveals extensive protein localization changes during ER stress" by Platzek et al. The collection comprises three pairs of a Fiji script and an associated jupyter notebook. These pairs are meant for:  

## Quantification of ER or nuclear envelope fractions
Images are quantified using the Fiji script QuantifyIntensity_ER.ijm. The resulting txt files are processed and the ER fractions or nuclear envelope fractions are calculated using the jupyter notebook ImageQuantification_Calculations.ipynb.

## Quantification of nucleoporin cytosolic puncta
Images are quantified using the Fiji script Puncta_counter.ijm. The resulting txt files are processed and the number of cytosolic nucleoporin puncta per cell are calculated using the jupyter notebook Nuppuncta_Quantification.ipynb.

## Quantification of nuclear import
Images are quantified using the Fiji script QuantifyNucImport.ijm. The resulting txt files are processed and the nuclear enrichment is calculated using the jupyter notebook NucImportQuantification_Calculations.ipynb.
