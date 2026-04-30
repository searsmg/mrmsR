

prepMRMS(dir = '/Users/megansears/Documents/MRMS_temp/height21',
         output_dir = '/Users/megansears/Documents/MRMS_temp/height21_processed',
         num_cores = 8,
         boundary = '/Volumes/MSears_Mac2/Documents/MRMS/bbox_2fires/bbox_2fires.shp')

library(terra)

test <- rast('./tests/testthat/RadarOnly_QPE_01H_00.00_20250101-020000_processed.tif')

plot(test)

library(terra)
library(mapview)
test1 <- vect('/Volumes/MSears_Mac2/Documents/MRMS/bbox_2fires/bbox_2fires.shp')

mapview(test1)
