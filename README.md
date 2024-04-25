# byu-cs-340-aws-terraform-infrastructure

The terraform to create the infrastructure for the byu cs 340 main project, including:

14 lambdas, one for each lambda endpoint 
A lambda layer with the necessary node_modules dependency that attaches itself to each lambda
An api gateway with 14 endpoints, with CORS enabled and the necessary method and integration responses that is automatically deployed to a stage
5 DynamoDB tables
2 SQS queues
2 lambdas to connect to the two SQS queues
A public S3 bucket for user images
