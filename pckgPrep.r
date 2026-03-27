library(devtools)

#use_mit_license()

# creates function file
#use_r('combineCSV')

# use this anytime a function is updated
document()

# pretend install
load_all()

# test environment
devtools::check()

usethis::use_package('lubridate')
usethis::use_package("httr")
usethis::use_package("R.utils")
usethis::use_package("terra")
usethis::use_package("furrr")
usethis::use_package("future")
usethis::use_package("data.table")
usethis::use_package("dplyr")
usethis::use_package("utils")


# rename files if we want to rename the R functions
# rename_files("strsplit1", "str_split_one")

# install the package and use it like any other package
#install()

##########################################
