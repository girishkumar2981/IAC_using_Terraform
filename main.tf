
resource "aws_vpc" "vpc_default" {
  cidr_block = var.cidr
}
resource "aws_subnet" "aws_subnet_default_1" {
  vpc_id                  = aws_vpc.vpc_default.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true

}
resource "aws_subnet" "aws_subnet_default_2" {
  vpc_id                  = aws_vpc.vpc_default.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = "us-west-1b"
  map_public_ip_on_launch = true

}
resource "aws_internet_gateway" "aws_ig_default" {
  vpc_id = aws_vpc.vpc_default.id
}
resource "aws_route_table" "aws_route_table_default" {
  vpc_id = aws_vpc.vpc_default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_ig_default.id
  }
}
resource "aws_route_table_association" "aws_assoc_default" {
  subnet_id      = aws_subnet.aws_subnet_default_1.id
  route_table_id = aws_route_table.aws_route_table_default.id
}
resource "aws_route_table_association" "aws_assoc_default2" {
  subnet_id      = aws_subnet.aws_subnet_default_2.id
  route_table_id = aws_route_table.aws_route_table_default.id
}

resource "aws_default_security_group" "default_sg" {
  vpc_id = aws_vpc.vpc_default.id

  ingress {
    description = "HTTP Request"
    protocol    = "TCP"
    self        = true
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    protocol    = "TCP"
    self        = true
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_s3_bucket" "example" {
  bucket = "girishkumarpillarisetty1999"
}
resource "aws_instance" "aws_ec2_default1" {
  ami                    = "ami-0a0409af1cb831414"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.aws_subnet_default_1.id
  vpc_security_group_ids = [aws_default_security_group.default_sg.id]
  user_data              = base64encode(file("userdata.sh"))
  iam_instance_profile   = aws_iam_instance_profile.iam_profile.name
}
resource "aws_instance" "aws_ec2_default2" {
  ami                    = "ami-0a0409af1cb831414"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.aws_subnet_default_2.id
  vpc_security_group_ids = [aws_default_security_group.default_sg.id]
  user_data              = base64encode(file("userdata1.sh"))
  iam_instance_profile   = aws_iam_instance_profile.iam_profile.name
}
resource "aws_lb" "alb_default" {
  name               = "loudbalanceraws"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_default_security_group.default_sg.id]
  subnets            = [aws_subnet.aws_subnet_default_1.id, aws_subnet.aws_subnet_default_2.id]
}
resource "aws_lb_target_group" "tg_default1" {
  name     = "tf-alb-default"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_default.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "tg_default_attach_1" {
  target_group_arn = aws_lb_target_group.tg_default1.arn
  target_id        = aws_instance.aws_ec2_default1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "tg_default_attach_2" {
  target_group_arn = aws_lb_target_group.tg_default1.arn
  target_id        = aws_instance.aws_ec2_default2.id
  port             = 80
}
resource "aws_lb_listener" "lb_list_default" {
  load_balancer_arn = aws_lb.alb_default.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_default1.arn
  }
}
resource "aws_iam_role_policy" "s3_IAM_policy" {
  name = "s3_IAM_policy"
  role = aws_iam_role.test_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
          "s3-object-lambda:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject", "s3:PutObject"],
        "Resource": "arn:aws:s3:::mybucket/path/to/my/key"
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/mytable"
      }
    ]
  })
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile"
  role = aws_iam_role.test_role.name
}
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
terraform{
backend "s3" {
     bucket         = "girishkumarpillarisetty1999"
     key            = "Remote_Backend/terraform.tfstate"
     region         = "us-west-1"
     encrypt        = true
     dynamodb_table = "terraform-state-lock"
  }
}

