# test-github-repo

Learning project: GitHub Actions CI/CD + Terraform managing AWS infrastructure,
authenticated via OIDC (no long-lived AWS access keys stored in GitHub).

## How it works

1. On every push/PR touching `terraform/**`, the `Terraform CI/CD` workflow
   ([.github/workflows/terraform.yml](.github/workflows/terraform.yml)) runs.
2. The job requests a short-lived GitHub OIDC token and exchanges it for
   temporary AWS credentials by assuming:
   `arn:aws:iam::250251693220:role/test-github-role`
3. Pull requests get `terraform plan` output posted as a PR comment.
4. Merges to `main` run `terraform apply` automatically.

## Prerequisites checklist

- [x] IAM role created with an OIDC trust policy (you already did this).
- [ ] Verify the role's trust policy scopes to *this* repo, e.g. the
      condition includes something like:
      `token.actions.githubusercontent.com:sub` =
      `repo:<your-org-or-user>/test-github-repo:ref:refs/heads/main`
      (and/or `repo:...:pull_request` if you want PR plans to run too).
- [ ] The role has an IAM policy attached granting only the permissions
      Terraform needs (start narrow — e.g. S3 permissions for the example
      bucket — and expand as you add resources).
- [ ] `terraform/` state currently uses a **local backend**. That's fine for
      solo learning, but CI runs use a fresh checkout each time, so state
      won't persist between runs. Next step once things work: create an S3
      bucket + DynamoDB table (or use S3 native locking) and uncomment the
      `backend "s3"` block in [terraform/providers.tf](terraform/providers.tf).

## Local usage

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Next steps to learn

1. Push this to `main` and watch the Actions tab run `init/validate/plan/apply`.
2. Open a PR that changes `terraform/main.tf` and see the plan posted as a comment.
3. Add branch protection on `main` requiring the workflow to pass before merge.
4. Migrate state to an S3 remote backend.
5. Split into multiple environments (dev/stage/prod) with separate `.tfvars` or workspaces.
