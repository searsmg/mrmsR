
# mrmsR

Tools for processing NOAA MRMS (Multi-Radar Multi-Sensor) gridded precipitation data and generating watershed-scale rainfall statistics.

---

## Overview

`mrmsR` provides functions to:

- Read and process MRMS GRIB2 precipitation data
- Project and clip rasters to watershed boundaries
- Compute watershed-scale rainfall statistics using zonal methods
- Export processed raster and tabular outputs
- Combine multi-file outputs into a single time series dataset

The package is designed for high-volume hydroclimatic workflows and supports efficient batch and parallel processing.

---

## Installation

Install the development version from GitHub:

```r
devtools::install_github("yourusername/mrmsR")
