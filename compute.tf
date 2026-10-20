# Obtener Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Llave SSH
resource "aws_key_pair" "deployer" {
  key_name   = "react-nest-key"
  public_key = file(var.ssh_public_key_path)
}

# -----------------------------------------------------
# INSTANCIA BACKEND (NestJS + PostgreSQL)
# -----------------------------------------------------
resource "aws_instance" "backend_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs git postgresql postgresql-contrib
    sudo npm install -g pm2

    # Configurar PostgreSQL
    sudo -u postgres psql -c "CREATE USER nestuser WITH PASSWORD 'nestpass123';"
    sudo -u postgres psql -c "CREATE DATABASE modulo2 OWNER nestuser;"

    # Clonar repo
    git clone https://github.com/Jorgito-cc/control-asistencia-academica.git /home/ubuntu/app
    cd /home/ubuntu/app/server
    
    # Crear archivo .env exacto para el Backend
    cat <<EOT > .env
    PORT=3000
    CORS_ORIGIN=*
    DB_HOST=localhost
    DB_PORT=5432
    DB_USER=nestuser
    DB_PASSWORD=nestpass123
    DB_NAME=modulo2
    JWT_SECRET=pon-un-secreto-largo
    JWT_EXPIRES_IN=8h
    APP_TZ=America/La_Paz
    ADMIN_EMAIL=admin@gmail.com
    ADMIN_PASSWORD=123456789
    ADMIN_NAME=Administrador
    EOT

    # Instalar y arrancar
    npm install
    npm run build
    pm2 start dist/main.js --name "backend-api"
    pm2 save
    sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root
  EOF

  tags = {
    Name = "Backend-NestJS-DB"
  }
}

# -----------------------------------------------------
# INSTANCIA FRONTEND (React + Nginx Proxy)
# -----------------------------------------------------
resource "aws_instance" "frontend_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs git nginx

    # Clonar y construir el frontend
    git clone https://github.com/Jorgito-cc/control-asistencia-academica.git /home/ubuntu/app
    cd /home/ubuntu/app/client
    npm install
    npm run build

    # Limpiar y copiar archivos estáticos al directorio de Nginx
    sudo rm -rf /var/www/html/*
    sudo cp -r dist/* /var/www/html/

    # Crear configuración de Nginx con Proxy Inverso para /api y WebSockets
    cat <<EOT > /etc/nginx/sites-available/default
    server {
        listen 80 default_server;
        server_name _;
        root /var/www/html;
        index index.html;

        location / {
            try_files \$uri \$uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://${aws_instance.backend_server.public_ip}:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
    EOT

    # Reiniciar Nginx para aplicar cambios
    sudo systemctl restart nginx
  EOF

  tags = {
    Name = "Frontend-React"
  }
}