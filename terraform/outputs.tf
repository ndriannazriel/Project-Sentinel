# Output the VPC ID so we can verify it was created
output "vpc_id" {
  description = "The ID of the Sentinel VPC"
  value       = aws_vpc.sentinel_vpc.id
}

# Output the Public IP of the subnet (useful for later)
output "public_subnet_id" {
  value = aws_subnet.sentinel_public_subnet.id
}

output "instance_public_ip" {
  description = "Public IP of the Sentinel Server"
  value       = aws_instance.sentinel_server.public_ip
}