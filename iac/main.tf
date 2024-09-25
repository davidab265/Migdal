//-----------------------------------------
// PROVIDERS
//----------------------------------------- 


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.27.0"
    }
  }
  // save the "tfstate" of this terraform file in a s3 bucket [created beforehand]
  backend "s3" {
    bucket = "david-friday-app1"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }

}


provider "aws" {
  region = var.aws_region
}


data "aws_availability_zones" "available" {}

//-----------------------------------------
// argocd
//----------------------------------------- 

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.friday.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.friday.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", "${var.cluster-name}"]
      command     = "aws"
    }
  }
}


resource "helm_release" "argocd" {
  name             = "argocd"
  create_namespace = true
  namespace        = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  values = [
    "${file("./values-argo.yaml")}"
  ]

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "configs.credentialTemplates.ssh-creds.sshPrivateKey"
    value = file(var.argocd_ssh_location)
    # "trimspace" func in order to remove spaces
  }
   set {
     name  = "configs.secret.argocdServerAdminPassword"
     value = bcrypt("12345678")
   }
  depends_on = [
    aws_eks_cluster.friday
  ]
}

//
//-----------------------------------------
// VPC
//----------------------------------------- 

// VPC Resources
//  [1] VPC
//  [2] Subnets
//  [3] Internet Gateway
//  [4] Route Table
//  [5] Route Table association

//  [1] VPC
resource "aws_vpc" "friday" {
  cidr_block = "10.0.0.0/16"

  tags = tomap({
    "Name"                                      = "${var.prefix}-node",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
    "owner"                                     = "David-Abrams",
    "purpose"                                   = "portfolio",
    "bootcamp"                                  = "14",
  })
}

//  [2] Subnets - 2 subnets
resource "aws_subnet" "friday" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.friday.id

  tags = tomap({
    "Name"                                      = "${var.prefix}-node",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
    "owner"                                     = "David Abrams",
    "purpose"                                   = "portfolio",
    "bootcamp"                                  = "14",

  })
}

//  [3] Internet Gateway
resource "aws_internet_gateway" "friday" {
  vpc_id = aws_vpc.friday.id

  tags = {
    Name = "${var.prefix}"
  }
}

//  [4] Route Table - routing the networking. connects the igw
resource "aws_route_table" "friday" {
  vpc_id = aws_vpc.friday.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.friday.id
  }

  tags = {
    Name = "${var.prefix}"
  }
}

//  [5] Route Table association - connects subnets to the route table
resource "aws_route_table_association" "friday" {
  count = 2

  subnet_id      = aws_subnet.friday.*.id[count.index]
  route_table_id = aws_route_table.friday.id
}

//-----------------------------------------
// EKS cluster & its iam role & its SG
//----------------------------------------- 


// EKS Cluster Resources
//  [6] IAM Role to allow EKS service to manage other AWS services
//  [7] EC2 Security Group to allow networking traffic with EKS cluster
//  [8] EKS Cluster



//  [6] IAM Role to allow EKS service to manage other AWS services

// create a new role
resource "aws_iam_role" "friday-cluster" {
  name = "terraform-eks-friday-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

// attach a policy to the role
resource "aws_iam_role_policy_attachment" "friday-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.friday-cluster.name
}

// attach another policy to the role
resource "aws_iam_role_policy_attachment" "friday-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.friday-cluster.name
}

//// instance profile. [not in use for now]
//resource "aws_iam_instance_profile" "friday-cluster" {
//  name = "terraform-friday-cluster"
//  role = aws_iam_role.friday-cluster.name
//}


//  [7] VPC Security Group to allow the networking of VPS with EKS cluster
resource "aws_security_group" "friday-cluster" {
  name        = "terraform-eks-friday-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.friday.id

  //ingress {
  //  description = "HTTP"
  //  from_port   = 80
  //  to_port     = 80
  //  protocol    = "TCP"
  //  cidr_blocks = [var.cidr_0]
  //}
  //
  //ingress {
  //  description = "SSH"
  //  from_port   = 22
  //  to_port     = 22
  //  protocol    = "TCP"
  //  cidr_blocks = [var.cidr_0]
  //}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_0]
  }

  tags = {
    Name = "${var.prefix}"
  }
}


//-----------------------------------------
// finely! the EKS clustes itself! 
//----------------------------------------- 

// [8] creates the cluster [with iam-role connects security-group and subnets]
resource "aws_eks_cluster" "friday" {
  name     = var.cluster-name
  role_arn = aws_iam_role.friday-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.friday-cluster.id]
    subnet_ids         = aws_subnet.friday[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.friday-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.friday-cluster-AmazonEKSVPCResourceController,
  ]
}

//-----------------------------------------
// EKS worker nodes [creates the worker nodes, and iam role]
//----------------------------------------- 

// EKS Worker Nodes Resources
//  * IAM role allowing Kubernetes actions to access other AWS services
//  * EKS Node Group to launch worker nodes
//

//  IAM role for the worker nods. allowing Kubernetes actions to access other AWS services
resource "aws_iam_role" "friday-node" {
  name = "terraform-eks-friday-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "friday-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.friday-node.name
}

resource "aws_iam_role_policy_attachment" "friday-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.friday-node.name
}

resource "aws_iam_role_policy_attachment" "friday-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.friday-node.name
}

resource "aws_iam_instance_profile" "friday-node" {
  name = "terraform-friday-node"
  role = aws_iam_role.friday-node.name
}

// EKS Node Group to launch worker nodes

resource "aws_eks_node_group" "friday" {
  cluster_name    = aws_eks_cluster.friday.name
  node_group_name = "friday"
  node_role_arn   = aws_iam_role.friday-node.arn
  subnet_ids      = aws_subnet.friday[*].id

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.friday-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.friday-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.friday-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}




//-----------------------------------------
// Worker Node Security Group
//----------------------------------------- 

resource "aws_security_group" "friday-node" {
  name        = "terraform-eks-friday-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.friday.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = tomap({
    "Name"                                      = "terraform-eks-friday-node",
    "kubernetes.io/cluster/${var.cluster-name}" = "owned",
  })
}

resource "aws_security_group_rule" "friday-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.friday-node.id
  source_security_group_id = aws_security_group.friday-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "friday-node-ingress-cluster-https" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.friday-node.id
  source_security_group_id = aws_security_group.friday-cluster.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "friday-node-ingress-cluster-others" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.friday-node.id
  source_security_group_id = aws_security_group.friday-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}


resource "aws_security_group_rule" "friday-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.friday-cluster.id
  source_security_group_id = aws_security_group.friday-node.id
  to_port                  = 443
  type                     = "ingress"
}


//-----------------------------------------
// Worker Node AutoScaling Group
//----------------------------------------- 

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.friday.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}


# and can be swapped out as necessary.
data "aws_region" "current" {}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  friday-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.friday.endpoint}' --b64-cluster-ca '${aws_eks_cluster.friday.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "friday" {
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.friday-node.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = "m4.large"
  name_prefix                 = "terraform-eks-friday"
  security_groups             = ["${aws_security_group.friday-node.id}"]
  user_data_base64            = base64encode(local.friday-node-userdata)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "friday" {
  desired_capacity     = 3
  launch_configuration = aws_launch_configuration.friday.id
  max_size             = 6
  min_size             = 2
  name                 = "terraform-eks-friday"
  vpc_zone_identifier  = aws_subnet.friday[*].id

  tag {
    key                 = "Name"
    value               = "terraform-eks-friday"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}







