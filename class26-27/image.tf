# dockwr build the migartion code image 

locals {
  repository = aws_ecr_repository.rds_migration.repository_url
  tag        = "latest"
}

resource "null_resource" "ecr_image" {
  depends_on = [
    aws_ecr_repository.rds_migration
  ]

  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }
    command = <<Settings
            cd ${path.module}/image/
            ../awsdocker.sh '${local.repository}' '${data.aws_ecr_authorization_token.token.password}' '${local.tag}'
            Settings
  }
}


# aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 879381241087.dkr.ecr.ap-south-1.amazonaws.com