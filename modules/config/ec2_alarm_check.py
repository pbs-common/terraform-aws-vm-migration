"""
AWS Config custom rule: every EC2 instance must have CloudWatch alarms
covering CPU, memory and disk.

CPU comes from the AWS/EC2 namespace; memory and disk come from the
CloudWatch agent (CWAgent namespace). An alarm "covers" an instance when
one of its metrics has an InstanceId dimension equal to that instance.
Metric-math alarms are inspected too.

Environment variables:
  REQUIRED_METRICS       JSON map of check -> list of acceptable metric names,
                         e.g. {"cpu": ["CPUUtilization"], "memory": ["mem_used_percent"], ...}
  REQUIRE_ALARM_ACTIONS  "true" to ignore alarms that have actions disabled
                         or no alarm action configured.
"""
import json
import os
from collections import defaultdict

import boto3

ec2 = boto3.client("ec2")
cloudwatch = boto3.client("cloudwatch")
config = boto3.client("config")

RESOURCE_TYPE = "AWS::EC2::Instance"
INSTANCE_STATES = ["pending", "running", "stopping", "stopped"]


def _required_metrics():
    required = json.loads(os.environ["REQUIRED_METRICS"])
    # metric name -> check name ("cpu", "memory", "disk")
    return required, {m: check for check, names in required.items() for m in names}


def _metrics_in_alarm(alarm):
    """Yield (metric_name, dimensions) for simple and metric-math alarms."""
    if alarm.get("MetricName"):
        yield alarm["MetricName"], alarm.get("Dimensions", [])
    for query in alarm.get("Metrics", []):
        metric = query.get("MetricStat", {}).get("Metric")
        if metric:
            yield metric["MetricName"], metric.get("Dimensions", [])


def _coverage(metric_to_check, require_actions):
    """Return {instance_id: {checks covered}} from all metric alarms."""
    covered = defaultdict(set)
    for page in cloudwatch.get_paginator("describe_alarms").paginate(AlarmTypes=["MetricAlarm"]):
        for alarm in page["MetricAlarms"]:
            if require_actions and not (alarm.get("ActionsEnabled") and alarm.get("AlarmActions")):
                continue
            for name, dims in _metrics_in_alarm(alarm):
                check = metric_to_check.get(name)
                if not check:
                    continue
                for d in dims:
                    if d["Name"] == "InstanceId":
                        covered[d["Value"]].add(check)
    return covered


def _instance_ids():
    ids = []
    paginator = ec2.get_paginator("describe_instances")
    for page in paginator.paginate(Filters=[{"Name": "instance-state-name", "Values": INSTANCE_STATES}]):
        for reservation in page["Reservations"]:
            ids.extend(i["InstanceId"] for i in reservation["Instances"])
    return ids


def _previously_evaluated(rule_name):
    ids = set()
    paginator = config.get_paginator("get_compliance_details_by_config_rule")
    for page in paginator.paginate(ConfigRuleName=rule_name):
        for result in page["EvaluationResults"]:
            qualifier = result["EvaluationResultIdentifier"]["EvaluationResultQualifier"]
            if qualifier.get("ResourceType") == RESOURCE_TYPE:
                ids.add(qualifier["ResourceId"])
    return ids


def handler(event, context):
    invoking_event = json.loads(event["invokingEvent"])
    timestamp = invoking_event["notificationTime"]
    result_token = event["resultToken"]
    rule_name = event["configRuleName"]

    required, metric_to_check = _required_metrics()
    require_actions = os.environ.get("REQUIRE_ALARM_ACTIONS", "true").lower() == "true"

    covered = _coverage(metric_to_check, require_actions)
    instances = _instance_ids()

    evaluations = []
    for instance_id in instances:
        missing = sorted(set(required) - covered.get(instance_id, set()))
        evaluations.append({
            "ComplianceResourceType": RESOURCE_TYPE,
            "ComplianceResourceId": instance_id,
            "ComplianceType": "NON_COMPLIANT" if missing else "COMPLIANT",
            "Annotation": ("Missing alarms for: " + ", ".join(missing))[:256] if missing
                          else "CPU, memory and disk alarms present",
            "OrderingTimestamp": timestamp,
        })

    # Instances that were evaluated before but are now terminated: clear them out.
    for gone in _previously_evaluated(rule_name) - set(instances):
        evaluations.append({
            "ComplianceResourceType": RESOURCE_TYPE,
            "ComplianceResourceId": gone,
            "ComplianceType": "NOT_APPLICABLE",
            "OrderingTimestamp": timestamp,
        })

    test_mode = result_token == "TESTMODE"
    for i in range(0, len(evaluations), 100):
        config.put_evaluations(
            Evaluations=evaluations[i:i + 100],
            ResultToken=result_token,
            TestMode=test_mode,
        )

    noncompliant = sum(e["ComplianceType"] == "NON_COMPLIANT" for e in evaluations)
    print(f"Evaluated {len(instances)} instances, {noncompliant} non-compliant")
