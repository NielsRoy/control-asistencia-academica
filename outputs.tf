output "frontend_url" {
  value       = "http://${aws_instance.frontend_server.public_ip}"
  description = "Entra a esta URL en tu navegador para ver la App de React"
}

output "backend_api_url" {
  value       = "http://${aws_instance.backend_server.public_ip}:3000"
  description = "URL base de la API de NestJS"
}