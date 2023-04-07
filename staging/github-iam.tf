resource "aws_iam_role" "github-actions-role" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github-actions-ecr-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role = aws_iam_role.github-actions-role.name
}

resource "aws_iam_role_policy_attachment" "github-actions-ecs-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  role = aws_iam_role.github-actions-role.name
}