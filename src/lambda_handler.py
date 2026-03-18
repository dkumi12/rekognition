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

        # CASE 1: S3 Record (Manual Pipeline)
        if 'Records' in event: #
            bucket = event['Records'][0]['s3']['bucket']['name']
            key = event['Records'][0]['s3']['object']['key']
            print(f"DEBUG: S3 Trigger from {bucket}/{key}")
            s3_info = {"bucket": bucket, "key": key}
            
            response = s3.get_object(Bucket=bucket, Key=key)
            image_bytes = response['Body'].read()

        # CASE 2: API Gateway Body (Frontend)
        elif 'body' in event: #
            print("DEBUG: API Gateway Trigger detected.")
            body = json.loads(event['body'])
            image_bytes = base64.b64decode(body['image_data'])

        if not image_bytes:
            raise Exception("No image data found in event.")

        # AI ANALYSIS
        labels = rekognition.detect_labels(Image={'Bytes': image_bytes})
        faces = rekognition.detect_faces(Image={'Bytes': image_bytes}, Attributes=['ALL'])
        
        result_data = {
            "labels": labels['Labels'][:5],
            "face_count": len(faces['FaceDetails']),
            "emotions": faces['FaceDetails'][0]['Emotions'] if faces['FaceDetails'] else []
        }

        # FINAL DESTINATION CHECK
        if s3_info:
            output_bucket = os.environ.get('OUTPUT_BUCKET') #
            print(f"DEBUG: Saving JSON results to {output_bucket}")
            
            # Cleanly name the analysis file
            file_name = s3_info['key'].split('/')[-1]
            output_key = f"analysis-{file_name}.json"
            
            s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=json.dumps(result_data, indent=2),
                ContentType='application/json'
            ) #
            return {"status": "Manual pipeline analysis saved."}

        # RETURN TO BROWSER
        return {
            "statusCode": 200,
            "headers": { 
                "Access-Control-Allow-Origin": "*", #
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