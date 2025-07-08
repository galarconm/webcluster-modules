resource "aws_db_instance" "mysql" {
    identifier = "terraform-up-and-running"
    engine = "mysql"
    engine_version = "8.0"
    allocated_storage = 10
    instance_class = "db.t3.micro"
    skip_final_snapshot = true
    db_name = "${var.db_name}_database"

    username = var.db_username
    password = var.db_password

  
}

