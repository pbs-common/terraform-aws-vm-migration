"""Forward SNS notifications (CloudWatch alarm state changes) to Slack and/or Teams."""

import json
import os
import urllib.request

import boto3

SLACK_WEBHOOK_SECRET_ARN = os.environ.get("SLACK_WEBHOOK_SECRET_ARN", "")
TEAMS_WEBHOOK_SECRET_ARN = os.environ.get("TEAMS_WEBHOOK_SECRET_ARN", "")

_secrets_client = boto3.client("secretsmanager")
# Caches across invocations in the same warm container, so each webhook
# URL gets fetched once, not on every alarm.
_webhook_url_cache = {}


def _webhook_url(secret_arn):
    if not secret_arn:
        return ""
    if secret_arn not in _webhook_url_cache:
        _webhook_url_cache[secret_arn] = _secrets_client.get_secret_value(SecretId=secret_arn)["SecretString"]
    return _webhook_url_cache[secret_arn]

STATE_COLOR = {
    "ALARM": "D32F2F",
    "OK": "2E7D32",
    "INSUFFICIENT_DATA": "757575",
}

STATE_EMOJI = {
    "ALARM": ":rotating_light:",
    "OK": ":white_check_mark:",
    "INSUFFICIENT_DATA": ":grey_question:",
}


def _parse_alarm(raw_message):
    try:
        message = json.loads(raw_message)
    except (TypeError, ValueError):
        return None
    if not isinstance(message, dict) or "AlarmName" not in message:
        return None
    return message


def _slack_payload(alarm, raw_message):
    if alarm is None:
        return {"text": raw_message}

    state = alarm.get("NewStateValue", "UNKNOWN")
    return {
        "text": (
            f"{STATE_EMOJI.get(state, '')} *{alarm.get('AlarmName')}* is now *{state}*\n"
            f"> {alarm.get('NewStateReason', '')}\n"
            f"Region: {alarm.get('Region', 'unknown')} | Account: {alarm.get('AWSAccountId', 'unknown')}"
        )
    }


def _teams_payload(alarm, raw_message):
    if alarm is None:
        return {"text": raw_message}

    state = alarm.get("NewStateValue", "UNKNOWN")
    return {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "summary": f"{alarm.get('AlarmName')} is {state}",
        "themeColor": STATE_COLOR.get(state, "757575"),
        "sections": [
            {
                "activityTitle": f"{alarm.get('AlarmName')} is now {state}",
                "text": alarm.get("NewStateReason", ""),
                "facts": [
                    {"name": "Region", "value": alarm.get("Region", "unknown")},
                    {"name": "Account", "value": alarm.get("AWSAccountId", "unknown")},
                ],
            }
        ],
    }


def _post(url, payload):
    if not url:
        return
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            response.read()
    except Exception as exc:
        # One bad webhook shouldn't block the other, or trigger an SNS retry
        # that just re-sends to the one that already worked.
        print(f"webhook POST failed: {exc}")


def handler(event, _context):
    slack_url = _webhook_url(SLACK_WEBHOOK_SECRET_ARN)
    teams_url = _webhook_url(TEAMS_WEBHOOK_SECRET_ARN)

    for record in event.get("Records", []):
        raw_message = record.get("Sns", {}).get("Message", "")
        alarm = _parse_alarm(raw_message)

        _post(slack_url, _slack_payload(alarm, raw_message))
        _post(teams_url, _teams_payload(alarm, raw_message))
