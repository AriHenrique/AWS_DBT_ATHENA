import boto3
import os
import json
from datetime import datetime

codebuild_client = boto3.client('codebuild')
CODE_BUILD_NAME = os.environ.get('code_build_name')
sns_client = boto3.client('sns')
SNS_TOPIC_ARN = os.environ.get('sns_topic_arn')


def serialize_datetime(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError("Type %s not serializable" % type(obj))


def main(event, lambda_context):
    """
    Start an AWS CodeBuild project.
    """
    try:
        response = codebuild_client.start_build(
            projectName=event.get('project', CODE_BUILD_NAME)
        )
        return json.dumps(response, default=serialize_datetime)
    except Exception as e:
        error_message = f'Error in Lambda Execution: {e}'
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=error_message,
            Subject='Error in Lambda Execution'
        )
        return json.dumps({'error': error_message}, default=serialize_datetime)
