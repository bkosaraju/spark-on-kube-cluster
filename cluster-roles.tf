
resource "aws_iam_role" "ns-admin" {
    name = "${var.cluster-name}-${var.application-namespace}-admin-role"
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "sts:AssumeRole"
      }
    ]
}
  POLICY
}


  resource "aws_iam_policy" "eks-cluster-policy" {
    name = "${var.cluster-name}-eks-policy"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "eks:DescribeNodegroup",
                  "eks:ListNodegroups",
                  "eks:DescribeUpdate",
                  "eks:ListUpdates",
                  "eks:DescribeCluster"
              ],
              "Resource": "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster-name}"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": "eks:ListClusters",
              "Resource": "*"
          }
      ]
}
  POLICY
  }


  resource "aws_iam_policy" "application-config" {
    name = "${var.cluster-name}-s3-appconfig-policy"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "s3:GetObjectAcl",
                  "s3:GetObject",
                  "s3:ListBucket"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.application-s3-bucket}/config/*",
                  "arn:aws:s3:::${var.application-s3-bucket}/jars/*"
              ]
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": [
                  "s3:ListAllMyBuckets",
                  "s3:HeadBucket",
                  "s3:ListBucket"
              ],
              "Resource": "*"
          },
          {
              "Sid": "VisualEditor2",
              "Effect": "Allow",
              "Action": [
                  "s3:GetObjectAcl",
                  "s3:GetObject",
                  "s3:ListBucket",
                  "s3:putObject"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.application-s3-bucket}/tmp/*",
                  "arn:aws:s3:::${var.application-s3-bucket}/logs/*"
              ]
          }
      ]
}
POLICY
}
  resource "aws_iam_policy" "argo-s3-config" {
    name = "${var.cluster-name}-s3-argo-policy"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "s3:*"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.argo-s3-bucket}",
                  "arn:aws:s3:::${var.argo-s3-bucket}/*"
              ]
          }
      ]
}
POLICY
}


  resource "aws_iam_policy" "application-config-readonly" {
    name = "${var.cluster-name}-s3-config-read-policy"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "s3:GetObjectAcl",
                  "s3:GetObject",
                  "s3:ListBucket"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.application-s3-bucket}/config/*",
                  "arn:aws:s3:::${var.application-s3-bucket}/jars/*"
              ]
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": [
                  "s3:ListAllMyBuckets",
                  "s3:HeadBucket"
              ],
              "Resource": "*"
          },
          {
              "Sid": "VisualEditor2",
              "Effect": "Allow",
              "Action": [
                  "s3:GetObjectAcl",
                  "s3:GetObject",
                  "s3:ListBucket"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.application-s3-bucket}/logs/*"
              ]
          },
          {
              "Sid": "VisualEditor3",
              "Effect": "Allow",
              "Action": [
                  "s3:ListBucket"
              ],
              "Resource": [
                  "arn:aws:s3:::${var.application-s3-bucket}"
              ]
          }
      ]
  }
  POLICY
  }


  data aws_kms_key "appkmskey" {
    key_id = "alias/${var.application-s3-bucket-kms-key}"
  }

  resource "aws_iam_policy" "application-kms-keyaccess" {
    name = "${var.cluster-name}-kms-keyaccess"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "kms:Decrypt",
                  "kms:Encrypt",
                  "kms:GenerateDataKey",
                  "kms:GenerateDataKeyWithoutPlaintext",
                  "kms:ReEncryptTo",
                  "kms:DescribeKey",
                  "kms:ReEncryptFrom"
              ],
              "Resource": "${data.aws_kms_key.appkmskey.arn}"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": "kms:GenerateRandom",
              "Resource": "*"
          }
      ]
  }
  POLICY
  }

  data aws_kms_key "argokmskey" {
    key_id = "alias/${var.argo-s3-bucket-kms-key}"
  }

  resource "aws_iam_policy" "argo-kms-keyaccess" {
    name = "${var.cluster-name}-argo-kms-keyaccess"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "kms:Decrypt",
                  "kms:Encrypt",
                  "kms:GenerateDataKey",
                  "kms:GenerateDataKeyWithoutPlaintext",
                  "kms:ReEncryptTo",
                  "kms:DescribeKey",
                  "kms:ReEncryptFrom"
              ],
              "Resource": "${data.aws_kms_key.argokmskey.arn}"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": "kms:GenerateRandom",
              "Resource": "*"
          }
      ]
  }
  POLICY
  }


  resource "aws_iam_policy" "ssm-read-access" {
    name = "${var.cluster-name}-ssm-read-policy"
    policy = <<POLICY
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "ssm:GetParameterHistory",
                  "ssm:GetParametersByPath",
                  "ssm:GetParameters",
                  "ssm:GetParameter"
              ],
              "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": [
                  "kms:Decrypt",
                  "ssm:DescribeParameters"
              ],
              "Resource": "*"
          }
      ]
  }
  POLICY
  }



  resource "aws_iam_role" "ns-edit" {
    name = "${var.cluster-name}-${var.application-namespace}-edit-role"

    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
  }


  resource "aws_iam_role" "ns-view" {
    name = "${var.cluster-name}-${var.application-namespace}-view-role"

    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "sts:AssumeRole"
      }
    ]
}
  POLICY
  }

  resource "aws_iam_policy" "ns-admin" {
    name        = "${var.cluster-name}-${var.application-namespace}-admin-policy"
    path        = "/"
    description = "Policy for providing User admin access to ${var.cluster-name} cluster in ${var.application-namespace} name space"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-admin-role"
    }
  }
  EOF
  }

  resource "aws_iam_policy" "ns-edit" {
    name        = "${var.cluster-name}-${var.application-namespace}-edit-policy"
    path        = "/"
    description = "Policy for providing User edit access to ${var.cluster-name} cluster in ${var.application-namespace} name space"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-edit-role"
    }
  }
  EOF
  }


  resource "aws_iam_policy" "ns-view" {
    name        = "${var.cluster-name}-${var.application-namespace}-view-policy"
    path        = "/"
    description = "Policy for providing User view access to ${var.cluster-name} cluster in ${var.application-namespace} name space"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-view-role"
    }
  }
  EOF
  }


  resource "aws_iam_role_policy_attachment" "eks-iam-policy-attach-admin" {
    role       = aws_iam_role.ns-admin.name
    policy_arn = aws_iam_policy.ns-admin.arn
  }
  resource "aws_iam_role_policy_attachment" "eks-iam-policy-attach-edit" {
    role       = aws_iam_role.ns-edit.name
    policy_arn = aws_iam_policy.ns-edit.arn
  }
  resource "aws_iam_role_policy_attachment" "eks-iam-policy-attach-view" {
    role       = aws_iam_role.ns-view.name
    policy_arn = aws_iam_policy.ns-view.arn
  }

  resource "aws_iam_group" "developer" {
    name = "${var.cluster-name}-developer-group"
  }
  resource "aws_iam_group" "operator" {
    name = "${var.cluster-name}-operator-group"
  }
  resource "aws_iam_group" "admin" {
    name = "${var.cluster-name}-admin-group"
  }

  //Admin

  resource "aws_iam_group_policy_attachment" "admin-eks" {
    group = aws_iam_group.admin.name
    policy_arn = aws_iam_policy.eks-cluster-policy.arn
  }

  resource "aws_iam_group_policy_attachment" "admin-ns" {
    group = aws_iam_group.admin.name
    policy_arn = aws_iam_policy.ns-admin.arn
  }

  resource "aws_iam_group_policy_attachment" "admin-ssm" {
    group = aws_iam_group.admin.name
    policy_arn = aws_iam_policy.ssm-read-access.arn
  }

  resource "aws_iam_group_policy_attachment" "admin-s3" {
    group = aws_iam_group.admin.name
    policy_arn = aws_iam_policy.application-config.arn
  }

  resource "aws_iam_group_policy_attachment" "admin-kms" {
    group = aws_iam_group.admin.name
    policy_arn = aws_iam_policy.application-kms-keyaccess.arn
  }


  //Operator

  resource "aws_iam_group_policy_attachment" "operator-eks" {
    group = aws_iam_group.operator.name
    policy_arn = aws_iam_policy.eks-cluster-policy.arn
  }

  resource "aws_iam_group_policy_attachment" "operator-ns" {
    group = aws_iam_group.operator.name
    policy_arn = aws_iam_policy.ns-view.arn
  }

  resource "aws_iam_group_policy_attachment" "operator-ssm" {
    group = aws_iam_group.operator.name
    policy_arn = aws_iam_policy.ssm-read-access.arn
  }

  resource "aws_iam_group_policy_attachment" "operator-s3" {
    group = aws_iam_group.operator.name
    policy_arn = aws_iam_policy.application-config.arn
  }

  resource "aws_iam_group_policy_attachment" "operator-kms" {
    group = aws_iam_group.operator.name
    policy_arn = aws_iam_policy.application-kms-keyaccess.arn
  }


  //developer
  resource "aws_iam_group_policy_attachment" "developer-eks" {
    group = aws_iam_group.developer.name
    policy_arn = aws_iam_policy.eks-cluster-policy.arn
  }

  resource "aws_iam_group_policy_attachment" "developer-ns" {
    group = aws_iam_group.developer.name
    policy_arn = aws_iam_policy.ns-edit.arn
  }

  resource "aws_iam_group_policy_attachment" "developer-ssm" {
    group = aws_iam_group.developer.name
    policy_arn = aws_iam_policy.ssm-read-access.arn
  }

  resource "aws_iam_group_policy_attachment" "developer-s3" {
    group = aws_iam_group.developer.name
    policy_arn = aws_iam_policy.application-config.arn
  }

  resource "aws_iam_group_policy_attachment" "developer-kms" {
    group = aws_iam_group.developer.name
    policy_arn = aws_iam_policy.application-kms-keyaccess.arn
  }
