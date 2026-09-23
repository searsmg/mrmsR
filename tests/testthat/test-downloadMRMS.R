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

test_that("downloadMRMS converts non-UTC times to UTC file names", {
  skip_on_cran()
  skip_if_offline()

  dest <- withr::local_tempdir()

  # 19:00 in Denver (MST, UTC-7) is 02:00 UTC the next day
  missing <- downloadMRMS(
    start = lubridate::ymd_hm("2024-12-31 19:00", tz = "America/Denver"),
    end = lubridate::ymd_hm("2024-12-31 19:00", tz = "America/Denver"),
    destination = dest,
    product = "RadarOnlyQPE"
  )

  expect_length(missing, 0)
  expect_equal(list.files(dest), "RadarOnly_QPE_01H_00.00_20250101-020000.grib2")
})

test_that("downloadMRMS requires POSIXct start and end", {
  expect_error(
    downloadMRMS(
      start = "2025-01-01 02:00",
      end = lubridate::ymd_hm("2025-01-01 03:00"),
      destination = withr::local_tempdir(),
      product = "RadarOnlyQPE"
    ),
    "must be POSIXct"
  )
})
