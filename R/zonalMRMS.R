#' Extract zonal mean using boundary from MRMS rasters
#'
#' Computes zonal mean precipitation for each raster file over the boundary
#' and writes results as CSV files.
#'
#' @param raster_dir Directory containing processed `.tif` files.
#' @param output_dir Directory to write CSV outputs.
#' @param boundary Path to boundary SpatVector object.
#' @param n_workers Number of parallel workers.
#'
#' @return Invisibly returns NULL
#' @export

zonalMRMS <- function(raster_dir,
                                output_dir,
                                boundary,
                                n_workers = 6) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)

  # Boundary prep
  if (is.character(boundary)) {
    boundary <- terra::vect(boundary)
  } else {
    boundary <- terra::vect(boundary)
  }

  boundary <- terra::project(boundary, "EPSG:4326")

  # Parallel processing for zonal
  future::plan(future::multisession, workers = n_workers)
  on.exit(future::plan(future::sequential), add = TRUE)

  furrr::future_walk(files, function(file) {

    r <- terra::rast(file)
    names(r) <- "p_mmhr"

    extract <- terra::zonal(
      r,
      boundary,
      fun = "mean",
      touches = TRUE,
      na.rm = TRUE
    )

    extract$catchment <- boundary$site

    # safer timestamp parsing
    timestamp <- tools::file_path_sans_ext(basename(file))

    extract$datetime <- lubridate::ymd_hms(timestamp)
    extract$doy <- lubridate::yday(extract$datetime)
    extract$hour <- lubridate::hour(extract$datetime)
    extract$min <- lubridate::minute(extract$datetime)

    out_file <- file.path(
      output_dir,
      paste0("extract_", extract$doy[1], "_", extract$hour[1], "_", extract$min[1], ".csv")
    )

    utils::write.csv(extract, out_file, row.names = FALSE)

  })

  message("Zonal stats complete")
  invisible(NULL)
}
