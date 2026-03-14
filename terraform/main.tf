# 1. Automatically find the latest Ubuntu 22.04 AMI in Singapore
# This replaces the hardcoded "ami-0c55..." which only works in Ohio
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's Official ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Add your Arch Linux SSH key to AWS
# This allows you to 'ssh ubuntu@ip' later. 
# Make sure the path matches your actual public key (~/.ssh/id_rsa.pub or id_ed25519.pub)
resource "aws_key_pair" "sentinel_key" {
  key_name   = "sentinel-key"
  public_key = file("~/.ssh/id_ed25519.pub") 
}

# 3. Create the VPC
resource "aws_vpc" "sentinel_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "Sentinel-VPC"
  }
}

# 4. Create an Internet Gateway
resource "aws_internet_gateway" "sentinel_igw" {
  vpc_id = aws_vpc.sentinel_vpc.id
  tags = {
    Name = "Sentinel-IGW"
  }
}

# 5. Create a Public Subnet
resource "aws_subnet" "sentinel_public_subnet" {
  vpc_id                  = aws_vpc.sentinel_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"
  tags = {
    Name = "Sentinel-Public-Subnet"
  }
}

# 6. Create a Route Table (So the Subnet can talk to the Internet)
resource "aws_route_table" "sentinel_rt" {
  vpc_id = aws_vpc.sentinel_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sentinel_igw.id
  }

  tags = {
    Name = "Sentinel-Route-Table"
  }
}

# Associate the Route Table with our Subnet
resource "aws_route_table_association" "sentinel_rta" {
  subnet_id      = aws_subnet.sentinel_public_subnet.id
  route_table_id = aws_route_table.sentinel_rt.id
}

# 7. Create a Security Group (The Firewall)
resource "aws_security_group" "sentinel_sg" {
  name        = "sentinel-security-group"
  description = "Allow SSH and Web Traffic"
  vpc_id      = aws_vpc.sentinel_vpc.id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # App Access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana Access
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus Access
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Outbound access (Required to pull Docker images)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Sentinel-Firewall"
  }
}

# 8. Define the EC2 Instance
resource "aws_instance" "sentinel_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.sentinel_key.key_name # Attach your SSH key

  subnet_id                   = aws_subnet.sentinel_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.sentinel_sg.id]
  associate_public_ip_address = true

  # Automation: Install Docker on boot
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              # Give ubuntu user permissions to use docker without sudo
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "Sentinel-App-Server"
  }
}