provider "aws" {
  region = "us-east-1"
}


# 1. Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}
# 3. Create Custom Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"                    # Route traffic to this CIDR block (internet)
    gateway_id = aws_internet_gateway.my_igw.id # Route traffic through the internet gateway
  }
  tags = {
    Name = "Route-table"
  }
}
# 4. Create a Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
# 5. Associate subnet with Route Table
resource "aws_route_table_association" "my_subnet_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}
# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "my-security-group"
  description = "Security group to allow SSH, HTTP, and HTTPS traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH traffic from anywhere
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP traffic from anywhere
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web_server_itfe" {
  subnet_id       = aws_subnet.my_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "my_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_itfe.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.my_igw]
}

# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami               = "ami-080e1f13689e07408"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "docker-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_itfe.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo bash -c 'echo your first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }
}