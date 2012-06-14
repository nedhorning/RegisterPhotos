// This macro registers two images - one acquired by an unmodified digital camera and the other
// from a digital camera that records infrared imagery. There are options to create an NGB false-color
// composite and NDVI images, both floating point and byte with a look-up table applied. The images are 
// clipped to output only the coincident area of the two images
//
// The macro will read a text file with the file names of the image pairs that will be registered with each file 
// name separated by a comma. The first image is the near_IR image (the source image tht will be warped) and the 
// second image is the visible image (the target image used as a reference but not altered). The last line must 
// be "end" (not case sensitive and do not include the quotation marks.
//
// A log file is created to document which registration method was used for each image pair.
//
// Questions and comments can be sent to Ned Horning - horning@amnh.org 
//
// Create dialog for entering parameters
lutList = getFileList(getDirectory("luts"));
Dialog.create("Processing choices");
Dialog.addChoice("Select registration method", newArray("Try SIFT", "SIFT", "bUnwarpJ"));
Dialog.addChoice("Select transformation type if using SIFT", newArray("Affine", "Rigid"));
Dialog.addChoice("Create NGR image?", newArray("yes", "no"));
Dialog.addChoice("Create Color NDVI image?", newArray("yes", "no"));
Dialog.addChoice("Create floating point NDVI image?", newArray("yes", "no"));
Dialog.addChoice("Output clipped visible image?", newArray("yes", "no"));
Dialog.addChoice("Output image type", newArray("tiff", "jpeg", "gif", "zip", "raw", "avi", "bmp", "fits", "png", "pgm"));
Dialog.addChoice("Select output color table for color NDVI image", lutList);
Dialog.addString("Enter name for log file", "log.txt");
Dialog.show();
method = Dialog.getChoice();
transType = Dialog.getChoice();
createNGR = Dialog.getChoice();
createNDVIColor  = Dialog.getChoice();
createNDVIFloat = Dialog.getChoice();
outputClipVis = Dialog.getChoice();
fileType = Dialog.getChoice();
lut = Dialog.getChoice();
logName = Dialog.getString();
lut = split(lut, ".")
lut = lut[0]
// Directory for input images
inDirectory = getDirectory("Choose the input image directory");
// Directory for output images
outDirectory = getDirectory("Choose the output image directory");
logFile = File.open(outDirectory+logName); 
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
   exists = File.exists(inDirectory+image1);
   if (exists != 1) {
      exit("The filename "+image1+" does not exist in "+inDirectory);
   }
   image2 = replace(twoImageNames[0], "\\s*$", "");
   image2 = replace(image1, "^\\s*", "");
   exists = File.exists(inDirectory+image2);
   if (exists != 1) {
      exit("The filename "+image2+" does not exist in "+inDirectory);
   }
   i = i + 1;
   if (i == list.length) {
      exit("The word end must be the last line of the file with no blank lines before")
   }
}

// Start processing image pairs
i=0;
while (list[i] != "end") {
   continue = true;
   twoImageNames = split(list[i], ",");
   // Remove leading and trailing spaces
   image1 = replace(twoImageNames[0], "\\s*$", "");
   image1 = replace(image1, "^\\s*", "");
   open(inDirectory+image1);
   sourceImage = getTitle();
   // Remove leading and trailing spaces
   image2 = replace(twoImageNames[1], "\\s*$", "");
   image2 = replace(image2, "^\\s*", "");
   open(inDirectory+image2);
   targetImage = getTitle();
   outFileBase = File.nameWithoutExtension;
   if (method == "SIFT" || method == "Try SIFT") {
      print("Processing "+image1+" and "+image2+" using SIFT and landmark correspondences"); 
      trys = 1;
      noPoints = true;
      run("Select None");
      // Try up to 5 times to get SIFT correspondence points
      while (trys <= 5 && noPoints) {
         print("Number of times trying SIFT: "+trys);   
         // Get match points using SIFT
         run("Extract SIFT Correspondences", "source_image="+targetImage+" target_image="+sourceImage+" initial_gaussian_blur=1.60    steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=1024 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/   next_closest_ratio=0.92 filter maximal_alignment_error=25 minimal_inlier_ratio=0.05 minimal_number_of_inliers=7 expected_transformation="+transType);
         if (selectionType() == 10) {
            noPoints = false;
         }
         trys = trys + 1;
      }
         // Register the images
      if (!noPoints) {
         run("Landmark Correspondences", "source_image="+sourceImage+" template_image="+targetImage+" transformation_method=[Moving Least Squares (non-linear)] alpha=1 mesh_resolution=32 transformation_class="+transType+" interpolate");
         print(logFile, "Images "+image1+" and "+image2+" registered using SIFT and landmark correspondences and "+transType+" transformation");
         selectWindow("Transformed"+sourceImage);
         run("Duplicate...", "title=tempImage.tif");
      } else if (method == "Try SIFT") {
         noPoints = true;  // no correspondence points created
         print("No points generated for landmark correspondence - trying bUnwarpJ");
      } else {
         print(logFile, "SIFT was not able to create points for image pair "+image1+" and "+image2+" - rerun using bUnwarpJ option");
         print("SIFT was not able to create points for image pair "+image1+" and "+image2+" - rerun using bUnwarpJ option");
         continue = false;
      }
   } 

   if (method == "bUnwarpJ" || (method == "Try SIFT" && noPoints)) {
      print("Processing "+image1+" and "+image2+" using bUnwarpJ");
      run("bUnwarpJ", "source_image="+sourceImage+" target_image="+targetImage+" registration=Fast image_subsample_factor=0 initial_deformation=[Very Coarse] final_deformation=Fine divergence_weight=0 curl_weight=0 landmark_weight=0 image_weight=1 consistency_weight=10 stop_threshold=0.01");
      print(logFile, "Images "+image1+" and "+image2+" registered using bUnwarpJ");
      selectWindow("Registered Source Image");
      run("Stack to Images");
      selectWindow("Registered Source Image");
      run("Duplicate...", "title=Transformed"+sourceImage);
      selectWindow("Registered Source Image");
   }
   if (continue) {
      // Set cropping parameters
      // Convert image to 8-bit
      run("8-bit");
      // This creates a selection rectangle of the entire image
      run("Select All");
      // Get coordinates from the selection bounding box
      getSelectionBounds(xmin, ymin, width, height);
      // Set variables for clipping
      xmax = width + xmin - 1;
      ymax = height + ymin - 1;
      imageHeight = getHeight;
      imageWidth = getWidth();
      topHasNoData = true;
      rightHasNoData = true;
      bottomHasNoData = true;
      leftHasNoData = true;
      sidesOK = 0;
      // Loop until all sides of the selection rectangle contain no no-data values
      while (sidesOK < 4) {
         proportionNoData = 0.0;
         move_xmin = false;
         move_xmax = false;
         move_ymin = false;
         move_ymax = false;
         moveSide = "";
         // For each side count the number of no-data pixel in the line or column then calculate percent no-data
         if (topHasNoData) {
            numNoData = 0;
            for (j=xmin+1; j<xmax; j++) {
               if (getPixel(j, ymin+1) == 0) {
                   numNoData++;
               }
            }
            if ((numNoData/xmax) > proportionNoData) {
               proportionNoData = numNoData/xmax;
               moveSide = "top";
            } else if (numNoData == 0) {
              topHasNoData = false;
              sidesOK = sidesOK + 1;
            }
         }
         if (rightHasNoData) {
            numNoData = 0;
           for (j=ymin+1; j<ymax; j++) {
               if (getPixel(xmax - 1, j) == 0) {
                   numNoData++;
               }
            }
            if ((numNoData/xmax) > proportionNoData) {
               proportionNoData = numNoData/xmax;
               moveSide = "right";
            } else if (numNoData == 0) {
              rightHasNoData = false;
              sidesOK = sidesOK + 1;
            }
         }
         if (bottomHasNoData) {
            numNoData = 0;
            for (j=xmin+1; j<xmax; j++) {
               if (getPixel(j, ymax - 1) == 0) {
                   numNoData++;
               }
            }
            if ((numNoData/xmax) > proportionNoData) {
               proportionNoData = numNoData/xmax;
               moveSide = "bottom";
            } else if (numNoData == 0) {
              bottomHasNoData = false;
              sidesOK = sidesOK + 1;
            }
         }
         if (leftHasNoData) {
            numNoData = 0;
            for (j=ymin+1; j<ymax; j++) {
               if (getPixel(xmin + 1, j) == 0) {
                   numNoData++;
               }
            }
            if ((numNoData/xmax) > proportionNoData) {
               proportionNoData = numNoData/xmax;
               moveSide = "left";
            } else if (numNoData == 0) {
              rightHasNoData = false;
              sidesOK = sidesOK + 1;
            }
         }
         // Move the side that has the highest proportion of no-data pixels
         if (moveSide == "top") {
            ymin = ymin + 1;
         }
         if (moveSide == "right") {
            xmax = xmax - 1;
         }
         if (moveSide == "bottom") {
            ymax = ymax - 1;
         }
         if (moveSide == "left") {
            xmin = xmin + 1;
         }
      }
      // Calculate selection rectangle
      makeRectangle(xmin,ymin, xmax - xmin - 1, ymax - ymin - 1);

      // Crop images
      selectWindow(targetImage);
      run("Restore Selection");
      run("Crop");
      if (outputClipVis == "yes") {
         clipTarget = outDirectory+outFileBase+"_clipped."+fileType;
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
            outNDVI_Float = outDirectory+outFileBase+"_NDVI_Float."+fileType;
            // Write floating point NDVI image
            saveAs(fileType, outNDVI_Float);
         }
         // Scale from floating point to byte and add a color table
         if (createNDVIColor == "yes") {
            run("Macro...", "code=v=(v+1)*255/2");
            run("8-bit");
            run(lut);
            outNDVI_Color = outDirectory+outFileBase+"_NDVI_Color."+fileType;
            // Write color NDVI image
            saveAs(fileType, outNDVI_Color);
         }
      }

      // Create an NGR image
      if (createNGR == "yes") {
         run("Merge Channels...", "red=[Transformed"+sourceImage+" (red)] green=["+targetImage+" (red)] blue=["+targetImage+" (green)] gray=*None*");
         outNRG = outDirectory+outFileBase+"_NRG."+fileType;
         // Output NRG image
         saveAs(fileType, outNRG);
      }
   }
   run("Close All");
   i = i + 1;
}
