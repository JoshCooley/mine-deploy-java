provider "aws" {
  region = "us-east-2"
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_security_group" "ssh" {
  name = "ssh"
}

resource "aws_iam_policy" "minecraft" {
  name        = "minecraft"
  description = "Used by minecraft servers to download configuration and plugins"

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "s3:ListBucket"
          ],
          "Effect": "Allow",
          "Resource": "${aws_s3_bucket.minecraft.arn}"
        },
        {
          "Action": [
            "s3:*"
          ],
          "Effect": "Allow",
          "Resource": "${aws_s3_bucket.minecraft.arn}/*"
        }
      ]
    }
  EOF
}

resource "aws_iam_role" "minecraft" {
  name               = "minecraft"
  assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                   "Service": "ec2.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "minecraft" {
  role       = aws_iam_role.minecraft.name
  policy_arn = aws_iam_policy.minecraft.arn
}

resource "aws_iam_instance_profile" "minecraft" {
  name = "minecraft"
  role = aws_iam_role.minecraft.name
}

resource "aws_instance" "minecraft" {
  ami                  = data.aws_ami.amazon-linux-2.id
  depends_on           = [aws_s3_bucket.minecraft]
  iam_instance_profile = aws_iam_instance_profile.minecraft.name
  instance_type        = "m5.large"
  key_name             = "josh.cooley"
  tags = {
    Name = "minecraft"
  }
  user_data              = file("setup_spigot.sh")
  vpc_security_group_ids = [data.aws_security_group.ssh.id]
}

resource "aws_s3_bucket" "minecraft" {
  bucket = "minecraft.cooley.tech"
  acl    = "private"
}

locals {
  minecraft_scripts_and_configs = [
    "server.properties",
    "setup_spigot.sh",
    "start_spigot.sh",
    "stop_spigot.sh",
  ]
}

resource "aws_s3_bucket_object" "minecraft_scripts_and_configs" {
  count  = length(local.minecraft_scripts_and_configs)
  bucket = aws_s3_bucket.minecraft.id
  key    = local.minecraft_scripts_and_configs[count.index]
  source = local.minecraft_scripts_and_configs[count.index]
  etag   = filemd5(local.minecraft_scripts_and_configs[count.index])
}

output "instance_info" {
  value = <<-eulav


    Instance ID:
    ${aws_instance.minecraft.id}
 
    SSH Command:
    ssh ec2-user@${aws_instance.minecraft.public_ip}


  eulav
}