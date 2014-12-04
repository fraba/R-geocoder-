#!/usr/bin/Rscript

# Required libraries
require(ggmap)
require(DBI)
require(RSQLite)

# Define variables
db = "~/Desktop/tmp_geocoordinates.sqlite"

# Define a character vector you want to geolocate
location_chars <- c("Chagcharan","Kabul","Sydney NSW","Moore's Law")
# Sanitize SQL
location_chars <- gsub("'","''",location_chars)

# Functions
# Geocode a string with Google Maps
# IMPORTANT: Send only one location per request
geocodeString <- function (location) {
  require(ggmap)
  coordinates <- tryCatch(
    geocode(location, output = "latlon"),
    error=function(cond) {
      message("Error connecting with the API")
      message("Here's the original error message:")
      message(cond)
      # Choose a return value in case of error
      return("API error")}
  )
  return(cbind(location, coordinates))
}

updateDb <- function(db, df, status) {
  now <- Sys.time()
  con <- dbConnect(RSQLite::SQLite(), dbname = db)
  query <- dbSendQuery(con, paste0(
    "UPDATE geo_coordinate SET lon = '",df[,"lon"],"', lat = '",df[,"lat"],"', status = ", status,", timestamp = '",now,"' WHERE location_char = '",df[,"location"],"';"
  ))
  dbClearResult(dbListResults(con)[[1]])
  dbDisconnect(con)
}

# Create database and populate (if doesn't exist)
if (file.exists(db)) {
  cat("Database already exists\n")
} else {
  cat("Creating database...\n")
  require(DBI)
  require(RSQLite)
  con <- dbConnect(RSQLite::SQLite(), dbname = db)
  dbSendQuery(con,
              "CREATE TABLE geo_coordinate
              (id INTEGER PRIMARY KEY AUTOINCREMENT,
              location_char TEXT UNIQUE,
              lat TEXT,
              lon TEXT,
              status INTEGER DEFAULT (0),
              timestamp DATETIME)")
  for(location_char in location_chars) {
    dbSendQuery(con,
                paste0("INSERT INTO geo_coordinate (location_char) VALUES ('", 
                       location_char,"')"))
  }
  dbClearResult(dbListResults(con)[[1]])
  dbDisconnect(con)
}

# Get locations from database
con <- dbConnect(RSQLite::SQLite(), dbname = db)
query <- dbSendQuery(con, "SELECT location_char FROM geo_coordinate WHERE status = 0")
result <- fetch(query, n = -1)
dbClearResult(query)
dbDisconnect(con)

# Cleanup results
locations_to_geolocate <- result$location_char
locations_to_geolocate <- locations_to_geolocate[!is.na(locations_to_geolocate)]
locations_to_geolocate <- locations_to_geolocate[locations_to_geolocate!=""]

# Enter loop
cat("Geocoding via Google Maps API...\n")
for (loc in locations_to_geolocate) {
  while (TRUE) {
    api_limit <- geocodeQueryCheck()
    # TEST
    # api_limit <- 3
    # api_limit <- api_limit - 1
    if (api_limit > 0) {
      # Geocode
      # cat(paste0(api_limit, " queries before reaching limit.\n"))
      cat("Geocoding...\n")
      api_result <- geocodeString(loc)
      cat("Storing data...\n")
      if (class(api_result)=="data.frame") {
        updateDb(db, api_result, status=1)
      } else {
        updateDb(db, data.frame(location=loc, lon="NULL", lat="NULL"), status=2)
      } 
      break
    } else {
      # Sleep 30 mins
      cat("We reached the API limit...\n")
      nowis <- Sys.time()
      cat(paste0("It is now ", format(nowis, "%H:%M"), ".\n"))
      cat(paste0("I'll try again at ", format(nowis + 1800, "%H:%M"), "...\n"))
      Sys.sleep(1800)
    }
  }
}
cat("Job completed. Have a nice day!\n")
