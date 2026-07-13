test_that("prepMRMS crops grib2 files to a boundary and writes tifs", {
  input_dir <- withr::local_tempdir()
  output_dir <- withr::local_tempdir()

  grib_files <- list.files(test_path(), pattern = "\\.grib2$", full.names = TRUE)
  file.copy(grib_files, input_dir)
  boundary <- test_path("catchments_all_lidar.shp")

  prepMRMS(dir = input_dir, output_dir = output_dir, num_cores = 1, boundary = boundary)

  out_files <- list.files(output_dir, pattern = "_processed\\.tif$")
  expect_length(out_files, length(grib_files))

  r <- terra::rast(file.path(output_dir, out_files[1]))
  b <- terra::vect(boundary)
  b_proj <- terra::project(b, terra::crs(r))

  expect_true(terra::same.crs(r, b_proj))
  expect_equal(as.vector(terra::ext(r)), as.vector(terra::ext(b_proj)), tolerance = 0.02)
})

test_that("prepMRMS skips files that are already processed", {
  input_dir <- withr::local_tempdir()
  output_dir <- withr::local_tempdir()

  grib_file <- list.files(test_path(), pattern = "\\.grib2$", full.names = TRUE)[1]
  file.copy(grib_file, input_dir)
  boundary <- test_path("catchments_all_lidar.shp")

  prepMRMS(dir = input_dir, output_dir = output_dir, num_cores = 1, boundary = boundary)

  expect_message(
    prepMRMS(dir = input_dir, output_dir = output_dir, num_cores = 1, boundary = boundary),
    "All files already processed"
  )
})

test_that("prepMRMS requires boundary to be a file path", {
  input_dir <- withr::local_tempdir()
  output_dir <- withr::local_tempdir()
  b <- terra::vect(test_path("catchments_all_lidar.shp"))

  expect_error(
    prepMRMS(dir = input_dir, output_dir = output_dir, num_cores = 1, boundary = b),
    "boundary must be a file path"
  )
})
