# 1. Use the official AWS Lambda Python base image
FROM public.ecr.aws/lambda/python:3.12

# 2. Copy requirements from the src folder to the image
COPY src/requirements.txt .

# 3. Install the dependencies
RUN pip install -r requirements.txt

# 4. Copy the handler code from the src folder to the task root
COPY src/lambda_handler.py ${LAMBDA_TASK_ROOT}

# 5. Set the CMD to your handler (matches the filename.function_name)
CMD [ "lambda_handler.lambda_handler" ]