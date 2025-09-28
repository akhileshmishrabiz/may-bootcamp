# lambda code to trogger the RDS instance migration ecs task

import boto3
from os import getenv
import json
import logging
import sys


def log_setup():
    logger = logging.getLogger()
    for handler in logger.handlers:
        logger.removeHandler(handler)
    handler = logging.StreamHandler(sys.stdout)

    dformat = "[%(filename)s:%(lineno)d] :%(levelname)8s: %(message)s"
    handler.setFormatter(logging.Formatter(dformat))
    logger.addHandler(handler)
    log_level = logging.INFO
    if getenv("DEBUG", False):
        log_level = logging.DEBUG
    logger.setLevel(log_level)

    # Suppress the more verbose modules
    logging.getLogger("botocore").setLevel(logging.WARN)
    logging.getLogger("s3transfer").setLevel(logging.WARN)
    logging.getLogger("boto3").setLevel(logging.WARN)
    logging.getLogger("urllib3").setLevel(logging.WARN)


# rds_instance, size
def run_ecs_task(rds_instance, allocated_storage):
    ecs = boto3.client("ecs")

    cluster = getenv("ECS_CLUSTER")
    task_definition = getenv("ECS_TASK_DEF").split("/")[-1]
    launch_type = "FARGATE"
    network_configuration = {
        "awsvpcConfiguration": {
            "subnets": json.loads(getenv("SUBNET_GROUP")),
            "securityGroups": [
                getenv("SG"),
            ],
            "assignPublicIp": "ENABLED",
        }
    }
    container_overrides = {
        "containerOverrides": [
            {
                "name": getenv("ECS_CONTAINER"),
                "command": ["python3", "main.py", "migrate", rds_instance, allocated_storage],
            }
        ]
    }

    response = ecs.run_task(
        cluster=cluster,
        taskDefinition=task_definition,
        launchType=launch_type,
        networkConfiguration=network_configuration,
        overrides=container_overrides,
    )

    return response["tasks"][0]["taskArn"]


def handler(event, context):
    log_setup()

    # data from trigger event
    print(f" Event -> {event}")
    db_instance = event["db_instance"]
    allocated_storage = event["allocated_storage"]

    print(f" RDS Instance : {db_instance} , Allocated Storage : {allocated_storage} ")
# event example
#    {
#     "db_instance": "mayclass26",
#     "allocated_storage": "20"    
# }
    logging.info(f' Triggering ECS task with RDS ')
    # Triger the ecs task
    try:
        ecs_task = run_ecs_task(db_instance, allocated_storage)
        logging.info(f"  ecs task triggered -> \n{ecs_task}")
    except Exception as e:
        logging.info(e)
    

