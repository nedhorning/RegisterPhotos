// This macro registers two images - one acquired by an unmodified digital camera and the other
// from a digital camera that records infrared imagery. There are options to create an NGB false-color
// composite and NDVI images, both floating point and byte with a look-up table applied. The images are 
// clipped to output only the coincident area of the two images
//
// The macro will read a text file with the file names of the image pairs that will be registered with each file 
// name separated by a comma. The first image is the near_IR image (the image tht will be warped) and the 
// second image is the visible image (used as a reference but not altered). The last line must be "end" (not case sensitive
// and do not include the quotation marks.
//
// Questions and comments can be sent to Ned Horning - horning@amnh.org 
//
// Create dialog for entering parameters
lutList = getFileList(getDirectory("luts"));
Dialog.create("Processing choices");
Dialog.addChoice("Create NGR image?", newArray("yes", "no"));
Dialog.addChoice("Create Color NDVI image?", newArray("yes", "no"));
Dialog.addChoice("Create floating point NDVI image?", newArray("yes", "no"));
Dialog.addChoice("Output clipped visible image?", newArray("yes", "no"));
Dialog.addChoice("Output image type", newArray("tiff", "jpeg", "gif", "zip", "raw", "avi", "bmp", "fits", "png", "pgm"));
Dialog.addChoice("Select output color table for color NDVI image", lutList)
Dialog.addNumber("Enter maximum clipping distance for width (pixels)", 200);
Dialog.addNumber("Enter maximum clipping distance for height (pixels)", 200);
Dialog.show();
createNGR = Dialog.getChoice();
createNDVIColor  = Dialog.getChoice();
createNDVIFloat = Dialog.getChoice();
outputClipVis = Dialog.getChoice();
fileType = Dialog.getChoice();
lut = Dialog.getChoice();
xBuffer = Dialog.getNumber();
yBuffer = Dialog.getNumber();
lut = split(lut, ".")
lut = lut[0]
// Directory for input/output images
directory = getDirectory("Choose the image directory");

// File open dialog and read the directory information
path = File.openDialog("Select the file with image names");
contents = File.openAsString(path)
list = split(contents, "\n");
// Check image pairs to make sure they exist
i=0;
while (list[i] != "end") {
   if (list[list.length-1] != "end") {
      exit("The word end must be the last line of the image pair text file");
   }
   twoImageNames = split(list[i], ",");
   image1 = replace(twoImageNames[0], "\\s*$", "");
   image1 = replace(image1, "^\\s*", "");
   exists = File.exists(directory+image1);
   if (exists != 1) {
      exit("The filename "+image1+" does not exist in "+directory);
   }
   image2 = replace(twoImageNames[0], "\\s*$", "");
   image2 = replace(image1, "^\\s*", "");
   exists = File.exists(directory+image2);
   if (exists != 1) {
      exit("The filename "+image2+" does not exist in "+directory);
   }
   i = i + 1;
   if (i == list.length) {
      exit("The word end must be the last line of the file with no spaces before")
   }
}
// Start processing image pairs
i=0;
while (list[i] != "end") {
   twoImageNames = split(list[i], ",");
   // Remove leading and trailing spaces
   image1 = replace(twoImageNames[0], "\\s*$", "");
   image1 = replace(image1, "^\\s*", "");
   open(directory+image1);
   sourceImage = getTitle();
   // Remove leading and trailing spaces
   image2 = replace(twoImageNames[1], "\\s*$", "");
   image2 = replace(image2, "^\\s*", "");
   open(directory+image2);
   targetImage = getTitle();
   outFileBase = File.nameWithoutExtension;
   // Get match points using SIFT
   run("Extract SIFT Correspondences", "source_image="+targetImage+" target_image="+sourceImage+" initial_gaussian_blur=1.60    steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=1024 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/   next_closest_ratio=0.92 filter maximal_alignment_error=25 minimal_inlier_ratio=0.05 minimal_number_of_inliers=7 expected_transformation=Affine");
   // Register the images
   run("Landmark Correspondences", "source_image="+sourceImage+" template_image="+targetImage+" transformation_method=[Moving Least Squares (non-linear)] alpha=1 mesh_resolution=32 transformation_class=Affine interpolate");
   selectWindow("Transformed"+sourceImage);
   run("Duplicate...", "title=tempImage.tif");
   // Clip images
   // Convert image to 8-bit
   run("8-bit");
   xminStart = xBuffer;
   yminStart = yBuffer;
   imageHeight = getHeight;
   imageWidth = getWidth();
   xmaxStart = imageWidth - xBuffer * 2;
   ymaxStart = imageHeight - yBuffer * 2;
   xmin = xminStart;
   xmax = xmaxStart;
   ymin = yminStart;
   ymax = ymaxStart;
   tooSmall = true;
   // Test for ymin
   while (tooSmall && ymin > 0) {
      ymin--;
      for (j=xminStart; j<xmaxStart; j++) {
         if (getPixel(j, ymin) == 0) {
            tooSmall=false;
         }
      }   
   }
   print("ymin = " + ymin);

   tooSmall = true;
   // Test for ymax
   while (tooSmall && ymax < imageHeight) {
      ymax++;
      for (j=xminStart; j<xmaxStart; j++) {
         if (getPixel(j, ymax) == 0) {
            tooSmall=false;
         }
      }   
   }
   print("ymax = " + ymax);
   tooSmall = true;
   // Test for xmin
   while (tooSmall && xmin > 0) {
      xmin--;
      for (j=yminStart; j<ymaxStart; j++) {
         if (getPixel(xmin, j) == 0) {
            tooSmall=false;
         }
      }   
   }
   print("xmin = " + xmin);
   tooSmall = true;
   // Test for xmax
   while (tooSmall && xmax < imageWidth) {
      xmax++;
      for (j=yminStart; j<ymaxStart; j++) {
         if (getPixel(xmax, j) == 0) {
            tooSmall=false;
         }
      }   
   }
   print("xmax = " + xmax);
   // Calculate selection rectangle shriking by 5 pixels on a side
   makeRectangle(xmin+5,ymin+5, xmax - xmin - 4, ymax - ymin - 4);

   // Crop images

   selectWindow(targetImage);
   run("Restore Selection");
   run("Crop");
   if (outputClipVis == "yes") {
      clipTarget = directory+outFileBase+"_clipped."+fileType;
      saveAs(fileType, clipTarget);
   }
   targetImage = getTitle();
   run("Split Channels");
 
   selectWindow("Transformed"+sourceImage);
   run("Restore Selection");
   run("Crop");
   run("Split Channels");

   // Calculate NDVI image
   if (createNDVIColor == "yes" || createNDVIFloat == "yes") {
      imageCalculator("create 32-bit subtract", "Transformed"+sourceImage+" (red)", targetImage+" (red)");
      numerator = getImageID();
      imageCalculator("create 32-bit add", "Transformed"+sourceImage+" (red)", targetImage+" (red)");
      denominator = getImageID();
      imageCalculator("create 32-bit divide", numerator, denominator);
      if (createNDVIFloat == "yes") {      
         outNDVI_Float = directory+outFileBase+"_NDVI_Float."+fileType;
         // Write floating point NDVI image
         saveAs(fileType, outNDVI_Float);
      }
      // Scale from floating point to byte and add a color table
      if (createNDVIColor == "yes") {
         run("Macro...", "code=v=(v+1)*255/2");
         run("8-bit");
         run(lut);
         outNDVI_Color = directory+outFileBase+"_NDVI_Color."+fileType;
         // Write color NDVI image
         saveAs(fileType, outNDVI_Color);
      }
   }
   // Create an NGR image
   if (createNGR == "yes") {
      run("Merge Channels...", "red=[Transformed"+sourceImage+" (red)] green=["+targetImage+" (red)] blue=["+targetImage+" (green)] gray=*None*");
      outNRG = directory+outFileBase+"_NRG."+fileType;
      // Output NRG image
      saveAs(fileType, outNRG);
   }
   run("Close All");
   i = i + 1;
}
