variable "aws_region" {
  default     = "us-east-1"
  description = "Región de AWS"
}

variable "instance_type" {
  default     = "t3.micro"
  description = "Tamaño de la instancia EC2"
}

variable "ssh_public_key_path" {
  default     = "~/.ssh/aws_ec2_key.pub"
  description = "Ruta a la llave pública SSH en tu máquina local"
}