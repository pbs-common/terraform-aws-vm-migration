# Tag-scoped SSM session-access policy. Attaching it to a role/permission set happens outside
# this repo (IAM Identity Center).

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "StartSessionOnTaggedInstances"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    dynamic "condition" {
      for_each = var.tags
      content {
        test     = "StringEquals"
        variable = "ssm:resourceTag/${condition.key}"
        values   = [condition.value]
      }
    }
  }

  statement {
    sid       = "StartSessionDocument"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell"]
  }

  statement {
    sid       = "ManageOwnSessions"
    effect    = "Allow"
    actions   = ["ssm:TerminateSession", "ssm:ResumeSession"]
    resources = ["arn:aws:ssm:*:*:session/$${aws:username}-*"]
  }

  statement {
    sid    = "SessionDiscovery"
    effect = "Allow"
    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceInformation",
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "this" {
  name   = var.name
  policy = data.aws_iam_policy_document.this.json
  tags   = var.tags
}
