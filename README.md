# Desafio - Estágio em DevOps - VExpenses

## Descrição Técnica

### Análise do Código Original
O código original, contido no arquivo `main.tf`, define uma infraestrutura básica na AWS, com os seguintes recursos:

1. **Provider AWS**: Configura o provedor para a região `us-east-1`.
   
2. **Variáveis de Entrada**:
   - `projeto`: Define o nome do projeto (por padrão, "VExpenses").
   - `candidato`: Define o nome do candidato (por padrão, "SeuNome").

3. **Recursos Criados**:
   - **Chave SSH (RSA)**: Um par de chaves é criado usando um algoritmo RSA de 2048 bits, armazenando a chave pública na AWS como um Key Pair, que é posteriormente associado à instância EC2.
   - **VPC**: Cria uma Virtual Private Cloud com o bloco CIDR `10.0.0.0/16` e habilita suporte a DNS.
   - **Subnet**: Define uma subnet dentro da VPC com o bloco CIDR `10.0.1.0/24`.
   - **Internet Gateway**: Cria um Gateway para permitir o acesso externo à VPC.
   - **Route Table**: Configura uma tabela de roteamento para permitir que o tráfego de saída passe pelo Internet Gateway.
   - **Associação de Route Table**: Associa a tabela de roteamento à subnet criada.

### (Interpreta-se que o código deve ser inserido também no README) Código modificado
#  
   
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

#

### Melhorias e Modificações Realizadas

#### 1. **Melhoria de Segurança**
   - Um **Security Group** foi criado para permitir apenas:
     - Acesso SSH na porta 22, restrito a um endereço IP específico (deve ser ajustado no arquivo com o seu próprio IP).
     - Acesso HTTP na porta 80 de qualquer IP, para acesso ao servidor Nginx que será instalado.
   - Essa alteração está de acordo com boas práticas de segurança, restringindo o acesso SSH e mantendo o HTTP aberto para tráfego web, de acordo também, com a documentação https://developer.hashicorp.com/well-architected-framework/security/security-sensitive-data

#### 2. **Automação do Nginx**
   - A instância EC2 foi configurada para automaticamente instalar e iniciar o Nginx assim que for criada. O script `user_data` usa comandos bash para instalar e habilitar o Nginx no Amazon Linux 2:
     ```bash
     #!/bin/bash
     yum update -y
     amazon-linux-extras install nginx1.12 -y
     systemctl start nginx
     systemctl enable nginx
     ```

#### 3. **Outras Melhorias**
   - O código foi mantido modular e adaptável, permitindo ajustes como a personalização do IP para SSH e melhorias na organização dos recursos. Tags foram incluídas em todos os recursos para facilitar a identificação.
   - Foi indicado um erro na função tag, já que na parte a qual foi aplicada, não suportava a aplicação tag, portanto, optei por remover a função, já que ela não comprometeria o código em si, apenas serviria para uma identificação mais prática no console AWS

## Instruções de Uso

### Pré-requisitos:
- Terraform instalado: [Guia de Instalação do Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- Credenciais da AWS configuradas. Se necessário, configure suas credenciais da AWS usando:
  ```bash
  aws configure
