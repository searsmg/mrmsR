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

test_that("zonalMRMS works with multiple parallel workers", {
  skip_on_cran()

  output_dir <- withr::local_tempdir()

  zonalMRMS(
    raster_dir = test_path("processedTIF"),
    output_dir = output_dir,
    boundary = test_path("catchments_all_lidar.shp"),
    n_workers = 2
  )

  n_rasters <- length(list.files(test_path("processedTIF"), pattern = "\\.tif$"))
  expect_length(list.files(output_dir, pattern = "\\.csv$"), n_rasters)
})

test_that("zonalMRMS keeps the same day and time in different years separate", {
  raster_dir <- withr::local_tempdir()
  output_dir <- withr::local_tempdir()

  tif <- list.files(test_path("processedTIF"), full.names = TRUE)[1]
  file.copy(tif, file.path(raster_dir, c(
    "RadarOnly_QPE_01H_00.00_20240101-020000_processed.tif",
    "RadarOnly_QPE_01H_00.00_20250101-020000_processed.tif"
  )))

  zonalMRMS(raster_dir, output_dir, test_path("catchments_all_lidar.shp"), n_workers = 1)

  expect_setequal(
    list.files(output_dir),
    c("extract_2024_1_02_00.csv", "extract_2025_1_02_00.csv")
  )
})

test_that("zonalMRMS requires boundary to be a file path", {
  b <- terra::vect(test_path("catchments_all_lidar.shp"))

  expect_error(
    zonalMRMS(test_path("processedTIF"), withr::local_tempdir(), b, n_workers = 1),
    "boundary must be a file path"
  )
})

test_that("zonalMRMS restores the caller's future plan", {
  withr::defer(future::plan(future::sequential))
  future::plan(future::multicore, workers = 1)

  zonalMRMS(test_path("processedTIF"), withr::local_tempdir(),
            test_path("catchments_all_lidar.shp"), n_workers = 1)

  expect_s3_class(future::plan(), "multicore")
})

test_that("zonalMRMS writes the full timestamp for midnight rasters", {
  raster_dir <- withr::local_tempdir()
  output_dir <- withr::local_tempdir()

  tif <- list.files(test_path("processedTIF"), full.names = TRUE)[1]
  file.copy(tif, file.path(raster_dir, "RadarOnly_QPE_01H_00.00_20250102-000000_processed.tif"))

  zonalMRMS(raster_dir, output_dir, test_path("catchments_all_lidar.shp"), n_workers = 1)

  df <- utils::read.csv(list.files(output_dir, full.names = TRUE))
  expect_equal(unique(df$datetime), "2025-01-02 00:00:00")
})

test_that("zonalMRMS labels catchments with id_col", {
  output_dir <- withr::local_tempdir()
  boundary <- test_path("catchments_all_lidar.shp")

  zonalMRMS(test_path("processedTIF"), output_dir, boundary, n_workers = 1, id_col = "ID")

  df <- utils::read.csv(list.files(output_dir, full.names = TRUE)[1])
  expect_equal(df$catchment, terra::vect(boundary)$ID)
})

test_that("zonalMRMS defaults to the site column", {
  output_dir <- withr::local_tempdir()
  boundary <- test_path("catchments_all_lidar.shp")

  zonalMRMS(test_path("processedTIF"), output_dir, boundary, n_workers = 1)

  df <- utils::read.csv(list.files(output_dir, full.names = TRUE)[1])
  expect_equal(df$catchment, terra::vect(boundary)$site)
})

test_that("zonalMRMS errors when id_col isn't in the boundary", {
  expect_error(
    zonalMRMS(test_path("processedTIF"), withr::local_tempdir(),
              test_path("catchments_all_lidar.shp"), n_workers = 1, id_col = "nope"),
    "is not a column in the boundary"
  )
})
