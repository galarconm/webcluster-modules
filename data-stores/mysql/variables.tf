variable "db_username" {
    description = "The username for the database"
    type = string
    sensitive = true
  
}

variable "db_password" {
    description = "The password for the database"
    type = string
    sensitive = true
  
}

variable "db_name" {
    description = "The name of the database to create"
    type = string
   
}

