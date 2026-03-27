

downloadMRMS(lubridate::ymd_hm(start = '2025-01-01 02:00'),
             lubridate::ymd_hm(end = '2025-01-01 6:00'),
             destination = './tests/testthat',
             product = 'RadarOnlyQPE')

library(terra)
test <- rast('./tests/testthat/RadarOnly_QPE_01H_00.00_20250101-040000.grib2')
plot(test)
