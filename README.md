# R script to geocode character strings via maps.googleapis.com

The script takes as input a character vector and passes each to the Google Maps API using the `ggmap` library managing API errors and limits (2500 queries per day).

 The script stores input and output data into a relational database (SQLite). When it reboots it will check if a database already exists and if finds one will continue last execution. 
