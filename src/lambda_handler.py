import boto3
import json
import base64
import os

rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    try:
        # API Gateway sends the body as a string, we must parse it
        body = json.loads(event['body'])
        image_bytes = base64.b64decode(body['image_data'])
        
        # Call Rekognition directly with bytes
        labels = rekognition.detect_labels(Image={'Bytes': image_bytes})
        faces = rekognition.detect_faces(Image={'Bytes': image_bytes}, Attributes=['ALL'])
        
        # Create the result data
        result_data = {
            "labels": labels['Labels'][:5],
            "face_count": len(faces['FaceDetails']),
            "emotions": faces['FaceDetails'][0]['Emotions'] if faces['FaceDetails'] else "No faces found"
        }

        # Return a SINGLE structured response with CORS headers
        # Ensure your Lambda returns this structure
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "labels": labels['Labels'][:5],
                "face_count": len(faces['FaceDetails']),
                "emotions": faces['FaceDetails'][0]['Emotions'] if faces['FaceDetails'] else []
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": { "Access-Control-Allow-Origin": "*" },
            "body": json.dumps({"error": str(e)})
        }