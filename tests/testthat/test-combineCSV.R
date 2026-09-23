test_that("combineCSV errors when the directory does not exist", {
  expect_error(combineCSV(withr::local_tempfile()), "does not exist")
})

test_that("combineCSV errors when the directory has no CSV files", {
  empty_dir <- withr::local_tempdir()
  expect_error(combineCSV(empty_dir), "No CSV files found")
})

test_that("combineCSV combines and sorts extraction CSVs by datetime", {
  csv_dir <- withr::local_tempdir()
  fixtures <- list.files(test_path(), pattern = "^extract_.*\\.csv$", full.names = TRUE)
  file.copy(fixtures, csv_dir)

  result <- combineCSV(csv_dir)

  expect_equal(nrow(result), 26 * length(fixtures))
  expect_true(all(c("catchment", "datetime", "p_mmhr") %in% names(result)))
  expect_true(!is.unsorted(result$datetime))
})

test_that("combineCSV reads old m/d/y date-only timestamps as midnight", {
  csv_dir <- withr::local_tempdir()
  writeLines(
    c('"ID","p_mmhr","catchment","datetime"', '1,0,"test","01/02/25"'),
    file.path(csv_dir, "extract_1_0_0.csv")
  )

  result <- combineCSV(csv_dir)

  expect_equal(result$datetime, as.POSIXct("2025-01-02 00:00:00", tz = "UTC"))
})

test_that("combineCSV reads date-only ISO timestamps as midnight", {
  csv_dir <- withr::local_tempdir()
  writeLines(
    c('"ID","p_mmhr","catchment","datetime"', '1,0,"test",2025-01-02'),
    file.path(csv_dir, "extract_2025_2_00_00.csv")
  )
  writeLines(
    c('"ID","p_mmhr","catchment","datetime"', '1,0,"test",2025-01-01 23:00:00'),
    file.path(csv_dir, "extract_2025_1_23_00.csv")
  )

  result <- combineCSV(csv_dir)

  expect_equal(
    result$datetime,
    as.POSIXct(c("2025-01-01 23:00:00", "2025-01-02 00:00:00"), tz = "UTC")
  )
})
