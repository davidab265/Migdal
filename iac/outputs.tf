//-----------------------------------------
// If you are planning on using kubectl to manage the Kubernetes cluster,
// now might be a great time to configure your client. After configuration,
// you can verify cluster access via kubectl version displaying server version 
// information in addition to local client version information.
// 
// The AWS CLI eks update-kubeconfig command provides a simple method to create or update configuration files.
// 
// If you would rather update your configuration manually,
// the below Terraform output generates a sample kubectl configuration to connect to your cluster.
// This can be placed into a Kubernetes configuration file, e.g. ~/.kube/config 
//-----------------------------------------


locals {

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.friday.endpoint}
    certificate-authority-data: ${aws_eks_cluster.friday.certificate_authority[0].data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

output "config_map_aws_auth" {
  value = local.config_map_aws_auth
}

output "kubeconfig" {
  value = local.kubeconfig
}



//-----------------------------------------
// The EKS service does not provide a cluster-level API parameter or resource to automatically
// configure the underlying Kubernetes cluster to allow worker nodes
// to join the cluster via AWS IAM role authentication.

// To output an example IAM Role authentication ConfigMap from your Terraform configuration:
//-----------------------------------------

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.friday-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}
