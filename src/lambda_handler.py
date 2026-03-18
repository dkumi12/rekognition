import boto3
import json
import base64
import os

rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    print(f"DEBUG: Received event: {json.dumps(event)}")
    try:
        image_bytes = None
        s3_info = None

        # 1. IDENTIFY THE SOURCE
        if 'Records' in event:
            # Manual S3 upload pipeline
            bucket = event['Records'][0]['s3']['bucket']['name']
            key = event['Records'][0]['s3']['object']['key']
            print(f"DEBUG: S3 Trigger from {bucket}/{key}")
            s3_info = {"bucket": bucket, "key": key}
            
            response = s3.get_object(Bucket=bucket, Key=key)
            image_bytes = response['Body'].read()

        elif 'body' in event:
            # Real-time API pipeline
            print("DEBUG: API Gateway Trigger detected.")
            body = json.loads(event['body'])
            image_bytes = base64.b64decode(body['image_data'])

        if not image_bytes:
            raise Exception("No image data found in event")

        # 2. ANALYSIS LOGIC
        labels = rekognition.detect_labels(Image={'Bytes': image_bytes})
        faces = rekognition.detect_faces(Image={'Bytes': image_bytes}, Attributes=['ALL'])
        
        result_data = {
            "labels": labels['Labels'][:5],
            "face_count": len(faces['FaceDetails']),
            "emotions": faces['FaceDetails'][0]['Emotions'] if faces['FaceDetails'] else []
        }

        # 3. HANDLE OUTPUT
        if s3_info:
            output_bucket = os.environ.get('OUTPUT_BUCKET')
            if output_bucket:
                # Save JSON to S3
                output_key = f"analysis-{s3_info['key'].split('/')[-1]}.json"
                print(f"DEBUG: Saving result to s3://{output_bucket}/{output_key}")
                s3.put_object(
                    Bucket=output_bucket,
                    Key=output_key,
                    Body=json.dumps(result_data, indent=2),
                    ContentType='application/json'
                )
            return {"status": "Manual S3 Analysis Saved"}

        # Return to Dashboard
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps(result_data)
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        return {
            "statusCode": 500,
            "headers": { "Access-Control-Allow-Origin": "*" },
            "body": json.dumps({"error": str(e)})
        }