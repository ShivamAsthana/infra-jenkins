#Create a new custom vpc 
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true 
  enable_dns_hostnames =true

  tags = {
    Name = "main_vpc"
  }
}

# create an internet gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "vpc_igw"
  }
}
# Create 2 public and 2 private subnets
# create public subnet one
resource "aws_subnet" "eks_pub_sub_one" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true 

  tags = {
    Name = "pub subnet one"
  }
}
# Create public subnet 2
resource "aws_subnet" "eks_pub_sub_two" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true 

  tags = {
    Name = "pub subnet two"
  }
}
# create 1st private subnet
resource "aws_subnet" "eks_priv_sub_one" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private subnet one"
  }
}
# create private subnet 2
resource "aws_subnet" "eks_priv_sub_two" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "priavte subnet two"
  }
}

# create an EIP for the NAT gateway
resource "aws_eip" "nat_eip" {
  vpc = true
}

# create a NAT gateway
resource "aws_nat_gateway" "eks_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.eks_pub_sub_one.id

  tags = {
    Name = "Nat gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.eks_igw]
}
# create a route table for the public subnet
resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "Public subnet route table"
  }
}
# create a route table for the private subnet
resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "Private subnet route table"
  }
}
# create a route table to the NAT gateway for the private subnet
resource "aws_route" "private_subnet_nat_gateway_route" {
  route_table_id            = aws_route_table.private_subnet_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.eks_nat_gw.id
}
# create a route to the internete gateway for the public subnet
resource "aws_route" "public_subnet_internet_gateway_route" {
  route_table_id            = aws_route_table.public_subnet_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                 = aws_internet_gateway.eks_igw.id
}
# Assocaite the 1st pubilc subnet  with the public subnet route table
resource "aws_route_table_association" "public_subnet_route_table_association" {
  subnet_id      = aws_subnet.eks_pub_sub_one.id
  route_table_id = aws_route_table.public_subnet_route_table.id
}
# Assocaite the 2nd public subnet with the public subnet route table
resource "aws_route_table_association" "public_subnet_route_table_association_2" {
  subnet_id      = aws_subnet.eks_pub_sub_two.id
  route_table_id = aws_route_table.public_subnet_route_table.id
}
#  Assocaite the 1st private subnet  with the private subnet route table
 resource "aws_route_table_association" "private_subnet_route_table_association" {
  subnet_id      = aws_subnet.eks_priv_sub_one.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}
# Assocaite the 2nd private subnet with the private subnet route table
 resource "aws_route_table_association" "private_subnet_route_table_association_2" {
  subnet_id      = aws_subnet.eks_priv_sub_two.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}
# create an IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

}
# Attach the neccessary eks_cluster policy to the IAM role.
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
# create an EKS cluster
resource "aws_eks_cluster" "abdu_cluster" {
  name     = "eks_cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = "1.26"

  vpc_config {
    subnet_ids = [aws_subnet.eks_priv_sub_one.id, aws_subnet.eks_priv_sub_two.id, aws_subnet.eks_pub_sub_one.id, aws_subnet.eks_pub_sub_two.id ]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role_attachment
  ]
}
# create an IAM role for the worker-nodes
resource "aws_iam_role" "eks_worker_node_role" {
  name = "eks_worker_node_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}
# Attach the necessary policies to IAM role

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_CNI_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_EC2CR_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_node_role.name
}
# create the EKS node group
resource "aws_eks_node_group" "eks_node" {
  cluster_name    = aws_eks_cluster.abdu_cluster.name
  node_group_name = "eks_node"
  node_role_arn   = aws_iam_role.eks_worker_node_role.arn

  # subnet configuration
  subnet_ids  = [aws_subnet.eks_priv_sub_one.id, aws_subnet.eks_priv_sub_two.id]


  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
  
  # use the latest EKS-optimize Amazon linux 2 AMI
  ami_type = "AL2_x86_64"

  # Use the latest version of the EKS-optimized AMI
  # Release version = "latest"
  # Configure the node group instances
  instance_types = ["t3.small", "t3.medium", "t3.large"]

  # use the managed node group capacity provider
  capacity_type = "ON_DEMAND"

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_attachment,
    aws_iam_role_policy_attachment.eks_CNI_policy_attachment,
    aws_iam_role_policy_attachment.eks_EC2CR_policy_attachment,
  ]
}

# specify the tags for the nodes group
/* tags = {
    Terraform = "true"
    Environment = "prod"
      }
} */