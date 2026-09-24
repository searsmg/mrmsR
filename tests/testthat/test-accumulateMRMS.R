# Helper: build per-timestep data like combineCSV() returns
make_steps <- function(times, values, catchment = "a") {
  data.frame(
    catchment = catchment,
    datetime = as.POSIXct(times, tz = "UTC"),
    p_mmhr = values
  )
}

test_that("accumulateMRMS converts 2-minute rates to depths", {
  # 30 two-minute steps at 6 mm/hr, stamped 00:02 to 01:00 = one full hour
  times <- seq(as.POSIXct("2025-01-01 00:02", tz = "UTC"), by = "2 min", length.out = 30)
  data <- make_steps(times, 6)

  out <- accumulateMRMS(data, product = "SurfacePrecipRate", by = "hour")

  expect_equal(nrow(out), 1)
  expect_equal(out$period_start, as.POSIXct("2025-01-01 00:00", tz = "UTC"))
  expect_equal(out$depth_mm, 6)
  expect_equal(out$n_steps, 30L)
  expect_equal(out$expected_steps, 30L)
})

test_that("accumulateMRMS counts the 00:00 hourly value in the previous day", {
  data <- make_steps(
    c("2025-01-01 01:00", "2025-01-01 23:00", "2025-01-02 00:00", "2025-01-02 01:00"),
    c(1, 2, 3, 4)
  )

  out <- accumulateMRMS(data, product = "RadarOnlyQPE", by = "day")

  expect_equal(out$period_start, as.POSIXct(c("2025-01-01", "2025-01-02"), tz = "UTC"))
  expect_equal(out$depth_mm, c(6, 4))
  expect_equal(out$n_steps, c(3L, 1L))
  expect_equal(out$expected_steps, c(24L, 24L))
})

test_that("accumulateMRMS uses tz for day boundaries", {
  # 06:00 UTC on Jan 2 is 23:00 on Jan 1 in Denver (UTC-7)
  data <- make_steps(c("2025-01-02 06:00", "2025-01-02 08:00"), c(1, 2))

  out <- accumulateMRMS(data, product = "RadarOnlyQPE", by = "day", tz = "America/Denver")

  expect_equal(
    out$period_start,
    as.POSIXct(c("2025-01-01", "2025-01-02"), tz = "America/Denver")
  )
  expect_equal(out$depth_mm, c(1, 2))
})

test_that("accumulateMRMS expects 23 steps on a spring-forward day", {
  data <- make_steps("2025-03-09 12:00", 1)

  out <- accumulateMRMS(data, product = "RadarOnlyQPE", by = "day", tz = "America/Denver")

  expect_equal(out$expected_steps, 23L)
})

test_that("accumulateMRMS totals each catchment and skips NA values", {
  data <- rbind(
    make_steps(c("2025-01-01 01:00", "2025-01-01 02:00", "2025-01-01 03:00"), c(1, NA, 2), "a"),
    make_steps(c("2025-01-01 01:00", "2025-01-01 02:00"), c(5, 5), "b")
  )

  out <- accumulateMRMS(data, product = "MultiSensorQPE", by = "total")

  expect_equal(out$catchment, c("a", "b"))
  expect_equal(out$depth_mm, c(3, 10))
  expect_equal(out$n_steps, c(2L, 2L))
  expect_equal(out$period_start, as.POSIXct(c("2025-01-01 00:00", "2025-01-01 00:00"), tz = "UTC"))
  expect_true(all(is.na(out$expected_steps)))
})

test_that("accumulateMRMS works on combineCSV output", {
  csv_dir <- withr::local_tempdir()
  file.copy(list.files(test_path(), pattern = "^extract_.*\\.csv$", full.names = TRUE), csv_dir)
  combined <- combineCSV(csv_dir)

  out <- accumulateMRMS(combined, product = "RadarOnlyQPE", by = "total")

  expect_equal(nrow(out), length(unique(combined$catchment)))
  expect_equal(sum(out$depth_mm), sum(combined$p_mmhr, na.rm = TRUE))
})

test_that("accumulateMRMS rejects non-precipitation products and bad input", {
  data <- make_steps("2025-01-01 01:00", 1)

  expect_error(accumulateMRMS(data, product = "RQI"), "isn't precipitation")
  expect_error(accumulateMRMS(data, product = "nope"), "SurfacePrecipRate")
  expect_error(accumulateMRMS(data[, -3], product = "RadarOnlyQPE"), "missing column")

  data$datetime <- as.character(data$datetime)
  expect_error(accumulateMRMS(data, product = "RadarOnlyQPE"), "must be POSIXct")
})
