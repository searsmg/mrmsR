

prepMRMS(dir = './tests/testthat',
         output_dir = './tests/testthat',
         num_cores =2,
         boundary = './tests/testthat/catchments_all_lidar.shp')

library(terra)

test <- rast('./tests/testthat/RadarOnly_QPE_01H_00.00_20250101-020000_processed.tif')

plot(test)
