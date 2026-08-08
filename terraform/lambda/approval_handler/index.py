import base64
import json
import os
import textwrap
import urllib.error
import urllib.request

import boto3

dynamodb = boto3.resource("dynamodb")
secretsmanager = boto3.client("secretsmanager")

TABLE_NAME = os.environ["TABLE_NAME"]
GITHUB_OWNER = os.environ["GITHUB_OWNER"]
GITHUB_REPO = os.environ["GITHUB_REPO"]
GITHUB_TOKEN_SECRET_ARN = os.environ["GITHUB_TOKEN_SECRET_ARN"]
GITHUB_BASE_BRANCH = os.environ.get("GITHUB_BASE_BRANCH", "main")

_github_token_cache = None


def handler(event, context):
    path_params = event.get("pathParameters") or {}
    query_params = event.get("queryStringParameters") or {}
    request_id = path_params.get("request_id")
    token = query_params.get("token")
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    action = "approve" if "/approve" in event.get("routeKey", "") else "reject"

    table = dynamodb.Table(TABLE_NAME)
    item = table.get_item(Key={"request_id": request_id}).get("Item")

    if not item:
        return respond(404, "Request not found.")
    if item.get("token") != token:
        return respond(403, "Invalid or expired approval link.")

    # GET only renders a confirmation page — it must stay side-effect-free
    # because email security scanners (e.g. Safe Links) auto-fetch every URL
    # in a message, which would otherwise silently approve/reject on delivery.
    if method == "GET":
        if item.get("status") != "PENDING":
            return respond(409, f"Request already {item.get('status')}.")
        return respond_html(200, render_confirm_page(request_id, token, action))

    if item.get("status") != "PENDING":
        return respond(409, f"Request already {item.get('status')}.")

    new_status = "APPROVED" if action == "approve" else "REJECTED"
    table.update_item(
        Key={"request_id": request_id},
        UpdateExpression="SET #s = :s",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": new_status},
    )


    if new_status == "APPROVED":
        try:
            sg_name = item.get("sg_name") or f"csv-request-{request_id}"
            pr_url = create_pull_request(request_id, sg_name, item["rules"])
            return respond(200, f"Request approved. Pull request opened: {pr_url}")
        except Exception as exc:
            # Status is already APPROVED in DynamoDB; surface the PR failure for manual follow-up.
            return respond(500, f"Approved, but failed to open pull request: {exc}")

    return respond(200, "Request rejected.")


def respond(status_code, message):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "text/plain"},
        "body": message,
    }


def respond_html(status_code, html):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "text/html"},
        "body": html,
    }


def render_confirm_page(request_id, token, action):
    label = "Approve" if action == "approve" else "Reject"
    return textwrap.dedent(
        f"""
        <!doctype html>
        <html>
          <body style="font-family: sans-serif; max-width: 480px; margin: 3rem auto;">
            <h2>{label} security group request?</h2>
            <p><code>{request_id}</code></p>
            <form method="POST" action="/{action}/{request_id}?token={token}">
              <button type="submit" style="font-size: 1rem; padding: 0.5rem 1rem;">
                Confirm {label}
              </button>
            </form>
          </body>
        </html>
        """
    ).strip("\n")


def get_github_token():
    global _github_token_cache
    if _github_token_cache is None:
        secret = secretsmanager.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)
        _github_token_cache = secret["SecretString"]
    return _github_token_cache


def github_request(method, path, payload=None):
    url = f"https://api.github.com{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {get_github_token()}")
    req.add_header("Accept", "application/vnd.github+json")
    # GitHub's API returns 403 Forbidden if no User-Agent header is present.
    req.add_header("User-Agent", "sg-approval-workflow")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"GitHub API {method} {path} failed: {exc.code} {exc.reason} - {body}") from exc


def render_terraform(request_id, sg_name, rules):
    def block(rule):
        return textwrap.dedent(
            f"""
            {rule["type"]} {{
              protocol    = "{rule["protocol"]}"
              from_port   = {rule["from_port"]}
              to_port     = {rule["to_port"]}
              cidr_blocks = ["{rule["cidr"]}"]
              description = "{rule["description"]}"
            }}
            """
        ).strip("\n")

    rule_blocks = "\n\n  ".join(block(r) for r in rules)
    resource_name = request_id.replace("-", "_")

    return (
        textwrap.dedent(
            f"""
            # Auto-generated from CSV approval request {request_id}. Do not edit by hand.
            resource "aws_security_group" "sg_request_{resource_name}" {{
              name        = "{sg_name}"
              description = "Approved via CSV upload workflow (request {request_id})"
              vpc_id      = var.vpc_id

              {rule_blocks}

              tags = {{
                Name      = "{sg_name}"
                RequestId = "{request_id}"
              }}
            }}
            """
        ).strip("\n")
        + "\n"
    )


def create_pull_request(request_id, sg_name, rules):
    base_ref = github_request(
        "GET", f"/repos/{GITHUB_OWNER}/{GITHUB_REPO}/git/ref/heads/{GITHUB_BASE_BRANCH}"
    )
    base_sha = base_ref["object"]["sha"]

    branch_name = f"sg-request-{request_id}"
    github_request(
        "POST",
        f"/repos/{GITHUB_OWNER}/{GITHUB_REPO}/git/refs",
        {"ref": f"refs/heads/{branch_name}", "sha": base_sha},
    )

    # Must live directly under terraform/ so the existing pipeline's `terraform apply`
    # (working-directory: terraform) picks it up automatically.
    file_path = f"terraform/sg-{request_id}.tf"
    content = render_terraform(request_id, sg_name, rules)
    github_request(
        "PUT",
        f"/repos/{GITHUB_OWNER}/{GITHUB_REPO}/contents/{file_path}",
        {
            "message": f"Add approved security group for request {request_id}",
            "content": base64.b64encode(content.encode()).decode(),
            "branch": branch_name,
        },
    )

    pr = github_request(
        "POST",
        f"/repos/{GITHUB_OWNER}/{GITHUB_REPO}/pulls",
        {
            "title": f"Add security group for approved request {request_id}",
            "head": branch_name,
            "base": GITHUB_BASE_BRANCH,
            "body": f"Auto-generated from approved CSV upload (request `{request_id}`). "
            f"Review the `terraform plan` output before merging.",
        },
    )
    return pr["html_url"]
