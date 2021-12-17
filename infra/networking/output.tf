output "vpc_id" {
  description = "Fetch VPC ID "
  value       = concat(aws_vpc.dm_vpc_res.*.id, [""])[0]
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.dm_priv_res.*.id
}

output "public_subnets" {
  value = aws_subnet.dm_pub_res.*.id
}
