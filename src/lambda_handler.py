import boto3
import json
import base64
import os

rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        image_bytes = None
        s3_info = None

        # --- CASE 1: S3 Trigger (Manual Pipeline) ---
        if 'Records' in event:
            bucket = event['Records'][0]['s3']['bucket']['name']
            key = event['Records'][0]['s3']['object']['key']
            s3_info = {"bucket": bucket, "key": key}
            
            # Get the image bytes from the S3 object
            response = s3.get_object(Bucket=bucket, Key=key)
            image_bytes = response['Body'].read()

        # --- CASE 2: API Gateway Trigger (Frontend) ---
        elif 'body' in event:
            body = json.loads(event['body'])
            image_bytes = base64.b64decode(body['image_data'])

        if not image_bytes:
            raise Exception("No image data found in event")

        # --- COMMON ANALYSIS LOGIC ---
        labels = rekognition.detect_labels(Image={'Bytes': image_bytes})
        faces = rekognition.detect_faces(Image={'Bytes': image_bytes}, Attributes=['ALL'])
        
        result_data = {
            "labels": labels['Labels'][:5],
            "face_count": len(faces['FaceDetails']),
            "emotions": faces['FaceDetails'][0]['Emotions'] if faces['FaceDetails'] else []
        }

        # --- CASE 1 OUTPUT: Save JSON to S3 if it was a manual upload ---
        if s3_info:
            output_bucket = os.environ.get('OUTPUT_BUCKET')
            if output_bucket:
                output_key = f"analysis-{s3_info['key']}.json"
                s3.put_object(
                    Bucket=output_bucket,
                    Key=output_key,
                    Body=json.dumps(result_data),
                    ContentType='application/json'
                )
            return {"status": "S3 Analysis Complete"}

        # --- CASE 2 OUTPUT: Return JSON to Frontend ---
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps(result_data)
        }

    except Exception as e:
        print(f"Error: {str(e)}") # Visible in CloudWatch logs
        return {
            "statusCode": 500,
            "headers": { "Access-Control-Allow-Origin": "*" },
            "body": json.dumps({"error": str(e)})
        }