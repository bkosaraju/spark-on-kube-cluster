resource "aws_cognito_user_pool" "pool" {
  name = "${var.argo-ns}-${var.cluster-name}"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }

    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }
 schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    required                 = true # true for "sub"
}
}



resource "aws_cognito_user_pool_client" "argo-pool-client" {
  name = "argo-${var.argo-ns}-${var.cluster-name}"
  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret     = true
  explicit_auth_flows = ["ALLOW_CUSTOM_AUTH","ALLOW_USER_SRP_AUTH","ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"
  callback_urls = ["https://argo.${var.cluster-name}.${var.eks-hosted-dnszone}/oauth2/callback"]
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid","email","profile","aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
}

#resource "aws_cognito_user_pool_domain" "argo-pool-domain" {
#  domain       = "argo-${var.argo-ns}-${var.cluster-name}"
#  user_pool_id = aws_cognito_user_pool.pool.id
#}

resource "aws_cognito_user_pool_client" "grafana-pool-client" {
  name = "grafana-${var.grafana-ns}-${var.cluster-name}"
  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret     = true
  explicit_auth_flows = ["ALLOW_CUSTOM_AUTH","ALLOW_USER_SRP_AUTH","ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"
  callback_urls = ["https://grafana.${var.cluster-name}.${var.eks-hosted-dnszone}/login/generic_oauth"]
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid","email","profile","aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
}

resource "aws_cognito_user_pool_domain" "pool-domain" {
  domain       = "clientapps-${var.cluster-name}"
  user_pool_id = aws_cognito_user_pool.pool.id
}



resource "aws_iam_role" "group_role" {
  name = "argo.${var.cluster-name}.${var.eks-hosted-dnszone}-cognito-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_cognito_user_group" "main" {
  name         = "argo-cognito-group"
  user_pool_id = aws_cognito_user_pool.pool.id
  description  = "Argo cognito group created and Managed by Terraform"
  precedence   = 42
  role_arn     = aws_iam_role.group_role.arn
}
