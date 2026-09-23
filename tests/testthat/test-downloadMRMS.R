test_that("downloadMRMS downloads and unzips available files", {
  skip_on_cran()
  skip_if_offline()

  # Destination doesn't exist yet; downloadMRMS should create it
  dest <- file.path(withr::local_tempdir(), "new_dir")

  missing <- downloadMRMS(
    start = lubridate::ymd_hm("2025-01-01 02:00"),
    end = lubridate::ymd_hm("2025-01-01 03:00"),
    destination = dest,
    product = "RadarOnlyQPE"
  )

  expect_length(missing, 0)

  files <- list.files(dest, pattern = "\\.grib2$")
  expect_length(files, 2)
})

test_that("downloadMRMS records missing dates for unavailable data", {
  skip_on_cran()
  skip_if_offline()

  dest <- withr::local_tempdir()

  missing <- downloadMRMS(
    start = lubridate::ymd_hm("2099-01-01 00:00"),
    end = lubridate::ymd_hm("2099-01-01 00:02"),
    destination = dest,
    product = "SurfacePrecipRate"
  )

  expect_length(missing, 2)
  expect_s3_class(missing[[1]], "POSIXct")
  expect_length(list.files(dest), 0)
})

test_that("downloadMRMS rejects unknown products with the valid options", {
  expect_error(
    downloadMRMS(
      start = lubridate::ymd_hm("2025-01-01 02:00"),
      end = lubridate::ymd_hm("2025-01-01 03:00"),
      destination = withr::local_tempdir(),
      product = "radaronlyqpe"
    ),
    "RadarOnlyQPE"
  )
})
