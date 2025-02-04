
# Redis DB and Flask API server in AWS Fargate serverless task implementing POC race timing services

Flask server implements basic commands to keep record of timing services:

1) Create competitor (including BIB)
2) Add and change timing points (start, split points, finish time)
3) Get Bib timings points
3) Get Bib competitor info

Redis memory based DB is configured to be backup every 20s (if changes)
to docker volume . In Fargate context "backup" is done to default volume
(which lives only when task is running). This to be storaged later
to Elasctic Cloud (etc) for permanent storage.

# From docker to Fargate

Only change for flask server (compared local machine usage):

As both containers are running in same "task space", definition
of redis server: 

REDIS_HOST = 'localhost'
REDIS_PORT = 6379


*docker-compose up* used only building both images locally
(or dockerfile for flask server)

### Short steps for Fargate deployment

1) Create cluster

  *ecs create-cluster --cluster-name my-cluster*

2) Create AWS repositories

  *aws ecr create-repository --repository-name redis-repo*

  *aws ecr create-repository --repository-name flask-repo*

3) Log into AWS

  *aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.eu-north-1.amazonaws.com*

4) Tag local images and push to AWS

  *docker tag redisflaskdocker_flask ACCOUNT_ID.dkr.ecr.eu-north-1.amazonaws.com/flask-repo:latest*

  *docker tag redis ACCOUNT_ID.dkr.ecr.eu-north-1.amazonaws.com/redis-repo:latest*

  *docker push ACCOUNT_ID.dkr.ecr.eu-north-1.amazonaws.com/flask-repo:latest*

  *docker push ACCOUNT_ID.dkr.ecr.eu-north-1.amazonaws.com/redis-repo:latest*

5) Fargate task definition : *aws_task_public.json*

  my-ecs-execution-role must have rights:

  1) AmazonECSTaskExecutionRolePolicy

  2) {
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:GetDownloadUrlForLayer",
				"ecr:BatchGetImage",
				"secretsmanager:GetSecretValue"
			],
			"Resource": "*"
		}
	]
}

  Defines default volume (lives only during task running)

  Activates logging

  awsvpc, needed ports can be opened via console

6) Register Fargate task 

*aws ecs register-task-definition --cli-input-json file://aws_task_public.json*

7) Create new security group  (AWS Management Console), attach to Fargate task

  (Define incoming ports here)

8) Some subnet definitions may be needed 

9) Run task

aws ecs run-task \
    --cluster my-cluster \
    --task-definition redis-flask-app:1 \
    --launch-type FARGATE \
    --network-configuration '{
        "awsvpcConfiguration": {
            "subnets": ["subnet-SUBNET_ID"],
            "securityGroups": ["sg-SECURITY_ID"],
            "assignPublicIp": "ENABLED"
        }
    }' \
    --region eu-north-1

10) Check privisioning in console: https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/my-cluster/tasks?region=eu-north-1

From Task / Configuration you will get the public ip . Use it like this (examples may have different port)

 curl -X POST \
    -H "Content-Type: application/json" \
    -d '{
    "bib": "123",
    "first_name": "Ellen",
    "last_name": "Ripley",
    "gender": "female",
    "country": "USA",
    "category": "women40"
    }' \
    http://AWS_TASK_PUBLIC_IP:5000/competitor



NOTE: REMEMBER STOP TASK(S) WHEN NOT WORKING ANYMORE. BILLING STOPS THEN

NOTE: RESTART TASK(S) USING ASW CLI COMMAND ABOVE (console UI starting did not start services correctly)


## Race data definitions

*db.json*

Defines all race timing points. Example:

{
    "allowed_checkpoints": ["start", "split1", "split2", "finish"]
}

*competitor.json*

Defines competitor data . Example:

{  
  "competitor_info": {
    "allowed_keys": ["bib", "first_name", "last_name", "gender", "country", "category"],
    "allowed_genders": ["male", "female", "na"],
    "allowed_categories": [
      "men20", "men30", "men40", "men50+",
      "women20", "women30", "women40", "women50+"
    ]
  }
}

## BIB number used to link competitor data to competitor timings:

Example, get BIB 123 info:
volumes: - /home/mika/REDIS_DATA:/data)
*curl -X GET http://localhost:5001/getcompetitor/123*

{
  "bib": "123",
  "first_name": "Ellen",
  "last_name": "Ripley",
  "gender": "female",
  "country": "USA",
  "category": "women40"
}

Example, get BIB 123 timing data:

*curl -X GET http://localhost:5001/gettimes/123*

{"finish":"13:00:00:000","split1":"00:00:00:000","split2":"00:00:00:000","start":"12:15:00:000"}


### Testing

TBD: port to Fargate context

Robot frame work test implementation started. See *.robot files for test

Manual sanity tests (via curl): [ManualTestsInfo.txt](./ManualTestsInfo.txt)




# REST API

[REST_API_DOC.txt](./REST_API_DOC.txt)


# Ranking the competitors

TBD: Port to Fargate context

As Redis does not offfer SQL type operations. Small demo script was written to create race data
(competitors and results)

When Redis and Flask are running, create a race: 
*python3 test_scripts/create_race.py* 

*python3 test_scripts/men30_results.py*

Results:

All competitor BIB numbers:['103', '104', '201', '203', '105', '202', '102', '205', '204', '101']


All men30 competitors:[{'bib': '103', 'first_name': 'Jari', 'last_name': 'Korhonen', 'gender': 'male', 'country': 'Finland', 'category': 'men30'}, {'bib': '104', 'first_name': 'Pekka', 'last_name': 'Lahtinen', 'gender': 'male', 'country': 'Finland', 'category': 'men30'}, {'bib': '105', 'first_name': 'Antti', 'last_name': 'Nieminen', 'gender': 'male', 'country': 'Finland', 'category': 'men30'}, {'bib': '102', 'first_name': 'Mikko', 'last_name': 'Virtanen', 'gender': 'male', 'country': 'Finland', 'category': 'men30'}, {'bib': '101', 'first_name': 'Matti', 'last_name': 'Meikäläinen', 'gender': 'male', 'country': 'Finland', 'category': 'men30'}]


men30 bib_numbers:['103', '104', '105', '102', '101']


--------- Sorted m30 result, best first -------------

Bib: 105, Name: Antti Nieminen, Finish Time: 09:30:00:000

Bib: 101, Name: Matti Meikäläinen, Finish Time: 09:30:00:000

Bib: 102, Name: Mikko Virtanen, Finish Time: 09:35:00:000

Bib: 103, Name: Jari Korhonen, Finish Time: 09:40:00:000

Bib: 104, Name: Pekka Lahtinen, Finish Time: 09:45:00:000


In reality one should create commandline tools to fetch result list in categoryX,
all competitors in country X , sorted by categoriess and results etc etc













