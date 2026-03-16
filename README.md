\# Group 3: Amazon Rekognition Image Analysis Pipeline 🚀



\## Project Overview

An automated, serverless computer vision pipeline that analyzes images uploaded to S3. The system uses \*\*Amazon Rekognition\*\* to detect objects, analyze facial attributes, and extract text, storing the consolidated results in a structured JSON format.



\## 🏗 System Architecture

1\. \*\*S3 Input Bucket\*\*: Trigger point for the pipeline (`group3-rekognition-inputs-253a579f`).

2\. \*\*S3 Event Notification\*\*: Automatically invokes the Lambda function on `.jpg` or `.png` uploads.

3\. \*\*AWS Lambda\*\*: Processes the image using Python (Boto3) and calls Rekognition APIs.

4\. \*\*Amazon Rekognition\*\*: Performs Label Detection, Face Analysis, and Text Extraction.

5\. \*\*S3 Output Bucket\*\*: Stores the final analysis as a timestamped JSON file.



\## 📁 Project Structure

```text

├── terraform/                # Infrastructure-as-Code (David)

│   ├── main.tf               # S3, IAM, and Lambda resources

│   └── variables.tf

├── src/                      # Python Source Code (Emmanuel \& Michael)

│   ├── lambda\_handler.py     # Core Boto3 logic

│   └── utils.py              # Error handling and formatting

├── docs/                     # Documentation (Nana Kwaku)

│   ├── architecture\_diag.png

│   └── testing\_results.md

└── README.md

