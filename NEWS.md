# mrmsR (development version)

## New features

* New `accumulateMRMS()` converts per-timestep values to rainfall depths and
  totals them by hour, day, or the whole record. It converts
  `SurfacePrecipRate` rates (mm/hr) to depths, assigns each value to the
  interval ending at its timestamp, supports local-time days via `tz`, and
  reports `n_steps` vs. `expected_steps` to flag gaps.
* `zonalMRMS()` gains `fun` to compute the `"max"`, `"min"`, `"median"`, or
  `"sum"` over each catchment instead of the mean.

# mrmsR 0.1.0

First release. `mrmsR` provides a four-step workflow for turning MRMS
gridded precipitation data into catchment-scale time series:
`downloadMRMS()`, `prepMRMS()`, `zonalMRMS()`, and `combineCSV()`.

## Breaking changes

* `zonalMRMS()` CSV files are now named `extract_<year>_<doy>_<hour>_<min>.csv`
  (previously `extract_<doy>_<hour>_<min>.csv`) and include a `year` column.
  The old names let the same day and time in different years overwrite each
  other.

## New features

* `zonalMRMS()` gains `id_col` to choose which boundary column labels each
  catchment. It still defaults to `site` when present.
* `downloadMRMS()` creates `destination` if it doesn't exist.

## Bug fixes

* `zonalMRMS()` now works with `n_workers > 1`. It previously failed with
  "external pointer is not valid".
* `downloadMRMS()` converts `start` and `end` to UTC before building URLs.
  Non-UTC times previously downloaded the wrong timesteps without warning.
* `zonalMRMS()` writes the full timestamp for midnight rasters, and
  `combineCSV()` reads date-only timestamps as midnight UTC regardless of
  file name.
* `downloadMRMS()` gives a clear error for an unknown `product` or
  non-POSIXct `start`/`end`.
* `prepMRMS()` and `zonalMRMS()` restore the caller's `future::plan()` on exit
  instead of resetting it to sequential.
