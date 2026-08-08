import csv
import io
import json
import os
import re
import uuid
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")

TABLE_NAME = os.environ["TABLE_NAME"]
API_BASE_URL = os.environ["API_BASE_URL"]
APPROVER_EMAIL = os.environ["APPROVER_EMAIL"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]

VALID_PROTOCOLS = {"tcp", "udp", "icmp", "-1"}
REQUIRED_COLUMNS = {"type", "protocol", "from_port", "to_port", "cidr", "description"}


def handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        obj = s3.get_object(Bucket=bucket, Key=key)
        content = obj["Body"].read().decode("utf-8")
        rules, errors = parse_rules(content)

        request_id = str(uuid.uuid4())
        token = str(uuid.uuid4())
        status = "INVALID" if errors else "PENDING"
        sg_name = derive_sg_name(key, request_id)

        table.put_item(
            Item={
                "request_id": request_id,
                "token": token,
                "status": status,
                "source_key": key,
                "sg_name": sg_name,
                "rules": rules,
                "errors": errors,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        )

        if errors:
            send_email(
                subject=f"[Rejected] Security group CSV request {request_id} failed validation",
                body="The uploaded CSV had the following errors:\n" + "\n".join(errors),
            )
            continue

        approve_url = f"{API_BASE_URL}/approve/{request_id}?token={token}"
        reject_url = f"{API_BASE_URL}/reject/{request_id}?token={token}"
        body = (
            f"A new security group request ({request_id}) was uploaded from s3://{bucket}/{key}.\n\n"
            f"Security group name: {sg_name}\n\n"
            f"Proposed rules:\n{json.dumps(rules, indent=2)}\n\n"
            f"Approve: {approve_url}\n"
            f"Reject:  {reject_url}\n"
        )
        send_email(subject=f"Security group approval needed: {request_id}", body=body)

    return {"statusCode": 200}


def derive_sg_name(key, request_id):
    """Derive an AWS-valid security group name from the uploaded CSV filename,
    e.g. incoming/app-sg-test.csv -> app-sg-test. Falls back to a
    request-id-based name if the filename doesn't yield a usable name."""
    base = os.path.splitext(os.path.basename(key))[0]
    name = re.sub(r"[^a-zA-Z0-9-]", "-", base).strip("-").lower()
    name = re.sub(r"-+", "-", name)

    if not name or name.startswith("sg-"):  # AWS reserves the "sg-" prefix
        name = f"csv-request-{request_id}"

    return name[:255]


def parse_rules(content):
    rules = []
    errors = []
    reader = csv.DictReader(io.StringIO(content))

    for i, row in enumerate(reader, start=2):  # row 1 is the header
        missing = REQUIRED_COLUMNS - row.keys()
        if missing:
            errors.append(f"Row {i}: missing columns {sorted(missing)}")
            continue

        rule_type = (row["type"] or "").strip().lower()
        if rule_type not in ("ingress", "egress"):
            errors.append(f"Row {i}: type must be 'ingress' or 'egress', got '{row['type']}'")
            continue

        protocol = (row["protocol"] or "").strip().lower()
        if protocol not in VALID_PROTOCOLS:
            errors.append(f"Row {i}: protocol must be one of {sorted(VALID_PROTOCOLS)}")
            continue

        try:
            from_port = int(row["from_port"])
            to_port = int(row["to_port"])
        except ValueError:
            errors.append(f"Row {i}: from_port/to_port must be integers")
            continue

        cidr = (row["cidr"] or "").strip()
        if "/" not in cidr:
            errors.append(f"Row {i}: cidr '{cidr}' must be in CIDR notation, e.g. 10.0.0.0/16")
            continue

        rules.append(
            {
                "type": rule_type,
                "protocol": protocol,
                "from_port": from_port,
                "to_port": to_port,
                "cidr": cidr,
                "description": (row["description"] or "").strip(),
            }
        )

    if not rules and not errors:
        errors.append("CSV contained no data rows")

    return rules, errors


def send_email(subject, body):
    ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [APPROVER_EMAIL]},
        Message={
            "Subject": {"Data": subject},
            "Body": {"Text": {"Data": body}},
        },
    )
