import json
import os
import urllib3
from datetime import datetime

http = urllib3.PoolManager()

def handler(event, context):
    """
    Lambda function to send CloudWatch Alarm notifications to Slack
    """
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    
    if not slack_webhook_url:
        print("SLACK_WEBHOOK_URL not configured")
        return {
            'statusCode': 200,
            'body': 'Slack webhook not configured'
        }
    
    # Parse SNS message
    try:
        message = json.loads(event['Records'][0]['Sns']['Message'])
    except:
        # Fallback for simple string messages
        message = {
            'AlarmName': 'Unknown',
            'NewStateValue': 'UNKNOWN',
            'NewStateReason': event['Records'][0]['Sns']['Message']
        }
    
    alarm_name = message.get('AlarmName', 'Unknown Alarm')
    new_state = message.get('NewStateValue', 'UNKNOWN')
    reason = message.get('NewStateReason', 'No reason provided')
    timestamp = message.get('StateChangeTime', datetime.utcnow().isoformat())
    region = message.get('Region', 'us-east-2')
    
    # Determine color and emoji based on state
    if new_state == 'ALARM':
        color = '#ff0000'  # Red
        emoji = '🚨'
        state_text = 'ALARM'
    elif new_state == 'OK':
        color = '#36a64f'  # Green
        emoji = '✅'
        state_text = 'RESOLVED'
    else:
        color = '#ffcc00'  # Yellow
        emoji = '⚠️'
        state_text = new_state
    
    # Extract severity from alarm description
    severity = 'INFO'
    if '🚨 CRITICAL' in message.get('AlarmDescription', ''):
        severity = 'CRITICAL'
    elif '⚠️ WARNING' in message.get('AlarmDescription', ''):
        severity = 'WARNING'
    
    # Build Slack message
    slack_message = {
        'attachments': [{
            'color': color,
            'fallback': f"{emoji} {alarm_name} is {state_text}",
            'title': f"{emoji} {alarm_name}",
            'title_link': f"https://console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{alarm_name}",
            'text': reason,
            'fields': [
                {
                    'title': 'Status',
                    'value': state_text,
                    'short': True
                },
                {
                    'title': 'Severity',
                    'value': severity,
                    'short': True
                },
                {
                    'title': 'Region',
                    'value': region,
                    'short': True
                },
                {
                    'title': 'Time',
                    'value': timestamp,
                    'short': True
                }
            ],
            'footer': 'AWS CloudWatch',
            'footer_icon': 'https://a0.awsstatic.com/libra-css/images/logos/aws_logo_smile_1200x630.png',
            'ts': int(datetime.utcnow().timestamp())
        }]
    }
    
    # Add threshold information if available
    if 'Trigger' in message:
        trigger = message['Trigger']
        threshold = trigger.get('Threshold')
        metric_name = trigger.get('MetricName')
        
        if threshold and metric_name:
            slack_message['attachments'][0]['fields'].append({
                'title': 'Metric',
                'value': f"{metric_name}: {threshold}",
                'short': False
            })
    
    # Send to Slack
    try:
        encoded_data = json.dumps(slack_message).encode('utf-8')
        response = http.request(
            'POST',
            slack_webhook_url,
            body=encoded_data,
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"Slack notification sent: {response.status}")
        return {
            'statusCode': 200,
            'body': json.dumps('Notification sent to Slack')
        }
    except Exception as e:
        print(f"Error sending to Slack: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

