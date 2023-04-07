resource "aws_ecr_repository" "beprayed-app-react" {
  name                 = "beprayed-app-react"
  image_tag_mutability = "MUTABLE"
  tags                 = {
    Name        = "beprayed-app-react"
    Environment = "staging"
  }
}