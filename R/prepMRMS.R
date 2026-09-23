#' Project and clip MRMS GRIB2 files using terra and furrr
#'
#' Reads MRMS GRIB2 files, assigns a coordinate reference system (CRS),
#' crops them to a specified boundary, and writes the results as tif files.
#' Processing is performed in parallel using furrr.
#'
#' @param dir Character. Directory containing MRMS `.grib2` files.
#' @param output_dir Character. Directory where processed `.tif` files will be saved.
#' @param num_cores Integer. Number of cores to use for parallel processing.
#' @param boundary Character. File path to the boundary (e.g., a shapefile)
#'   defining the spatial extent to crop to. A path is required because
#'   `SpatVector` objects can't be sent to parallel workers.
#'
#' @return Invisibly returns `NULL`. Writes processed raster files to `output_dir`.
#'
#' @details
#' Uses the `terra` package for raster processing and `furrr` for parallel execution.
#' The CRS is WGS84 (EPSG:4326).
#'
#' @examples
#' \dontrun{
#' prepMRMS(
#'   dir = "path/to/grib2_files",
#'   output_dir = "path/to/output",
#'   num_cores = 4,
#'   boundary = "path/to/boundary.shp"
#' )
#' }
#'
#' @export
#'

prepMRMS <- function(dir, output_dir, num_cores, boundary) {

  # Input check
  if (!is.character(boundary)) {
    stop("boundary must be a file path when using parallel processing")
  }

  # Create output dir if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # List GRIB2 files, skipping any already processed
  files <- base::list.files(dir, pattern = "\\.grib2$", full.names = TRUE)

  already_done <- base::list.files(output_dir, pattern = "_processed\\.tif$", full.names = FALSE)
  already_done_base <- sub("_processed\\.tif$", ".grib2", already_done)
  files <- files[!(base::basename(files) %in% already_done_base)]

  if (length(files) == 0) {
    message("All files already processed.")
    return(invisible(NULL))
  }

  message(sprintf("%d files to process.", length(files)))

  # Set parallel plan, restoring the caller's plan on exit
  old_plan <- future::plan(future::multisession, workers = num_cores)
  on.exit(future::plan(old_plan), add = TRUE)

  # Function to process each file
  process_file <- function(file, boundary_path, output_dir) {

    r <- terra::rast(file)

    # set crs
    terra::crs(r) <- "EPSG:4326"

    b <- terra::vect(boundary_path)

    # Align CRS
    if (!terra::same.crs(r, b)) {
      b <- terra::project(b, terra::crs(r))
    }

    # Crop + mask (more robust than crop alone)
    r <- terra::crop(r, b)
    r <- terra::mask(r, b)

    # Output filename
    new_file <- base::file.path(
      output_dir,
      paste0(tools::file_path_sans_ext(base::basename(file)), "_processed.tif")
    )

    # Write
    terra::writeRaster(r, new_file, overwrite = TRUE)

    invisible(NULL)
  }

  # Run in parallel
  furrr::future_map(
    files,
    process_file,
    boundary_path = boundary,
    output_dir = output_dir,
    .options = furrr::furrr_options(seed = TRUE)
  )

  message("Processing complete!")

  invisible(NULL)
}
