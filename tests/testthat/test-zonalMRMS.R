test_that("zonalMRMS extracts zonal means for each raster and writes csvs", {
  raster_dir <- test_path("processedTIF")
  output_dir <- withr::local_tempdir()
  boundary <- test_path("catchments_all_lidar.shp")

  n_rasters <- length(list.files(raster_dir, pattern = "\\.tif$"))
  n_catchments <- nrow(terra::vect(boundary))

  zonalMRMS(raster_dir = raster_dir, output_dir = output_dir, boundary = boundary, n_workers = 1)

  out_files <- list.files(output_dir, pattern = "\\.csv$")
  expect_length(out_files, n_rasters)

  df <- utils::read.csv(file.path(output_dir, out_files[1]))
  expect_true(all(c("p_mmhr", "catchment", "datetime", "doy", "hour", "min") %in% names(df)))
  expect_equal(nrow(df), n_catchments)
})
