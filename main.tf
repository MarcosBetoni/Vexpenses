provider "aws" {
  region = "us-east-1"
}

# Variável que define o nome do projeto
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

# Variável que define o nome do candidato
variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

# Geração de chave privada usando algoritmo RSA de 2048 bits
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Criação do par de chaves na AWS, usando a chave pública gerada
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Criação de uma VPC (Virtual Private Cloud)
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# Criação de uma subnet dentro da VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Criação de um gateway de internet para acesso externo
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

# Criação de uma tabela de rotas que direciona o tráfego para o gateway de internet
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

# Associação da tabela de rotas à subnet
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

# Grupo de segurança (firewall) que define as regras de acesso
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Security Group para a instância EC2"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir acesso SSH (porta 22) apenas a partir de um IP específico
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # Substitua YOUR_IP pelo seu endereço IP
  }

  # Permitir acesso HTTP (porta 80) de qualquer endereço IP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir HTTP de qualquer IP
  }

  # Permitir todo o tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

# Criação da instância EC2
resource "aws_instance" "main_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name
  subnet_id     = aws_subnet.main_subnet.id
  security_groups = [aws_security_group.main_sg.name]

  # Script para instalar e iniciar o servidor Nginx automaticamente
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1.12 -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
